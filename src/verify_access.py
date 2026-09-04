"""Verifica a separação de papéis: o usuário de BI lê o que deve e nada além.

Complementa verify_schema.py, que cobre estrutura e constraints. Aqui o objeto
verificado é permissão, e as checagens negativas são a parte que importa —
declarar que um papel é somente leitura não prova que ele é.

Exige DATABASE_URL (papel dono) e BI_DATABASE_URL (usuário de leitura) no .env.

Uso: python src/verify_access.py
"""

from __future__ import annotations

import os
import sys

import psycopg
from dotenv import load_dotenv

READABLE = ["core", "analytics", "ops"]
FORBIDDEN = ["staging", "etl"]

failures: list[str] = []


def report(label: str, ok: bool, detail: str = "") -> None:
    print(f"  [{'PASSOU' if ok else 'FALHOU'}] {label}{(' — ' + detail) if detail else ''}")
    if not ok:
        failures.append(label)


def expect_denied(cur, sql: str, label: str) -> None:
    """Executa comando que DEVE ser recusado por falta de privilégio."""
    try:
        cur.execute(sql)
    except psycopg.errors.InsufficientPrivilege:
        report(label, True)
        return
    except psycopg.Error as exc:
        report(label, False, f"recusado por outro motivo: {type(exc).__name__}")
        return
    report(label, False, "a operação foi permitida")


def check_owner_view(dsn: str) -> None:
    """Atributos do papel de permissões, consultados com o papel dono."""
    print("\nPapel de permissões")
    with psycopg.connect(dsn, application_name="verify_access.py") as conn, conn.cursor() as cur:
        cur.execute("SELECT count(*) FROM pg_roles WHERE rolname = 'bi_reader'")
        report("papel bi_reader existe", cur.fetchone()[0] == 1)

        cur.execute("SELECT rolcanlogin FROM pg_roles WHERE rolname = 'bi_reader'")
        row = cur.fetchone()
        report("bi_reader não faz login", row is not None and row[0] is False,
               "é conjunto de permissões, não usuário")


def check_bi_user(dsn_bi: str, dsn_owner: str) -> None:
    with psycopg.connect(dsn_bi, application_name="verify_access.py",
                         autocommit=True) as conn, conn.cursor() as cur:
        # session_user, não current_user: o usuário de BI assume bi_reader ao
        # conectar (ALTER ROLE ... SET role), então current_user devolveria o
        # papel de permissões e a checagem de filiação olharia para o objeto
        # errado. session_user preserva quem se autenticou.
        cur.execute("SELECT session_user, current_user")
        user, effective = cur.fetchone()
        print(f"\nUsuário de BI conectado: {user} (assume {effective})")

        print("\nFiliação e atributos")
        with psycopg.connect(dsn_owner) as owner_conn, owner_conn.cursor() as owner_cur:
            owner_cur.execute("""
                SELECT m.rolname FROM pg_auth_members am
                  JOIN pg_roles m ON m.oid = am.roleid
                  JOIN pg_roles u ON u.oid = am.member
                 WHERE u.rolname = %s
            """, (user,))
            roles = sorted(r[0] for r in owner_cur.fetchall())
            report("membro apenas de bi_reader", roles == ["bi_reader"], str(roles))
            report("assume bi_reader ao conectar", effective == "bi_reader", effective)

            owner_cur.execute("""
                SELECT rolsuper, rolcreatedb, rolcreaterole, rolbypassrls
                  FROM pg_roles WHERE rolname = %s
            """, (user,))
            flags = owner_cur.fetchone()
            report("sem atributos administrativos", not any(flags),
                   f"super={flags[0]} createdb={flags[1]} "
                   f"createrole={flags[2]} bypassrls={flags[3]}")

        print("\nLeitura permitida")
        for schema in READABLE:
            try:
                cur.execute(f"SELECT count(*) FROM information_schema.tables "
                            f"WHERE table_schema = '{schema}'")
                report(f"enxerga o schema {schema}", cur.fetchone()[0] > 0)
            except psycopg.Error as exc:
                report(f"enxerga o schema {schema}", False, type(exc).__name__)

        for label, sql in [
            ("lê o rollup semanal",
             "SELECT count(*) FROM analytics.mv_weekly_price"),
            ("lê o fato",
             "SELECT count(*) FROM core.fct_price_observation "
             "WHERE collection_date >= DATE '2026-01-01'"),
            ("lê a dimensão versionada",
             "SELECT count(*) FROM core.dim_station WHERE is_current"),
            ("lê a saúde da carga",
             "SELECT count(*) FROM ops.v_load_health"),
        ]:
            try:
                cur.execute(sql)
                report(label, True, f"{cur.fetchone()[0]:,} linhas")
            except psycopg.Error as exc:
                report(label, False, type(exc).__name__)

        print("\nEscrita e schemas internos recusados")
        expect_denied(cur, "DELETE FROM core.fct_price_observation WHERE false",
                      "não apaga do fato")
        expect_denied(cur, "UPDATE core.dim_station SET legal_name = legal_name "
                           "WHERE false", "não altera a dimensão")
        expect_denied(cur, "INSERT INTO core.dim_city (city_name, uf, region) "
                           "VALUES ('X', 'XX', 'X')", "não insere em dimensão")
        expect_denied(cur, "CREATE TABLE core.intruso (id int)",
                      "não cria objeto em core")
        for schema in FORBIDDEN:
            expect_denied(cur, f"SELECT count(*) FROM {schema}."
                               + ("stg_price_survey" if schema == "staging"
                                  else "source_files"),
                          f"não lê o schema {schema}")


def main() -> None:
    load_dotenv()
    dsn_owner = os.getenv("DATABASE_URL")
    dsn_bi = os.getenv("BI_DATABASE_URL")
    if not dsn_owner:
        sys.exit("DATABASE_URL não encontrada no .env")
    if not dsn_bi:
        sys.exit("BI_DATABASE_URL não encontrada no .env")

    check_owner_view(dsn_owner)
    check_bi_user(dsn_bi, dsn_owner)

    print(f"\n{len(failures)} falha(s).")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
