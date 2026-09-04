"""Procura duplicatas de posto+produto+dia nos arquivos brutos.

O fato tem chave primária (collection_date, station_key, product_key) e a carga
usa ON CONFLICT DO NOTHING, então duplicata na origem é descartada em silêncio.
Este script mostra o que foi descartado e, principalmente, se as linhas
repetidas trazem o mesmo preço ou preços divergentes.

Uso: python src/check_duplicates.py data/raw/ca-2024-01.csv data/raw/ca-2026-01.csv
"""

from __future__ import annotations

import sys
from pathlib import Path

import pandas as pd

KEYS = ["cnpj_da_revenda", "produto", "data_da_coleta", "valor_de_venda",
        "revenda", "municipio", "estado_sigla"]


def inspect(path: Path) -> None:
    header = path.open(encoding="utf-8-sig").readline().rstrip("\r\n").split(";")
    wanted = [c for c in header if c.strip().lower().replace(" ", "_")
              .replace("ç", "c").replace("ã", "a") in
              {"cnpj_da_revenda", "produto", "data_da_coleta", "valor_de_venda",
               "revenda", "municipio", "estado_sigla"}]

    frame = pd.read_csv(path, sep=";", encoding="utf-8-sig", dtype=str,
                        usecols=wanted, keep_default_na=False)
    frame.columns = [c.strip().lower().replace(" ", "_")
                     .replace("ç", "c").replace("ã", "a") for c in frame.columns]

    frame["cnpj"] = frame["cnpj_da_revenda"].str.replace(r"\D", "", regex=True)
    frame["price"] = pd.to_numeric(
        frame["valor_de_venda"].str.strip().str.replace(",", ".", regex=False),
        errors="coerce")
    frame = frame[frame["cnpj"].str.len() == 14]

    key = ["cnpj", "produto", "data_da_coleta"]
    sizes = frame.groupby(key).size()
    dupes = sizes[sizes > 1]

    print(f"\n## {path.name}")
    print(f"  linhas válidas: {len(frame):,}")
    print(f"  grupos duplicados: {len(dupes):,}")
    print(f"  linhas excedentes: {int((dupes - 1).sum()):,}")

    if dupes.empty:
        return

    subset = frame.set_index(key).loc[dupes.index].reset_index()
    spread = subset.groupby(key)["price"].agg(["nunique", "min", "max"])
    divergent = spread[spread["nunique"] > 1]

    print(f"  com preço divergente: {len(divergent):,} de {len(dupes):,}")
    if not divergent.empty:
        gap = (divergent["max"] - divergent["min"])
        print(f"  diferença: mediana R$ {gap.median():.3f}, máxima R$ {gap.max():.3f}")

    print("\n  amostra:")
    for key_values in list(dupes.index)[:8]:
        rows = subset[(subset["cnpj"] == key_values[0]) &
                      (subset["produto"] == key_values[1]) &
                      (subset["data_da_coleta"] == key_values[2])]
        precos = sorted(rows["price"].tolist())
        nomes = rows["revenda"].unique().tolist()
        print(f"    {key_values[0]} {key_values[1]:<20} {key_values[2]}  "
              f"precos={precos}  revenda={nomes}")


def main(paths: list[str]) -> None:
    if not paths:
        sys.exit("informe ao menos um CSV")
    for p in paths:
        inspect(Path(p))


if __name__ == "__main__":
    main(sys.argv[1:])
