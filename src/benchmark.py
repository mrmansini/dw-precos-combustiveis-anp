"""Mede as consultas de sql/queries/ em cada cenário de índice e escreve o relatório.

Para cada cenário: cria o índice candidato, atualiza estatísticas, executa cada
consulta três vezes e captura EXPLAIN (ANALYZE, BUFFERS) da última execução,
derruba o índice e passa ao próximo.

Executa três vezes por medida porque a primeira leitura sobe páginas do
armazenamento para o cache; o menor tempo das três é o que se aproxima do
comportamento em regime.

Os índices são criados um de cada vez e derrubados em seguida, por restrição de
espaço. A comparação continua válida: o que registra a diferença é o plano
capturado, não a coexistência dos índices.

Os números publicados em docs/performance.md foram obtidos ANTES da migração
010, quando o fato tinha apenas a chave primária. Depois dela existe um índice
permanente em (station_key, collection_date), e qualquer candidato medido agora
soma-se a ele — para reproduzir a comparação original é preciso derrubar esse
índice antes e recriá-lo depois.

Uso:
    python src/benchmark.py                 # todos os cenários
    python src/benchmark.py --only sem_indice brin_date
"""

from __future__ import annotations

import os
import re
import sys
import time
from pathlib import Path

import psycopg
from dotenv import load_dotenv

QUERY_DIR = Path("sql/queries")
REPORT_PATH = Path("docs/performance.md")
FACT = "core.fct_price_observation"
REPETITIONS = 3

SCENARIOS: list[tuple[str, str | None, str]] = [
    (
        "sem_indice",
        None,
        "Apenas a chave primária (collection_date, station_key, product_key) e o "
        "particionamento por trimestre.",
    ),
    (
        "brin_date",
        f"CREATE INDEX bench_idx ON {FACT} USING brin (collection_date)",
        "BRIN em collection_date. A tabela é carregada em ordem cronológica, "
        "logo a correlação física entre a coluna e a ordem das páginas é alta — "
        "condição em que o BRIN costuma render.",
    ),
    (
        "btree_produto_data",
        f"CREATE INDEX bench_idx ON {FACT} (product_key, collection_date) "
        f"INCLUDE (sale_price)",
        "B-tree em (product_key, collection_date) cobrindo sale_price. Atende as "
        "consultas que filtram por produto, coisa que a chave primária não faz "
        "por começar pela data.",
    ),
    (
        "btree_posto_data",
        f"CREATE INDEX bench_idx ON {FACT} (station_key, collection_date)",
        "B-tree em (station_key, collection_date). Atende o acesso por conjunto "
        "de postos, o padrão da análise de evento.",
    ),
]


def load_queries() -> list[tuple[str, str]]:
    files = sorted(QUERY_DIR.glob("*.sql"))
    if not files:
        sys.exit(f"nenhuma consulta encontrada em {QUERY_DIR.resolve()}")
    return [(f.stem, f.read_text(encoding="utf-8")) for f in files]


def index_size_mb(cur) -> float:
    """Soma o tamanho das partições do índice candidato."""
    cur.execute("""
        SELECT coalesce(sum(pg_relation_size(inhrelid)), 0)
          FROM pg_inherits
         WHERE inhparent = to_regclass('core.bench_idx')
    """)
    return (cur.fetchone()[0] or 0) / 1024 / 1024


def execution_time(plan: str) -> float | None:
    match = re.search(r"Execution Time: ([\d.]+) ms", plan)
    return float(match.group(1)) if match else None


def summarize(plan: str) -> str:
    """Extrai os nós que decidem a leitura, sem o plano inteiro."""
    interesting = (
        "Seq Scan", "Index Scan", "Index Only Scan", "Bitmap Heap Scan",
        "Bitmap Index Scan", "Append", "Partitions",
    )
    lines = [
        line.strip()
        for line in plan.splitlines()
        if any(token in line for token in interesting)
    ]
    return "; ".join(lines[:4]) if lines else "-"


def run_query(cur, sql: str) -> tuple[float, str]:
    """Executa REPETITIONS vezes e devolve o menor tempo e o plano da última."""
    best = float("inf")
    plan = ""
    for _ in range(REPETITIONS):
        started = time.perf_counter()
        cur.execute(f"EXPLAIN (ANALYZE, BUFFERS, TIMING) {sql}")
        plan = "\n".join(row[0] for row in cur.fetchall())
        best = min(best, execution_time(plan) or (time.perf_counter() - started) * 1000)
    return best, plan


def main(argv: list[str]) -> None:
    selected = None
    if "--only" in argv:
        selected = set(argv[argv.index("--only") + 1:])

    load_dotenv()
    dsn = os.getenv("DATABASE_URL")
    if not dsn:
        sys.exit("DATABASE_URL não encontrada no .env")

    queries = load_queries()
    results: dict[str, dict[str, float]] = {}
    plans: dict[str, dict[str, str]] = {}
    sizes: dict[str, float] = {}

    with psycopg.connect(dsn, application_name="benchmark.py", autocommit=True) as conn:
        with conn.cursor() as cur:
            # O índice nasce no schema da tabela, não no search_path.
            cur.execute("DROP INDEX IF EXISTS core.bench_idx")
            print("atualizando estatísticas...")
            cur.execute(f"ANALYZE {FACT}")
            cur.execute("ANALYZE core.dim_station")

            for name, ddl, _ in SCENARIOS:
                if selected and name not in selected:
                    continue

                print(f"\ncenário: {name}")
                if ddl:
                    started = time.perf_counter()
                    cur.execute(ddl)
                    cur.execute(f"ANALYZE {FACT}")
                    sizes[name] = index_size_mb(cur)
                    print(f"  índice criado em {time.perf_counter() - started:.1f}s"
                          f"  ({sizes[name]:.1f} MB)")
                else:
                    sizes[name] = 0.0

                results[name] = {}
                plans[name] = {}
                for query_name, sql in queries:
                    elapsed, plan = run_query(cur, sql)
                    results[name][query_name] = elapsed
                    plans[name][query_name] = plan
                    print(f"  {query_name:<32} {elapsed:>9.1f} ms")

                if ddl:
                    cur.execute("DROP INDEX core.bench_idx")

    write_report(queries, results, plans, sizes, selected)


def write_report(queries, results, plans, sizes, selected) -> None:
    scenarios = [s for s in SCENARIOS if not selected or s[0] in selected]
    baseline = results.get("sem_indice", {})

    out: list[str] = [
        "# Medição de desempenho",
        "",
        "Tempos em milissegundos, menor de três execuções. Cada índice candidato "
        "foi criado sozinho, medido e derrubado — a comparação está nos planos "
        "capturados, não na coexistência dos índices.",
        "",
        "O ambiente é uma instância de computação pequena com cache reduzido, "
        "então os números absolutos são maiores do que seriam num servidor "
        "dedicado. O que interessa é a razão entre cenários e o nó de leitura "
        "escolhido pelo planejador.",
        "",
        "## Cenários",
        "",
    ]
    for name, _, description in scenarios:
        size = sizes.get(name, 0.0)
        out.append(f"**`{name}`** — {description}"
                   + (f" Tamanho: {size:.1f} MB." if size else ""))
        out.append("")

    out += ["## Tempos", "", "| consulta | " +
            " | ".join(f"`{s[0]}`" for s in scenarios) + " |",
            "| --- |" + " ---: |" * len(scenarios)]

    for query_name, _ in queries:
        cells = []
        for name, _, _ in scenarios:
            value = results.get(name, {}).get(query_name)
            if value is None:
                cells.append("-")
                continue
            base = baseline.get(query_name)
            if base and name != "sem_indice":
                cells.append(f"{value:,.0f} ({value / base:.2f}x)")
            else:
                cells.append(f"{value:,.0f}")
        out.append(f"| `{query_name}` | " + " | ".join(cells) + " |")

    out += ["", "## Nós de leitura escolhidos", ""]
    for query_name, _ in queries:
        out += [f"### `{query_name}`", ""]
        for name, _, _ in scenarios:
            plan = plans.get(name, {}).get(query_name)
            if plan:
                out.append(f"- **{name}**: {summarize(plan)}")
        out.append("")

    out += ["## Planos completos", ""]
    for query_name, _ in queries:
        for name, _, _ in scenarios:
            plan = plans.get(name, {}).get(query_name)
            if not plan:
                continue
            out += [f"<details><summary><code>{query_name}</code> — "
                    f"<code>{name}</code></summary>", "", "```", plan, "```", "",
                    "</details>", ""]

    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)

    if selected:
        # Execução parcial não substitui o relatório comparativo: ele contém
        # cenários que esta execução não mediu, e sobrescrevê-lo perderia tanto
        # os planos ausentes quanto qualquer texto acrescentado depois.
        partial = REPORT_PATH.with_name("performance-parcial.md")
        partial.write_text("\n".join(out), encoding="utf-8")
        print(f"\nexecução parcial — relatório em {partial}")
        return

    REPORT_PATH.write_text("\n".join(out), encoding="utf-8")
    print(f"\nrelatório em {REPORT_PATH}")


if __name__ == "__main__":
    main(sys.argv[1:])
