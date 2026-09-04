"""Checagens que decidem o grao do fato e a normalizacao de bandeira.

Uso: python src/check_grain.py data/raw/ca-2023-01.csv data/raw/ca-2025-02.csv
"""
from __future__ import annotations

import re
import sys
import unicodedata
from pathlib import Path

import pandas as pd

KEYS = [
    "cnpj_da_revenda", "revenda", "bandeira", "produto", "data_da_coleta",
    "valor_de_venda", "unidade_de_medida", "municipio", "estado_sigla", "cep",
]
REPORT_PATH = Path("docs/perfil-grao.md")
OUT: list[str] = []


def say(text: str = "") -> None:
    OUT.append(text)
    print(text)


def slug(text: str) -> str:
    text = unicodedata.normalize("NFKD", str(text)).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-zA-Z0-9]+", "_", text).strip("_").lower()


def load(path: Path) -> pd.DataFrame:
    header = path.open(encoding="utf-8-sig").readline().rstrip("\r\n")
    mapping = {slug(c): c for c in header.split(";")}
    wanted = [mapping[k] for k in KEYS if k in mapping]

    frame = pd.read_csv(
        path, sep=";", encoding="utf-8-sig", dtype=str,
        usecols=wanted, keep_default_na=False,
    )
    frame.columns = [slug(c) for c in frame.columns]
    frame["cnpj"] = frame["cnpj_da_revenda"].str.replace(r"\D", "", regex=True)
    frame["brand"] = frame["bandeira"].str.strip().str.upper()
    frame["product"] = frame["produto"].str.strip().str.upper()
    frame["collected_at"] = pd.to_datetime(
        frame["data_da_coleta"].str.strip(), format="%d/%m/%Y", errors="coerce"
    )
    frame["price"] = pd.to_numeric(
        frame["valor_de_venda"].str.strip().str.replace(",", ".", regex=False),
        errors="coerce",
    )
    return frame


def inspect(path: Path) -> pd.DataFrame:
    frame = load(path)
    say(f"## `{path.name}`")
    say()

    # 1. datas de verdade, agora parseadas
    bad_dates = int(frame["collected_at"].isna().sum())
    say(f"- datas invalidas: {bad_dates:,}")
    say(f"- periodo real: {frame['collected_at'].min():%Y-%m-%d} a "
        f"{frame['collected_at'].max():%Y-%m-%d}")
    say(f"- dias distintos de coleta: {frame['collected_at'].nunique():,}")
    say(f"- dias da semana (0=seg): "
        f"{frame['collected_at'].dt.weekday.value_counts().sort_index().to_dict()}")
    say()
    say("| mes | linhas |")
    say("| --- | ---: |")
    for period, count in frame["collected_at"].dt.to_period("M").value_counts().sort_index().items():
        say(f"| {period} | {count:,} |")
    say()

    # 2. CNPJ e preco
    lengths = frame["cnpj"].str.len().value_counts().to_dict()
    say(f"- comprimento do CNPJ normalizado: {lengths}")
    say(f"- precos nao numericos: {int(frame['price'].isna().sum()):,}")
    say()
    say("| produto | min | mediana | max |")
    say("| --- | ---: | ---: | ---: |")
    for product, group in frame.groupby("product")["price"]:
        say(f"| {product} | {group.min():.3f} | {group.median():.3f} | {group.max():.3f} |")
    say()

    # 3. duplicatas — o teste que define a chave primaria
    for label, keys in [
        ("dia", ["cnpj", "product", "collected_at"]),
        ("semana ISO", ["cnpj", "product"]),
    ]:
        work = frame.copy()
        if label.startswith("semana"):
            work["week"] = work["collected_at"].dt.to_period("W")
            keys = keys + ["week"]
        sizes = work.groupby(keys, dropna=False).size()
        dupes = sizes[sizes > 1]
        extra = int((dupes - 1).sum())
        say(f"- duplicatas por **{label}** (cnpj+produto): {len(dupes):,} grupos, "
            f"{extra:,} linhas excedentes ({extra / len(frame):.2%})")
        if len(dupes):
            keyset = work.set_index(keys).index
            conflicting = work[keyset.isin(dupes.index)].groupby(keys)["price"].nunique()
            say(f"  - desses, com **preco divergente**: "
                f"{int((conflicting > 1).sum()):,} grupos")
    say()

    # 4. bandeiras e mudanca de municipio
    say(f"- bandeiras distintas: {frame['brand'].nunique():,}")
    say("- top 15 bandeiras: ")
    for brand, count in frame["brand"].value_counts().head(15).items():
        say(f"  - `{brand}` — {count:,}")
    multi_city = frame.groupby("cnpj")["municipio"].nunique()
    say(f"- CNPJs com mais de um municipio no mesmo arquivo: "
        f"{int((multi_city > 1).sum()):,}")
    say(f"- unidades de medida: {frame['unidade_de_medida'].value_counts().to_dict()}")
    say()
    return frame


def transitions(first: pd.DataFrame, second: pd.DataFrame) -> None:
    """Bandeira mais frequente por CNPJ em cada arquivo, e as transicoes."""
    def dominant(frame: pd.DataFrame) -> pd.Series:
        return frame.groupby("cnpj")["brand"].agg(lambda s: s.value_counts().idxmax())

    left, right = dominant(first), dominant(second)
    common = left.index.intersection(right.index)
    pairs = pd.DataFrame({"from": left[common], "to": right[common]})
    changed = pairs[pairs["from"] != pairs["to"]]

    say("## Transicoes de bandeira")
    say()
    say(f"- CNPJs em ambos: {len(common):,}")
    say(f"- com bandeira dominante diferente: {len(changed):,} "
        f"({len(changed) / max(len(common), 1):.1%})")
    say()
    say("| de | para | postos |")
    say("| --- | --- | ---: |")
    for (origin, target), count in (
        changed.groupby(["from", "to"]).size().sort_values(ascending=False).head(30).items()
    ):
        say(f"| {origin} | {target} | {count:,} |")
    say()


def main(paths: list[str]) -> None:
    frames = [inspect(Path(p)) for p in paths]
    if len(frames) == 2:
        transitions(frames[0], frames[1])
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text("\n".join(OUT), encoding="utf-8")
    print(f"\n>>> relatorio gravado em {REPORT_PATH}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit("uso: python src/check_grain.py <csv> [<csv>]")
    main(sys.argv[1:])
