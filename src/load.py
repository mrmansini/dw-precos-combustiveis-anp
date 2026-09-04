"""Carrega um semestre da série histórica de preços para o data warehouse.

O catálogo etl.source_files governa a leitura: encoding, delimitador, cabeçalho
esperado e período vêm de lá, não de constantes deste arquivo.

Etapas, cada uma registrada em ops.load_runs:
    stage          COPY do CSV para staging.stg_price_survey
    transform      classificação das linhas inválidas em staging.stg_rejects
    load_stations  abertura e encerramento de versões em core.dim_station
    load_facts     inserção em core.fct_price_observation

Uso:
    python src/load.py 2023-01
    python src/load.py 2023-01 2023-02 2024-01     # em ordem cronológica
    python src/load.py 2023-01 --keep-staging      # não trunca ao final
"""

from __future__ import annotations

import csv
import hashlib
import os
import sys
import time
import unicodedata
from pathlib import Path

import psycopg
from dotenv import load_dotenv

RAW_DIR = Path("data/raw")
COPY_COLUMNS = [
    "source_file_id", "line_number",
    "regiao_sigla", "estado_sigla", "municipio", "revenda", "cnpj_da_revenda",
    "nome_da_rua", "numero_rua", "complemento", "bairro", "cep", "produto",
    "data_da_coleta", "valor_de_venda", "valor_de_compra", "unidade_de_medida",
    "bandeira",
]
MAX_FIELD_COUNT_SAMPLES = 50


def slug(text: str) -> str:
    text = unicodedata.normalize("NFKD", str(text)).encode("ascii", "ignore").decode()
    import re

    return re.sub(r"[^a-zA-Z0-9]+", "_", text).strip("_").lower()


def sha256_of(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


class Run:
    """Abre uma linha em ops.load_runs e a fecha no __exit__, inclusive em erro."""

    def __init__(self, conn: psycopg.Connection, source_file_id: int, step: str):
        self.conn = conn
        self.source_file_id = source_file_id
        self.step = step
        self.run_id: int | None = None
        self.metrics: dict[str, int] = {}

    def __enter__(self) -> "Run":
        with self.conn.cursor() as cur:
            cur.execute(
                "INSERT INTO ops.load_runs (source_file_id, step) VALUES (%s, %s)"
                " RETURNING run_id",
                (self.source_file_id, self.step),
            )
            self.run_id = cur.fetchone()[0]
        self.conn.commit()
        self.started = time.perf_counter()
        return self

    def __exit__(self, exc_type, exc, _tb) -> bool:
        if exc_type is not None:
            self.conn.rollback()
        columns = ", ".join(f"{k} = %s" for k in self.metrics)
        params = list(self.metrics.values())
        with self.conn.cursor() as cur:
            cur.execute(
                f"""
                UPDATE ops.load_runs
                   SET status = %s, finished_at = now(), error_detail = %s
                       {(', ' + columns) if columns else ''}
                 WHERE run_id = %s
                """,
                [
                    "failed" if exc_type else "success",
                    f"{exc_type.__name__}: {exc}" if exc_type else None,
                    *params,
                    self.run_id,
                ],
            )
        self.conn.commit()
        elapsed = time.perf_counter() - self.started
        outcome = "FALHOU" if exc_type else "ok"
        detail = "  ".join(f"{k}={v:,}" for k, v in self.metrics.items())
        print(f"    [{outcome}] {self.step:<14} {elapsed:6.1f}s  {detail}")
        return False


def fetch_catalog(conn: psycopg.Connection, semester: str) -> dict:
    with conn.cursor(row_factory=psycopg.rows.dict_row) as cur:
        cur.execute(
            "SELECT * FROM etl.source_files WHERE semester_label = %s", (semester,)
        )
        row = cur.fetchone()
    if row is None:
        sys.exit(f"semestre {semester} não está no catálogo etl.source_files")
    return row


def assert_chronological(conn: psycopg.Connection, catalog: dict) -> None:
    """O SCD2 reconstrói vigências em ordem; carregar um arquivo anterior a um já
    carregado produziria versões com intervalo invertido."""
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT semester_label FROM etl.source_files
             WHERE status = 'loaded' AND period_start > %s
             ORDER BY period_start LIMIT 1
            """,
            (catalog["period_start"],),
        )
        later = cur.fetchone()
    if later:
        sys.exit(
            f"{catalog['semester_label']} é anterior a {later[0]}, que já está "
            "carregado. Carregue os semestres em ordem cronológica."
        )


def validate_header(path: Path, catalog: dict) -> None:
    with path.open(encoding=catalog["file_encoding"], newline="") as handle:
        header = handle.readline().rstrip("\r\n")
    found = [slug(c) for c in header.split(catalog["field_delimiter"])]
    expected = catalog["expected_columns"]
    if found != expected:
        missing = set(expected) - set(found)
        extra = set(found) - set(expected)
        sys.exit(
            "cabeçalho divergente do catálogo.\n"
            f"  esperado: {expected}\n"
            f"  no arquivo: {found}\n"
            f"  faltando: {sorted(missing) or 'nenhuma'}\n"
            f"  a mais: {sorted(extra) or 'nenhuma'}"
        )


def stage_file(conn: psycopg.Connection, path: Path, catalog: dict, run: Run) -> None:
    source_file_id = catalog["source_file_id"]
    expected_fields = len(catalog["expected_columns"])
    staged = 0
    malformed: list[tuple[int, str]] = []

    with conn.cursor() as cur:
        # TRUNCATE, não DELETE: DELETE apenas marca as linhas como mortas e o
        # espaço só volta depois de VACUUM, o que num semestre de texto largo
        # significa dezenas de MB parados. Só um arquivo fica em staging por vez.
        cur.execute("TRUNCATE staging.stg_price_survey")
        statement = (
            f"COPY staging.stg_price_survey ({', '.join(COPY_COLUMNS)}) FROM STDIN"
        )
        with path.open(encoding=catalog["file_encoding"], newline="") as handle:
            reader = csv.reader(handle, delimiter=catalog["field_delimiter"])
            next(reader)  # cabeçalho já validado
            with cur.copy(statement) as copy:
                for line_number, fields in enumerate(reader, start=2):
                    if len(fields) != expected_fields:
                        if len(malformed) < MAX_FIELD_COUNT_SAMPLES:
                            malformed.append((line_number, catalog["field_delimiter"].join(fields)[:500]))
                        continue
                    copy.write_row([source_file_id, line_number, *fields])
                    staged += 1

        if malformed:
            cur.executemany(
                """
                INSERT INTO staging.stg_rejects
                    (source_file_id, line_number, rule_name, detail)
                VALUES (%s, %s, 'field_count', %s)
                """,
                [(source_file_id, ln, text) for ln, text in malformed],
            )

    run.metrics["rows_out"] = staged
    if malformed:
        print(f"      {len(malformed)} linha(s) com contagem de campos errada")


def load_semester(conn: psycopg.Connection, semester: str, keep_staging: bool) -> None:
    catalog = fetch_catalog(conn, semester)
    assert_chronological(conn, catalog)

    path = RAW_DIR / catalog["local_file_name"]
    if not path.exists():
        sys.exit(f"arquivo não encontrado: {path.resolve()}")

    print(f"\n{semester}  ({path.name}, {path.stat().st_size / 1e6:.0f} MB)")
    validate_header(path, catalog)

    source_file_id = catalog["source_file_id"]
    digest = sha256_of(path)
    with conn.cursor() as cur:
        cur.execute(
            """
            UPDATE etl.source_files
               SET checksum_sha256 = %s, downloaded_at = coalesce(downloaded_at, now()),
                   status = 'downloaded'
             WHERE source_file_id = %s
            """,
            (digest, source_file_id),
        )
    conn.commit()

    with Run(conn, source_file_id, "stage") as run:
        stage_file(conn, path, catalog, run)
        conn.commit()
        staged = run.metrics["rows_out"]

    with Run(conn, source_file_id, "transform") as run:
        with conn.cursor() as cur:
            cur.execute("SELECT staging.fn_validate_batch(%s)", (source_file_id,))
            rejected = cur.fetchone()[0]
        conn.commit()
        run.metrics["rows_in"] = staged
        run.metrics["rows_rejected"] = rejected

    with Run(conn, source_file_id, "load_stations") as run:
        with conn.cursor() as cur:
            cur.execute("SELECT * FROM core.fn_apply_station_scd2(%s)", (source_file_id,))
            opened, closed, new_brands = cur.fetchone()
        conn.commit()
        run.metrics["stations_opened"] = opened
        run.metrics["stations_closed"] = closed
        run.metrics["brands_new"] = new_brands

    with Run(conn, source_file_id, "load_facts") as run:
        with conn.cursor() as cur:
            cur.execute("SELECT core.fn_load_facts(%s)", (source_file_id,))
            inserted = cur.fetchone()[0]
        conn.commit()
        run.metrics["rows_in"] = staged - rejected
        run.metrics["rows_out"] = inserted

    with conn.cursor() as cur:
        cur.execute(
            """
            UPDATE etl.source_files
               SET status = 'loaded', rows_staged = %s, rows_rejected = %s,
                   facts_inserted = %s, loaded_at = now()
             WHERE source_file_id = %s
            """,
            (staged, rejected, inserted, source_file_id),
        )
        if not keep_staging:
            # Libera espaço de fato: o plano gratuito do Neon tem 0,5 GB por
            # projeto e a staging de um semestre sozinha ocupa uma fatia
            # relevante disso.
            cur.execute("TRUNCATE staging.stg_price_survey")
    conn.commit()

    if new_brands:
        print(f"      {new_brands} bandeira(s) nova(s) — revise ops.v_brands_to_review")


def main(argv: list[str]) -> None:
    keep_staging = "--keep-staging" in argv
    semesters = [a for a in argv if not a.startswith("--")]
    if not semesters:
        sys.exit("informe ao menos um semestre, por exemplo: python src/load.py 2023-01")

    load_dotenv()
    dsn = os.getenv("DATABASE_URL")
    if not dsn:
        sys.exit("DATABASE_URL não encontrada no .env")

    started = time.perf_counter()
    with psycopg.connect(dsn, application_name="load.py", autocommit=False) as conn:
        for semester in semesters:
            load_semester(conn, semester, keep_staging)

    print(f"\nConcluído em {time.perf_counter() - started:.1f}s.")


if __name__ == "__main__":
    main(sys.argv[1:])
