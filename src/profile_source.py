"""Perfil dos arquivos brutos da ANP (Levantamento de Precos de Combustiveis).

Nao cria schema nem carrega nada: le os CSVs, mede o que existe e grava
o relatorio em docs/perfil-fonte.md como evidencia versionada.

Uso:  python src/profile_source.py data/raw/ca-2023-01.csv data/raw/ca-2025-02.csv
"""
from __future__ import annotations

import re
import sys
import unicodedata
from collections import Counter, defaultdict
from pathlib import Path

import pandas as pd

CHUNKSIZE = 250_000
SCOPE_KEYWORDS = ("gasolina comum", "etanol", "s10", "s-10")  # escopo pretendido
REPORT_PATH = Path("docs/perfil-fonte.md")


def slug(text: str) -> str:
    """Normaliza nome de coluna: sem acento, minusculo, underscore."""
    text = unicodedata.normalize("NFKD", str(text)).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-zA-Z0-9]+", "_", text).strip("_").lower()


def sniff(path: Path) -> tuple[str, str, str]:
    """Descobre encoding e delimitador lendo o inicio do arquivo em bytes."""
    head = path.open("rb").read(1_000_000)
    try:
        head.decode("utf-8")
        encoding = "utf-8-sig"
    except UnicodeDecodeError:
        encoding = "latin-1"
    header = head.split(b"\n", 1)[0].decode(encoding, errors="replace")
    delimiter = max((";", ",", "\t"), key=header.count)
    return encoding, delimiter, header


def pick(columns: list[str], *candidates: str) -> str | None:
    """Escolhe a coluna: match exato primeiro, depois por conteudo."""
    for cand in candidates:
        if cand in columns:
            return cand
    for cand in candidates:
        for col in columns:
            if cand in col:
                return col
    return None


def profile(path: Path, brands: dict) -> dict:
    encoding, delimiter, header = sniff(path)
    columns = [slug(c) for c in header.split(delimiter)]

    col_cnpj = pick(columns, "cnpj_da_revenda", "cnpj")
    col_brand = pick(columns, "bandeira")
    col_name = pick(columns, "revenda")
    col_product = pick(columns, "produto")
    col_date = pick(columns, "data_da_coleta", "data")
    col_sale = pick(columns, "valor_de_venda")
    col_purchase = pick(columns, "valor_de_compra")
    col_unit = pick(columns, "unidade_de_medida")
    col_uf = pick(columns, "estado_sigla", "estado")
    col_city = pick(columns, "municipio")
    addr_cols = [c for c in ("nome_da_rua", "numero_rua", "bairro", "cep") if c in columns]

    stats = {
        "path": path.name, "encoding": encoding, "delimiter": delimiter,
        "columns": columns, "rows": 0, "rows_in_scope": 0,
        "products": Counter(), "units": Counter(), "ufs": Counter(),
        "null_sale": 0, "null_purchase": 0, "bad_lines": 0,
        "cnpj_masked": 0, "cnpj_raw_sample": None,
        "date_min": None, "date_max": None, "cities": set(), "cnpjs": set(),
    }

    reader = pd.read_csv(
        path, sep=delimiter, encoding=encoding, dtype=str,
        chunksize=CHUNKSIZE, on_bad_lines="skip", keep_default_na=False,
    )
    for chunk in reader:
        chunk.columns = [slug(c) for c in chunk.columns]
        stats["rows"] += len(chunk)

        if col_product:
            products = chunk[col_product].str.strip().str.upper()
            stats["products"].update(products.value_counts().to_dict())
            in_scope = products.str.lower().apply(
                lambda p: any(k in p for k in SCOPE_KEYWORDS)
            )
            stats["rows_in_scope"] += int(in_scope.sum())
        if col_unit:
            stats["units"].update(chunk[col_unit].value_counts().to_dict())
        if col_uf:
            stats["ufs"].update(chunk[col_uf].value_counts().to_dict())
        if col_sale:
            stats["null_sale"] += int((chunk[col_sale].str.strip() == "").sum())
        if col_purchase:
            stats["null_purchase"] += int((chunk[col_purchase].str.strip() == "").sum())
        if col_city:
            stats["cities"].update(chunk[col_city].unique())
        if col_date:
            dates = chunk[col_date].str.strip()
            lo, hi = dates.min(), dates.max()
            stats["date_min"] = min(filter(None, [stats["date_min"], lo]), default=None)
            stats["date_max"] = max(filter(None, [stats["date_max"], hi]), default=None)

        if col_cnpj:
            cnpj_raw = chunk[col_cnpj].str.strip()
            if stats["cnpj_raw_sample"] is None and len(cnpj_raw):
                stats["cnpj_raw_sample"] = cnpj_raw.iloc[0]
            stats["cnpj_masked"] += int(cnpj_raw.str.contains(r"[./-]", regex=True).sum())
            cnpj = cnpj_raw.str.replace(r"\D", "", regex=True)
            stats["cnpjs"].update(cnpj.unique())

            # acumula atributos por CNPJ para o teste de SCD2
            frame = pd.DataFrame({"cnpj": cnpj})
            frame["brand"] = chunk[col_brand].str.strip().str.upper() if col_brand else ""
            frame["name"] = chunk[col_name].str.strip().str.upper() if col_name else ""
            frame["addr"] = (
                chunk[addr_cols].fillna("").agg("|".join, axis=1).str.upper()
                if addr_cols else ""
            )
            for row in frame.drop_duplicates().itertuples(index=False):
                bucket = brands[row.cnpj]
                bucket["brand"].add(row.brand)
                bucket["name"].add(row.name)
                bucket["addr"].add(row.addr)
                bucket["files"].add(path.name)

    return stats


def main(paths: list[str]) -> None:
    brands: dict = defaultdict(
        lambda: {"brand": set(), "name": set(), "addr": set(), "files": set()}
    )
    results = [profile(Path(p), brands) for p in paths]

    lines: list[str] = ["# Perfil da fonte — ANP, levantamento de precos por posto", ""]

    for s in results:
        lines += [
            f"## `{s['path']}`", "",
            f"- encoding detectado: `{s['encoding']}` · delimitador: `{s['delimiter']}`",
            f"- colunas ({len(s['columns'])}): `{', '.join(s['columns'])}`",
            f"- linhas: {s['rows']:,}",
            f"- linhas no escopo (gasolina comum / etanol / S-10): {s['rows_in_scope']:,}",
            f"- CNPJs distintos: {len(s['cnpjs']):,} · municipios: {len(s['cities']):,}",
            f"- CNPJ com mascara: {s['cnpj_masked']:,} (amostra bruta: `{s['cnpj_raw_sample']}`)",
            f"- data da coleta: `{s['date_min']}` a `{s['date_max']}`",
            f"- valor de venda vazio: {s['null_sale']:,} "
            f"({s['null_sale'] / max(s['rows'], 1):.1%})",
            f"- valor de compra vazio: {s['null_purchase']:,} "
            f"({s['null_purchase'] / max(s['rows'], 1):.1%})",
            f"- unidades de medida: {dict(s['units'])}",
            "", "| produto | linhas |", "| --- | ---: |",
        ]
        for product, count in s["products"].most_common():
            lines.append(f"| {product} | {count:,} |")
        lines.append("")

    # teste que decide se o SCD2 tem material
    both = {c: v for c, v in brands.items() if len(v["files"]) == len(results)}
    changed_brand = sum(1 for v in both.values() if len(v["brand"]) > 1)
    changed_name = sum(1 for v in both.values() if len(v["name"]) > 1)
    changed_addr = sum(1 for v in both.values() if len(v["addr"]) > 1)
    total_both = max(len(both), 1)

    lines += [
        "## Teste de SCD Tipo 2", "",
        f"- CNPJs presentes em **todos** os arquivos analisados: {len(both):,}",
        f"- mudaram de **bandeira**: {changed_brand:,} ({changed_brand / total_both:.1%})",
        f"- mudaram de **razao social**: {changed_name:,} ({changed_name / total_both:.1%})",
        f"- mudaram de **endereco**: {changed_addr:,} ({changed_addr / total_both:.1%})",
        "",
        "> Limite inferior: comparando so os extremos da janela, trocas de ida e volta "
        "e mudancas nos semestres intermediarios nao aparecem.",
        "",
    ]

    rows_scope_year = sum(s["rows_in_scope"] for s in results)  # 2 semestres ~ 1 ano
    est_rows = rows_scope_year * 3.5
    lines += [
        "## Orcamento de armazenamento (estimativa)", "",
        f"- linhas no escopo por ano (aprox.): {rows_scope_year:,}",
        f"- projecao para 3,5 anos (2023-01 a 2026-01): {est_rows:,.0f}",
        f"- heap do fato a ~80 B/linha: {est_rows * 80 / 1e6:,.0f} MB",
        f"- com ~30% de indices: {est_rows * 80 * 1.3 / 1e6:,.0f} MB (teto do Neon free: 500 MB)",
        "",
    ]

    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text("\n".join(lines), encoding="utf-8")
    print("\n".join(lines))
    print(f"\n>>> relatorio gravado em {REPORT_PATH}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit("uso: python src/profile_source.py <csv> [<csv> ...]")
    main(sys.argv[1:])
