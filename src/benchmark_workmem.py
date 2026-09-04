"""Mede o efeito de work_mem nas consultas analíticas.

Os planos do benchmark de índices mostraram ordenação em disco (external merge)
e agregação em lotes, sinal de que o gargalo das consultas de agregação ampla é
memória de trabalho, não acesso à tabela. Este script isola essa variável.

work_mem é definido por sessão: não altera a configuração do servidor nem afeta
outras conexões.

Uso: python src/benchmark_workmem.py
"""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path

import psycopg
from dotenv import load_dotenv

QUERY_DIR = Path("sql/queries")
REPORT_PATH = Path("docs/performance-memoria.md")
SETTINGS = ["4MB", "16MB", "64MB", "256MB"]
REPETITIONS = 3


def execution_time(plan: str) -> float:
    match = re.search(r"Execution Time: ([\d.]+) ms", plan)
    return float(match.group(1)) if match else float("nan")


def spill(plan: str) -> str:
    marks = []
    for line in plan.splitlines():
        line = line.strip()
        if "Sort Method" in line or "Disk Usage" in line:
            marks.append(line)
    return "; ".join(marks[:2]) if marks else "tudo em memória"


def main() -> None:
    load_dotenv()
    dsn = os.getenv("DATABASE_URL")
    if not dsn:
        sys.exit("DATABASE_URL não encontrada no .env")

    queries = [(f.stem, f.read_text(encoding="utf-8"))
               for f in sorted(QUERY_DIR.glob("*.sql"))]

    times: dict[str, dict[str, float]] = {}
    spills: dict[str, dict[str, str]] = {}

    with psycopg.connect(dsn, application_name="benchmark_workmem.py",
                         autocommit=True) as conn, conn.cursor() as cur:
        cur.execute("SHOW work_mem")
        print("work_mem do servidor:", cur.fetchone()[0])

        for setting in SETTINGS:
            cur.execute(f"SET work_mem = '{setting}'")
            print(f"\nwork_mem = {setting}")
            times[setting] = {}
            spills[setting] = {}
            for name, sql in queries:
                best, plan = float("inf"), ""
                for _ in range(REPETITIONS):
                    cur.execute(f"EXPLAIN (ANALYZE, BUFFERS) {sql}")
                    plan = "\n".join(row[0] for row in cur.fetchall())
                    best = min(best, execution_time(plan))
                times[setting][name] = best
                spills[setting][name] = spill(plan)
                print(f"  {name:<32} {best:>9.1f} ms   {spills[setting][name]}")

    base = times[SETTINGS[0]]
    out = [
        "# Efeito de work_mem",
        "",
        "Tempos em milissegundos, menor de três execuções. work_mem definido por "
        "sessão, sem alterar a configuração do servidor.",
        "",
        "| consulta | " + " | ".join(SETTINGS) + " |",
        "| --- |" + " ---: |" * len(SETTINGS),
    ]
    for name, _ in queries:
        cells = []
        for setting in SETTINGS:
            value = times[setting][name]
            cells.append(f"{value:,.0f}" if setting == SETTINGS[0]
                         else f"{value:,.0f} ({value / base[name]:.2f}x)")
        out.append(f"| `{name}` | " + " | ".join(cells) + " |")

    out += ["", "## Transbordo para disco", ""]
    for name, _ in queries:
        out.append(f"### `{name}`")
        out.append("")
        for setting in SETTINGS:
            out.append(f"- **{setting}**: {spills[setting][name]}")
        out.append("")

    REPORT_PATH.write_text("\n".join(out), encoding="utf-8")
    print(f"\nrelatório em {REPORT_PATH}")


if __name__ == "__main__":
    main()
