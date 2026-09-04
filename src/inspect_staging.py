"""Inspeciona o conteúdo bruto em staging para entender uma rejeição.

Roda contra o arquivo que estiver carregado em staging.stg_price_survey no
momento. Não escreve nada.

Uso: python src/inspect_staging.py
"""

from __future__ import annotations

import os
import sys

import psycopg
from dotenv import load_dotenv

SEM_CNPJ = r"length(regexp_replace(cnpj_da_revenda, '\D', '', 'g')) = 0"


def main() -> None:
    load_dotenv()
    dsn = os.getenv("DATABASE_URL")
    if not dsn:
        sys.exit("DATABASE_URL não encontrada no .env")

    with psycopg.connect(dsn, application_name="inspect_staging.py") as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT count(*) FROM staging.stg_price_survey")
            total = cur.fetchone()[0]
            print(f"linhas em staging: {total:,}\n")

            cur.execute(f"""
                SELECT produto, unidade_de_medida, count(*)
                  FROM staging.stg_price_survey
                 WHERE {SEM_CNPJ}
                 GROUP BY 1, 2 ORDER BY 3 DESC
            """)
            print("produtos das linhas sem CNPJ:")
            for produto, unidade, n in cur.fetchall():
                print(f"  {produto:<22} {unidade:<14} {n:>8,}")

            cur.execute(f"""
                SELECT
                    count(*) FILTER (WHERE btrim(municipio)       = '') AS sem_municipio,
                    count(*) FILTER (WHERE btrim(estado_sigla)    = '') AS sem_uf,
                    count(*) FILTER (WHERE btrim(bandeira)        = '') AS sem_bandeira,
                    count(*) FILTER (WHERE btrim(nome_da_rua)     = '') AS sem_rua,
                    count(*) FILTER (WHERE btrim(valor_de_venda)  = '') AS sem_preco,
                    count(*) FILTER (WHERE btrim(data_da_coleta)  = '') AS sem_data,
                    count(*)                                            AS total
                  FROM staging.stg_price_survey WHERE {SEM_CNPJ}
            """)
            columns = [d.name for d in cur.description]
            print("\npreenchimento das outras colunas nessas linhas:")
            for name, value in zip(columns, cur.fetchone()):
                print(f"  {name:<16} {value:>8,}")

            cur.execute(f"""
                SELECT regiao_sigla, estado_sigla, municipio, revenda, cnpj_da_revenda,
                       nome_da_rua, bairro, cep, produto, data_da_coleta,
                       valor_de_venda, unidade_de_medida, bandeira
                  FROM staging.stg_price_survey WHERE {SEM_CNPJ} LIMIT 3
            """)
            print("\nlinhas completas (amostra):")
            for row in cur.fetchall():
                print("  ", row)

            cur.execute("""
                SELECT produto, count(*) FROM staging.stg_price_survey
                 GROUP BY 1 ORDER BY 2 DESC
            """)
            print("\ntodos os produtos do arquivo:")
            for produto, n in cur.fetchall():
                print(f"  {produto:<22} {n:>8,}")


if __name__ == "__main__":
    main()
