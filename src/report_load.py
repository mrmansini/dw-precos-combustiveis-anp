"""Balanço da carga: reconcilia arquivo, staging, rejeições e fatos.

Uso: python src/report_load.py
"""

from __future__ import annotations

import os
import sys

import psycopg
from dotenv import load_dotenv


def main() -> None:
    load_dotenv()
    dsn = os.getenv("DATABASE_URL")
    if not dsn:
        sys.exit("DATABASE_URL não encontrada no .env")

    with psycopg.connect(dsn, application_name="report_load.py") as conn, conn.cursor() as cur:
        cur.execute("""
            SELECT f.semester_label, f.rows_staged, f.rows_rejected,
                   f.rows_staged - f.rows_rejected AS validas,
                   f.facts_inserted,
                   f.rows_staged - f.rows_rejected - f.facts_inserted AS perdidas
              FROM etl.source_files f
             WHERE f.status = 'loaded'
             ORDER BY f.period_start
        """)
        print(f"{'semestre':<10}{'staged':>10}{'rejeit':>9}{'validas':>10}"
              f"{'fatos':>10}{'perdidas':>10}")
        for row in cur.fetchall():
            print(f"{row[0]:<10}{row[1]:>10,}{row[2]:>9,}{row[3]:>10,}"
                  f"{row[4]:>10,}{row[5]:>10,}")

        cur.execute("""
            SELECT rule_name, count(*) FROM staging.stg_rejects
             GROUP BY 1 ORDER BY 2 DESC
        """)
        print("\nrejeições por regra:")
        for rule, n in cur.fetchall():
            print(f"  {rule:<24} {n:>10,}")

        print()
        for label, query in [
            ("observações no fato",      "SELECT count(*) FROM core.fct_price_observation"),
            ("versões de posto",         "SELECT count(*) FROM core.dim_station"),
            ("postos distintos",         "SELECT count(DISTINCT cnpj) FROM core.dim_station"),
            ("postos com versão aberta", "SELECT count(*) FROM core.dim_station WHERE is_current"),
            ("trocas de bandeira",       "SELECT count(*) FROM core.v_brand_changes"),
            ("municípios",               "SELECT count(*) FROM core.dim_city"),
            ("bandeiras",                "SELECT count(*) FROM core.dim_brand"),
            ("bandeiras a revisar",      "SELECT count(*) FROM ops.v_brands_to_review"),
            ("linhas na partição DEFAULT",
             "SELECT count(*) FROM core.fct_price_observation_default"),
        ]:
            cur.execute(query)
            print(f"{label:<28} {cur.fetchone()[0]:>10,}")

        cur.execute("""
            SELECT change_type, count(*) FROM core.v_brand_changes
             GROUP BY 1 ORDER BY 2 DESC
        """)
        print("\ntrocas de bandeira por tipo:")
        for tipo, n in cur.fetchall():
            print(f"  {tipo:<24} {n:>10,}")

        cur.execute("""
            SELECT date_part('year', valid_from)::int AS ano,
                   count(*) AS abertas,
                   count(*) FILTER (WHERE NOT is_current) AS ja_encerradas
              FROM core.dim_station GROUP BY 1 ORDER BY 1
        """)
        print("\nversões abertas por ano:")
        for ano, abertas, encerradas in cur.fetchall():
            print(f"  {ano}  abertas={abertas:>7,}  já encerradas={encerradas:>7,}")

        cur.execute("""
            SELECT pg_size_pretty(pg_database_size(current_database())),
                   pg_size_pretty((SELECT sum(pg_total_relation_size(relid))
                                     FROM pg_partition_tree('core.fct_price_observation')
                                    WHERE isleaf)),
                   pg_size_pretty(pg_total_relation_size('core.dim_station'))
        """)
        db, fato, station = cur.fetchone()
        print(f"\nbanco: {db}   fato: {fato}   dim_station: {station}")


if __name__ == "__main__":
    main()
