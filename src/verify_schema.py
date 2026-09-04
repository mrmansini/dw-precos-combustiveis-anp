"""Verificação do schema: contagens de seed e garantias estruturais.

Executa tudo dentro de uma transação revertida ao final — o banco fica
exatamente como estava. As checagens negativas confirmam que constraints
recusam dado inválido, não só que aceitam dado válido.

Uso: python src/verify_schema.py
"""

from __future__ import annotations

import os
import sys

import psycopg
from dotenv import load_dotenv

CNPJ = "00000000000191"
failures: list[str] = []


def report(label: str, ok: bool, detail: str = "") -> None:
    status = "PASSOU" if ok else "FALHOU"
    print(f"  [{status}] {label}{(' — ' + detail) if detail else ''}")
    if not ok:
        failures.append(label)


def expect_error(cur, sql: str, params, error_class, label: str) -> None:
    """Executa SQL que DEVE falhar, isolando em savepoint para seguir depois."""
    cur.execute("SAVEPOINT probe")
    try:
        cur.execute(sql, params)
    except error_class as exc:
        cur.execute("ROLLBACK TO SAVEPOINT probe")
        report(label, True, type(exc).__name__)
        return
    except Exception as exc:  # noqa: BLE001
        cur.execute("ROLLBACK TO SAVEPOINT probe")
        report(label, False, f"erro inesperado: {type(exc).__name__}")
        return
    cur.execute("ROLLBACK TO SAVEPOINT probe")
    report(label, False, "a operação foi aceita")


def main() -> None:
    load_dotenv()
    dsn = os.getenv("DATABASE_URL")
    if not dsn:
        sys.exit("DATABASE_URL não encontrada no .env")

    expected_counts = [
        ("core.dim_date",       1826, "dias de 2023-01-01 a 2027-12-31"),
        ("core.dim_product",       6, "produtos"),
        ("core.dim_brand",        22, "bandeiras canônicas"),
        ("core.brand_alias",      24, "aliases"),
        ("etl.source_files",       7, "semestres no catálogo"),
    ]

    with psycopg.connect(dsn, application_name="verify_schema.py") as conn:
        with conn.cursor() as cur:
            print("\nSeed das dimensões")
            for table, expected, label in expected_counts:
                cur.execute(f"SELECT count(*) FROM {table}")
                actual = cur.fetchone()[0]
                report(f"{table}: {label}", actual == expected,
                       f"esperado {expected}, obtido {actual}")

            cur.execute("SELECT count(*) FROM core.brand_alias WHERE is_rename")
            report("aliases marcados como renomeação", cur.fetchone()[0] == 2)

            print("\nEstrutura física")
            cur.execute("SELECT count(*) FROM ops.v_partition_health")
            report("partições do fato", cur.fetchone()[0] == 17,
                   "16 trimestres + DEFAULT")

            cur.execute("SELECT count(*) FROM pg_extension WHERE extname = 'btree_gist'")
            report("extensão btree_gist instalada", cur.fetchone()[0] == 1)

            cur.execute("""
                SELECT count(*) FROM pg_constraint
                WHERE conname = 'dim_station_no_overlap' AND contype = 'x'
            """)
            report("constraint de exclusão presente", cur.fetchone()[0] == 1)

            print("\nGarantias do modelo (transação revertida)")
            cur.execute("""
                INSERT INTO core.dim_city (city_name, uf, region)
                VALUES ('MUNICIPIO DE TESTE', 'PR', 'S')
                ON CONFLICT (city_name, uf) DO NOTHING
            """)
            cur.execute("""
                SELECT city_key FROM core.dim_city
                WHERE city_name = 'MUNICIPIO DE TESTE' AND uf = 'PR'
            """)
            city_key = cur.fetchone()[0]

            cur.execute("SELECT brand_key FROM core.dim_brand WHERE brand_name = 'VIBRA'")
            brand_vibra = cur.fetchone()[0]
            cur.execute("SELECT brand_key FROM core.dim_brand WHERE brand_name = 'BRANCA'")
            brand_branca = cur.fetchone()[0]

            insert_station = """
                INSERT INTO core.dim_station
                    (cnpj, legal_name, brand_key, city_key, valid_from, valid_to, is_current)
                VALUES (%s, 'POSTO DE TESTE', %s, %s, %s, %s, %s)
                RETURNING station_key
            """

            cur.execute(insert_station,
                        (CNPJ, brand_vibra, city_key, "2023-01-01", "2024-01-01", False))
            station_v1 = cur.fetchone()[0]
            report("versão inicial do posto aceita", station_v1 is not None)

            expect_error(
                cur, insert_station,
                (CNPJ, brand_branca, city_key, "2023-06-01", "infinity", True),
                psycopg.errors.ExclusionViolation,
                "vigência sobreposta é recusada",
            )

            expect_error(
                cur, insert_station,
                (CNPJ, brand_branca, city_key, "2024-01-01", "2025-01-01", True),
                psycopg.errors.CheckViolation,
                "is_current inconsistente com valid_to é recusado",
            )

            cur.execute(insert_station,
                        (CNPJ, brand_branca, city_key, "2024-01-01", "infinity", True))
            station_v2 = cur.fetchone()[0]
            report("versão seguinte, sem sobreposição, aceita", station_v2 is not None)

            cur.execute("SELECT core.fn_station_key_at(%s, %s)", (CNPJ, "2023-05-10"))
            report("resolução temporal aponta para a versão da data",
                   cur.fetchone()[0] == station_v1)

            cur.execute("""
                SELECT change_type FROM core.v_brand_changes WHERE cnpj = %s
            """, (CNPJ,))
            row = cur.fetchone()
            report("troca de bandeira classificada", row is not None and row[0] == "desbandeiramento",
                   row[0] if row else "nenhuma linha")

            insert_fact = """
                INSERT INTO core.fct_price_observation
                    (collection_date, station_key, product_key, sale_price, source_file_id)
                VALUES (%s, %s, 1, %s,
                        (SELECT source_file_id FROM etl.source_files WHERE semester_label = '2023-01'))
                RETURNING tableoid::regclass::text
            """
            cur.execute(insert_fact, ("2023-03-15", station_v1, 5.29))
            landed_in = cur.fetchone()[0]
            report("fato roteado para a partição correta", landed_in.endswith("2023q1"),
                   landed_in)

            expect_error(cur, insert_fact, ("2023-03-16", station_v1, -1),
                         psycopg.errors.CheckViolation,
                         "preço negativo é recusado")

            expect_error(cur, insert_fact, ("2019-03-15", station_v1, 5.29),
                         psycopg.errors.ForeignKeyViolation,
                         "data fora de dim_date é recusada")

            expect_error(cur, insert_fact, ("2023-03-15", station_v1, 6.00),
                         psycopg.errors.UniqueViolation,
                         "grão duplicado (posto+produto+dia) é recusado")

        conn.rollback()
        print("\nTransação revertida — nenhum dado de teste permaneceu.")

    print(f"\n{len(failures)} falha(s).")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
