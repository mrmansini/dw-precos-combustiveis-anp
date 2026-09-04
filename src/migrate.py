"""Aplica as migrações de sql/ em ordem, registrando no ledger ops.schema_migrations.

As migrações são idempotentes, então reaplicar é seguro. O ledger serve para
auditoria e para detectar arquivo editado depois de aplicado (checksum diferente).

Uso:
    python src/migrate.py            # aplica o que falta
    python src/migrate.py --all      # reaplica tudo
    python src/migrate.py --status   # só mostra o estado, não escreve
"""

from __future__ import annotations

import hashlib
import os
import sys
import time
from pathlib import Path

import psycopg
from dotenv import load_dotenv

SQL_DIR = Path("sql")
NOTICES: list[str] = []
BOOTSTRAP = """
CREATE SCHEMA IF NOT EXISTS ops;
CREATE TABLE IF NOT EXISTS ops.schema_migrations (
    filename    text PRIMARY KEY,
    checksum    char(64) NOT NULL,
    applied_at  timestamptz NOT NULL DEFAULT now(),
    duration_ms integer
);
"""


def checksum(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def connect() -> psycopg.Connection:
    load_dotenv()
    dsn = os.getenv("DATABASE_URL")
    if not dsn:
        sys.exit("DATABASE_URL não encontrada. Crie o .env com a string do Neon.")
    conn = psycopg.connect(dsn, application_name="migrate.py", autocommit=False)
    # As migrações usam RAISE NOTICE para relatar o que criaram ou pularam. No
    # psycopg 3 essas mensagens chegam por callback e são descartadas se ninguém
    # as coletar.
    conn.add_notice_handler(lambda diag: NOTICES.append(diag.message_primary or ""))
    return conn


def main(argv: list[str]) -> None:
    force = "--all" in argv
    status_only = "--status" in argv

    files = sorted(SQL_DIR.glob("[0-9][0-9][0-9]_*.sql"))
    if not files:
        sys.exit(f"nenhuma migração encontrada em {SQL_DIR.resolve()}")

    with connect() as conn:
        with conn.cursor() as cur:
            cur.execute(BOOTSTRAP)
        conn.commit()

        with conn.cursor() as cur:
            cur.execute("SELECT filename, checksum FROM ops.schema_migrations")
            applied = dict(cur.fetchall())

        for path in files:
            digest = checksum(path)
            previous = applied.get(path.name)

            if previous == digest and not force:
                print(f"  ok      {path.name}")
                continue
            if previous and previous != digest:
                print(f"  ALTERADA {path.name} (checksum mudou desde a aplicação)")
            if status_only:
                print(f"  pendente {path.name}")
                continue

            started = time.perf_counter()
            try:
                with conn.cursor() as cur:
                    cur.execute(path.read_text(encoding="utf-8"))
                    elapsed = int((time.perf_counter() - started) * 1000)
                    cur.execute(
                        """
                        INSERT INTO ops.schema_migrations
                            (filename, checksum, applied_at, duration_ms)
                        VALUES (%s, %s, now(), %s)
                        ON CONFLICT (filename) DO UPDATE
                           SET checksum = EXCLUDED.checksum,
                               applied_at = EXCLUDED.applied_at,
                               duration_ms = EXCLUDED.duration_ms
                        """,
                        (path.name, digest, elapsed),
                    )
                conn.commit()
                print(f"  APLICADA {path.name} ({elapsed} ms)")
            except Exception as exc:  # noqa: BLE001 — queremos o erro cru na tela
                conn.rollback()
                print(f"\nFALHOU em {path.name}:\n{exc}")
                sys.exit(1)

        for message in NOTICES:
            print(f"  nota: {message.strip()}")

    print("\nMigrações concluídas.")


if __name__ == "__main__":
    main(sys.argv[1:])