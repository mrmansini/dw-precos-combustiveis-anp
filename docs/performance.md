# Medição de desempenho

Tempos em milissegundos, menor de três execuções. Cada índice candidato foi criado sozinho, medido e derrubado — a comparação está nos planos capturados, não na coexistência dos índices.

O ambiente é uma instância de computação pequena com cache reduzido, então os números absolutos são maiores do que seriam num servidor dedicado. O que interessa é a razão entre cenários e o nó de leitura escolhido pelo planejador.

## Cenários

**`sem_indice`** — Apenas a chave primária (collection_date, station_key, product_key) e o particionamento por trimestre.

**`brin_date`** — BRIN em collection_date. A tabela é carregada em ordem cronológica, logo a correlação física entre a coluna e a ordem das páginas é alta — condição em que o BRIN costuma render. Tamanho: 0.4 MB.

**`btree_produto_data`** — B-tree em (product_key, collection_date) cobrindo sale_price. Atende as consultas que filtram por produto, coisa que a chave primária não faz por começar pela data. Tamanho: 91.5 MB.

**`btree_posto_data`** — B-tree em (station_key, collection_date). Atende o acesso por conjunto de postos, o padrão da análise de evento. Tamanho: 46.2 MB.

## Tempos

| consulta | `sem_indice` | `brin_date` | `btree_produto_data` | `btree_posto_data` |
| --- | ---: | ---: | ---: | ---: |
| `01_serie_semanal_por_uf` | 452 | 470 (1.04x) | 434 (0.96x) | 457 (1.01x) |
| `02_dispersao_intramunicipal` | 631 | 607 (0.96x) | 601 (0.95x) | 618 (0.98x) |
| `03_paridade_etanol_gasolina` | 939 | 960 (1.02x) | 951 (1.01x) | 960 (1.02x) |
| `04_evento_troca_bandeira` | 215 | 226 (1.05x) | 254 (1.18x) | 100 (0.47x) |

## Nós de leitura escolhidos

### `01_serie_semanal_por_uf`

- **sem_indice**: ->  Append  (cost=0.00..19092.54 rows=212048 width=18) (actual time=0.006..70.434 rows=212528.00 loops=1); ->  Seq Scan on fct_price_observation_2025q3 f_1  (cost=0.00..4102.59 rows=48152 width=18) (actual time=0.006..13.077 rows=48601.00 loops=1); ->  Seq Scan on fct_price_observation_2025q4 f_2  (cost=0.00..4486.53 rows=53213 width=18) (actual time=0.023..15.003 rows=53004.00 loops=1); ->  Seq Scan on fct_price_observation_2026q1 f_3  (cost=0.00..4646.54 rows=54211 width=18) (actual time=0.026..14.264 rows=54662.00 loops=1)
- **brin_date**: ->  Append  (cost=0.00..19088.12 rows=211165 width=18) (actual time=0.009..72.866 rows=212528.00 loops=1); ->  Seq Scan on fct_price_observation_2025q3 f_1  (cost=0.00..4102.59 rows=48384 width=18) (actual time=0.008..13.042 rows=48601.00 loops=1); ->  Seq Scan on fct_price_observation_2025q4 f_2  (cost=0.00..4486.53 rows=52390 width=18) (actual time=0.021..14.693 rows=53004.00 loops=1); ->  Seq Scan on fct_price_observation_2026q1 f_3  (cost=0.00..4646.54 rows=54162 width=18) (actual time=0.021..13.782 rows=54662.00 loops=1)
- **btree_produto_data**: ->  Append  (cost=1268.64..15668.59 rows=212826 width=18) (actual time=1.570..55.231 rows=212528.00 loops=1); ->  Bitmap Heap Scan on fct_price_observation_2025q3 f_1  (cost=1268.64..3356.52 rows=49192 width=18) (actual time=1.569..8.613 rows=48601.00 loops=1); ->  Bitmap Index Scan on fct_price_observation_2025q3_product_key_collection_date_sa_idx  (cost=0.00..1256.34 rows=49192 width=0) (actual time=1.413..1.414 rows=48601.00 loops=1); ->  Bitmap Heap Scan on fct_price_observation_2025q4 f_2  (cost=1357.73..3625.90 rows=52811 width=18) (actual time=1.576..9.640 rows=53004.00 loops=1)
- **btree_posto_data**: ->  Append  (cost=0.00..19096.93 rows=212927 width=18) (actual time=0.007..73.159 rows=212528.00 loops=1); ->  Seq Scan on fct_price_observation_2025q3 f_1  (cost=0.00..4102.59 rows=48727 width=18) (actual time=0.006..14.376 rows=48601.00 loops=1); ->  Seq Scan on fct_price_observation_2025q4 f_2  (cost=0.00..4486.53 rows=53213 width=18) (actual time=0.024..14.811 rows=53004.00 loops=1); ->  Seq Scan on fct_price_observation_2026q1 f_3  (cost=0.00..4646.54 rows=54980 width=18) (actual time=0.028..14.749 rows=54662.00 loops=1)

### `02_dispersao_intramunicipal`

- **sem_indice**: ->  Append  (cost=0.00..21054.76 rows=211193 width=18) (actual time=0.007..73.927 rows=212423.00 loops=1); ->  Seq Scan on fct_price_observation_2025q1 f_1  (cost=0.00..5159.77 rows=54026 width=18) (actual time=0.006..17.268 rows=54652.00 loops=1); ->  Seq Scan on fct_price_observation_2025q2 f_2  (cost=0.00..5289.39 rows=55802 width=18) (actual time=0.019..15.149 rows=56166.00 loops=1); ->  Seq Scan on fct_price_observation_2025q3 f_3  (cost=0.00..4561.36 rows=48152 width=18) (actual time=0.021..13.701 rows=48601.00 loops=1)
- **brin_date**: ->  Append  (cost=0.00..21061.63 rows=212567 width=18) (actual time=0.007..74.572 rows=212423.00 loops=1); ->  Seq Scan on fct_price_observation_2025q1 f_1  (cost=0.00..5159.77 rows=55239 width=18) (actual time=0.007..17.130 rows=54652.00 loops=1); ->  Seq Scan on fct_price_observation_2025q2 f_2  (cost=0.00..5289.39 rows=56554 width=18) (actual time=0.023..15.557 rows=56166.00 loops=1); ->  Seq Scan on fct_price_observation_2025q3 f_3  (cost=0.00..4561.36 rows=48384 width=18) (actual time=0.026..13.919 rows=48601.00 loops=1)
- **btree_produto_data**: ->  Append  (cost=1552.13..16766.79 rows=213762 width=18) (actual time=1.633..56.237 rows=212423.00 loops=1); ->  Bitmap Heap Scan on fct_price_observation_2025q1 f_1  (cost=1552.13..4039.51 rows=54879 width=18) (actual time=1.632..9.515 rows=54652.00 loops=1); ->  Bitmap Index Scan on fct_price_observation_2025q1_product_key_collection_date_sa_idx  (cost=0.00..1538.41 rows=54879 width=0) (actual time=1.472..1.472 rows=54652.00 loops=1); ->  Bitmap Heap Scan on fct_price_observation_2025q2 f_2  (cost=1605.64..4166.04 rows=56880 width=18) (actual time=1.657..10.917 rows=56166.00 loops=1)
- **btree_posto_data**: ->  Append  (cost=0.00..21061.25 rows=212490 width=18) (actual time=0.008..79.219 rows=212423.00 loops=1); ->  Seq Scan on fct_price_observation_2025q1 f_1  (cost=0.00..5159.77 rows=54649 width=18) (actual time=0.007..16.465 rows=54652.00 loops=1); ->  Seq Scan on fct_price_observation_2025q2 f_2  (cost=0.00..5289.39 rows=55901 width=18) (actual time=0.014..15.862 rows=56166.00 loops=1); ->  Seq Scan on fct_price_observation_2025q3 f_3  (cost=0.00..4561.36 rows=48727 width=18) (actual time=0.015..17.715 rows=48601.00 loops=1)

### `03_paridade_etanol_gasolina`

- **sem_indice**: Planned Partitions: 8  Batches: 9  Memory Usage: 8273kB  Disk Usage: 6672kB; ->  Append  (cost=0.00..52637.85 rows=1024317 width=20) (actual time=0.007..289.874 rows=1025310.00 loops=1); ->  Seq Scan on fct_price_observation_2024q1 f_1  (cost=0.00..5331.62 rows=113490 width=20) (actual time=0.007..26.191 rows=112966.00 loops=1); ->  Seq Scan on fct_price_observation_2024q2 f_2  (cost=0.00..5334.48 rows=114297 width=20) (actual time=0.028..26.497 rows=113350.00 loops=1)
- **brin_date**: Planned Partitions: 8  Batches: 9  Memory Usage: 8273kB  Disk Usage: 6672kB; ->  Append  (cost=0.00..52654.86 rows=1027720 width=20) (actual time=0.010..298.716 rows=1025310.00 loops=1); ->  Seq Scan on fct_price_observation_2024q1 f_1  (cost=0.00..5331.62 rows=113911 width=20) (actual time=0.009..23.564 rows=112966.00 loops=1); ->  Seq Scan on fct_price_observation_2024q2 f_2  (cost=0.00..5334.48 rows=113995 width=20) (actual time=0.028..24.984 rows=113350.00 loops=1)
- **btree_produto_data**: Planned Partitions: 8  Batches: 9  Memory Usage: 8273kB  Disk Usage: 6672kB; ->  Append  (cost=0.00..52649.90 rows=1026728 width=20) (actual time=0.006..294.976 rows=1025310.00 loops=1); ->  Seq Scan on fct_price_observation_2024q1 f_1  (cost=0.00..5331.62 rows=114086 width=20) (actual time=0.006..25.989 rows=112966.00 loops=1); ->  Seq Scan on fct_price_observation_2024q2 f_2  (cost=0.00..5334.48 rows=114042 width=20) (actual time=0.027..27.012 rows=113350.00 loops=1)
- **btree_posto_data**: Planned Partitions: 8  Batches: 9  Memory Usage: 8273kB  Disk Usage: 6672kB; ->  Append  (cost=0.00..52647.38 rows=1026223 width=20) (actual time=0.007..309.074 rows=1025310.00 loops=1); ->  Seq Scan on fct_price_observation_2024q1 f_1  (cost=0.00..5331.62 rows=112838 width=20) (actual time=0.007..28.740 rows=112966.00 loops=1); ->  Seq Scan on fct_price_observation_2024q2 f_2  (cost=0.00..5334.48 rows=114329 width=20) (actual time=0.028..29.730 rows=113350.00 loops=1)

### `04_evento_troca_bandeira`

- **sem_indice**: ->  Seq Scan on dim_station prev  (cost=0.00..594.31 rows=17631 width=31) (actual time=0.011..1.607 rows=17631.00 loops=1); ->  Seq Scan on dim_brand b_prev  (cost=0.00..1.51 rows=51 width=5) (actual time=0.005..0.011 rows=56.00 loops=1); ->  Seq Scan on dim_brand b_curr  (cost=0.00..1.51 rows=51 width=5) (actual time=0.006..0.010 rows=56.00 loops=1); ->  Index Scan using dim_station_brand_idx on dim_station curr  (cost=0.29..36.12 rows=82 width=31) (actual time=0.004..0.541 rows=1837.00 loops=55)
- **brin_date**: ->  Seq Scan on dim_station prev  (cost=0.00..594.31 rows=17631 width=31) (actual time=0.015..1.640 rows=17631.00 loops=1); ->  Seq Scan on dim_brand b_prev  (cost=0.00..1.51 rows=51 width=5) (actual time=0.006..0.014 rows=56.00 loops=1); ->  Seq Scan on dim_brand b_curr  (cost=0.00..1.51 rows=51 width=5) (actual time=0.005..0.009 rows=56.00 loops=1); ->  Index Scan using dim_station_brand_idx on dim_station curr  (cost=0.29..36.12 rows=82 width=31) (actual time=0.005..0.601 rows=1837.00 loops=55)
- **btree_produto_data**: ->  Seq Scan on dim_station prev  (cost=0.00..594.31 rows=17631 width=31) (actual time=0.012..1.705 rows=17631.00 loops=1); ->  Seq Scan on dim_brand b_prev  (cost=0.00..1.51 rows=51 width=5) (actual time=0.006..0.017 rows=56.00 loops=1); ->  Seq Scan on dim_brand b_curr  (cost=0.00..1.51 rows=51 width=5) (actual time=0.006..0.010 rows=56.00 loops=1); ->  Index Scan using dim_station_brand_idx on dim_station curr  (cost=0.29..36.12 rows=82 width=31) (actual time=0.006..0.580 rows=1837.00 loops=55)
- **btree_posto_data**: ->  Seq Scan on dim_station prev  (cost=0.00..594.31 rows=17631 width=31) (actual time=0.013..1.383 rows=17631.00 loops=1); ->  Seq Scan on dim_brand b_prev  (cost=0.00..1.51 rows=51 width=5) (actual time=0.007..0.024 rows=56.00 loops=1); ->  Seq Scan on dim_brand b_curr  (cost=0.00..1.51 rows=51 width=5) (actual time=0.006..0.011 rows=56.00 loops=1); ->  Index Scan using dim_station_brand_idx on dim_station curr  (cost=0.29..36.12 rows=82 width=31) (actual time=0.006..0.586 rows=1837.00 loops=55)

## Planos completos

<details><summary><code>01_serie_semanal_por_uf</code> — <code>sem_indice</code></summary>

```
GroupAggregate  (cost=45493.02..49822.41 rows=7074 width=35) (actual time=370.889..460.706 rows=1425.00 loops=1)
  Group Key: d.survey_week_key, c.uf, d.week_start_date
  Buffers: shared hit=6374, temp read=1095 written=1098
  ->  Sort  (cost=45493.02..46023.14 rows=212048 width=25) (actual time=370.837..388.550 rows=212528.00 loops=1)
        Sort Key: d.survey_week_key, c.uf, d.week_start_date, f.station_key
        Sort Method: external merge  Disk: 8760kB
        Buffers: shared hit=6374, temp read=1095 written=1098
        ->  Hash Join  (cost=889.16..21658.10 rows=212048 width=25) (actual time=4.942..186.673 rows=212528.00 loops=1)
              Hash Cond: (s.city_key = c.city_key)
              Buffers: shared hit=6374
              ->  Hash Join  (cost=874.78..21082.00 rows=212048 width=26) (actual time=4.840..157.048 rows=212528.00 loops=1)
                    Hash Cond: (f.station_key = s.station_key)
                    Buffers: shared hit=6370
                    ->  Hash Join  (cost=60.09..19710.54 rows=212048 width=22) (actual time=0.367..98.332 rows=212528.00 loops=1)
                          Hash Cond: (f.collection_date = d.full_date)
                          Buffers: shared hit=5952
                          ->  Append  (cost=0.00..19092.54 rows=212048 width=18) (actual time=0.006..70.434 rows=212528.00 loops=1)
                                Buffers: shared hit=5933
                                ->  Seq Scan on fct_price_observation_2025q3 f_1  (cost=0.00..4102.59 rows=48152 width=18) (actual time=0.006..13.077 rows=48601.00 loops=1)
                                      Filter: ((collection_date >= '2025-07-01'::date) AND (product_key = 1))
                                      Rows Removed by Filter: 134905
                                      Buffers: shared hit=1350
                                ->  Seq Scan on fct_price_observation_2025q4 f_2  (cost=0.00..4486.53 rows=53213 width=18) (actual time=0.023..15.003 rows=53004.00 loops=1)
                                      Filter: ((collection_date >= '2025-07-01'::date) AND (product_key = 1))
                                      Rows Removed by Filter: 147698
                                      Buffers: shared hit=1476
                                ->  Seq Scan on fct_price_observation_2026q1 f_3  (cost=0.00..4646.54 rows=54211 width=18) (actual time=0.026..14.264 rows=54662.00 loops=1)
                                      Filter: ((collection_date >= '2025-07-01'::date) AND (product_key = 1))
                                      Rows Removed by Filter: 153174
                                      Buffers: shared hit=1529
                                ->  Seq Scan on fct_price_observation_2026q2 f_4  (cost=0.00..4796.64 rows=56469 width=18) (actual time=0.022..14.408 rows=56261.00 loops=1)
                                      Filter: ((collection_date >= '2025-07-01'::date) AND (product_key = 1))
                                      Rows Removed by Filter: 158315
                                      Buffers: shared hit=1578
                                ->  Seq Scan on fct_price_observation_2026q3 f_5  (cost=0.00..0.00 rows=1 width=26) (actual time=0.020..0.020 rows=0.00 loops=1)
                                      Filter: ((collection_date >= '2025-07-01'::date) AND (product_key = 1))
                                ->  Seq Scan on fct_price_observation_2026q4 f_6  (cost=0.00..0.00 rows=1 width=26) (actual time=0.005..0.005 rows=0.00 loops=1)
                                      Filter: ((collection_date >= '2025-07-01'::date) AND (product_key = 1))
                                ->  Seq Scan on fct_price_observation_default f_7  (cost=0.00..0.00 rows=1 width=26) (actual time=0.004..0.005 rows=0.00 loops=1)
                                      Filter: ((collection_date >= '2025-07-01'::date) AND (product_key = 1))
                          ->  Hash  (cost=37.26..37.26 rows=1826 width=12) (actual time=0.356..0.358 rows=1826.00 loops=1)
                                Buckets: 2048  Batches: 1  Memory Usage: 95kB
                                Buffers: shared hit=19
                                ->  Seq Scan on dim_date d  (cost=0.00..37.26 rows=1826 width=12) (actual time=0.005..0.184 rows=1826.00 loops=1)
                                      Buffers: shared hit=19
                    ->  Hash  (cost=594.31..594.31 rows=17631 width=12) (actual time=4.437..4.438 rows=17631.00 loops=1)
                          Buckets: 32768  Batches: 1  Memory Usage: 1014kB
                          Buffers: shared hit=418
                          ->  Seq Scan on dim_station s  (cost=0.00..594.31 rows=17631 width=12) (actual time=0.008..2.509 rows=17631.00 loops=1)
                                Buffers: shared hit=418
              ->  Hash  (cost=8.61..8.61 rows=461 width=7) (actual time=0.096..0.097 rows=462.00 loops=1)
                    Buckets: 1024  Batches: 1  Memory Usage: 27kB
                    Buffers: shared hit=4
                    ->  Seq Scan on dim_city c  (cost=0.00..8.61 rows=461 width=7) (actual time=0.011..0.048 rows=462.00 loops=1)
                          Buffers: shared hit=4
Planning:
  Buffers: shared hit=33
Planning Time: 1.846 ms
Execution Time: 461.636 ms
```

</details>

<details><summary><code>01_serie_semanal_por_uf</code> — <code>brin_date</code></summary>

```
GroupAggregate  (cost=45376.16..49687.88 rows=7074 width=35) (actual time=375.548..468.863 rows=1425.00 loops=1)
  Group Key: d.survey_week_key, c.uf, d.week_start_date
  Buffers: shared hit=6374, temp read=1095 written=1098
  ->  Sort  (cost=45376.16..45904.07 rows=211165 width=25) (actual time=375.497..394.018 rows=212528.00 loops=1)
        Sort Key: d.survey_week_key, c.uf, d.week_start_date, f.station_key
        Sort Method: external merge  Disk: 8760kB
        Buffers: shared hit=6374, temp read=1095 written=1098
        ->  Hash Join  (cost=889.16..21646.71 rows=211165 width=25) (actual time=5.000..193.096 rows=212528.00 loops=1)
              Hash Cond: (s.city_key = c.city_key)
              Buffers: shared hit=6374
              ->  Hash Join  (cost=874.78..21072.95 rows=211165 width=26) (actual time=4.896..160.093 rows=212528.00 loops=1)
                    Hash Cond: (f.station_key = s.station_key)
                    Buffers: shared hit=6370
                    ->  Hash Join  (cost=60.09..19703.81 rows=211165 width=22) (actual time=0.374..101.592 rows=212528.00 loops=1)
                          Hash Cond: (f.collection_date = d.full_date)
                          Buffers: shared hit=5952
                          ->  Append  (cost=0.00..19088.12 rows=211165 width=18) (actual time=0.009..72.866 rows=212528.00 loops=1)
                                Buffers: shared hit=5933
                                ->  Seq Scan on fct_price_observation_2025q3 f_1  (cost=0.00..4102.59 rows=48384 width=18) (actual time=0.008..13.042 rows=48601.00 loops=1)
                                      Filter: ((collection_date >= '2025-07-01'::date) AND (product_key = 1))
                                      Rows Removed by Filter: 134905
                                      Buffers: shared hit=1350
                                ->  Seq Scan on fct_price_observation_2025q4 f_2  (cost=0.00..4486.53 rows=52390 width=18) (actual time=0.021..14.693 rows=53004.00 loops=1)
                                      Filter: ((collection_date >= '2025-07-01'::date) AND (product_key = 1))
                                      Rows Removed by Filter: 147698
                                      Buffers: shared hit=1476
                                ->  Seq Scan on fct_price_observation_2026q1 f_3  (cost=0.00..4646.54 rows=54162 width=18) (actual time=0.021..13.782 rows=54662.00 loops=1)
                                      Filter: ((collection_date >= '2025-07-01'::date) AND (product_key = 1))
                                      Rows Removed by Filter: 153174
                                      Buffers: shared hit=1529
                                ->  Seq Scan on fct_price_observation_2026q2 f_4  (cost=0.00..4796.64 rows=56226 width=18) (actual time=0.022..18.220 rows=56261.00 loops=1)
                                      Filter: ((collection_date >= '2025-07-01'::date) AND (product_key = 1))
                                      Rows Removed by Filter: 158315
                                      Buffers: shared hit=1578
                                ->  Seq Scan on fct_price_observation_2026q3 f_5  (cost=0.00..0.00 rows=1 width=26) (actual time=0.019..0.019 rows=0.00 loops=1)
                                      Filter: ((collection_date >= '2025-07-01'::date) AND (product_key = 1))
                                ->  Seq Scan on fct_price_observation_2026q4 f_6  (cost=0.00..0.00 rows=1 width=26) (actual time=0.005..0.006 rows=0.00 loops=1)
                                      Filter: ((collection_date >= '2025-07-01'::date) AND (product_key = 1))
                                ->  Seq Scan on fct_price_observation_default f_7  (cost=0.00..0.00 rows=1 width=26) (actual time=0.005..0.005 rows=0.00 loops=1)
                                      Filter: ((collection_date >= '2025-07-01'::date) AND (product_key = 1))
                          ->  Hash  (cost=37.26..37.26 rows=1826 width=12) (actual time=0.360..0.362 rows=1826.00 loops=1)
                                Buckets: 2048  Batches: 1  Memory Usage: 95kB
                                Buffers: shared hit=19
                                ->  Seq Scan on dim_date d  (cost=0.00..37.26 rows=1826 width=12) (actual time=0.005..0.186 rows=1826.00 loops=1)
                                      Buffers: shared hit=19
                    ->  Hash  (cost=594.31..594.31 rows=17631 width=12) (actual time=4.485..4.486 rows=17631.00 loops=1)
                          Buckets: 32768  Batches: 1  Memory Usage: 1014kB
                          Buffers: shared hit=418
                          ->  Seq Scan on dim_station s  (cost=0.00..594.31 rows=17631 width=12) (actual time=0.007..2.500 rows=17631.00 loops=1)
                                Buffers: shared hit=418
              ->  Hash  (cost=8.61..8.61 rows=461 width=7) (actual time=0.099..0.099 rows=462.00 loops=1)
                    Buckets: 1024  Batches: 1  Memory Usage: 27kB
                    Buffers: shared hit=4
                    ->  Seq Scan on dim_city c  (cost=0.00..8.61 rows=461 width=7) (actual time=0.012..0.049 rows=462.00 loops=1)
                          Buffers: shared hit=4
Planning:
  Buffers: shared hit=42
Planning Time: 2.075 ms
Execution Time: 469.908 ms
```

</details>

<details><summary><code>01_serie_semanal_por_uf</code> — <code>btree_produto_data</code></summary>

```
GroupAggregate  (cost=42167.19..46512.13 rows=7074 width=35) (actual time=341.679..433.034 rows=1425.00 loops=1)
  Group Key: d.survey_week_key, c.uf, d.week_start_date
  Buffers: shared hit=7199, temp read=1095 written=1098
  ->  Sort  (cost=42167.19..42699.25 rows=212826 width=25) (actual time=341.634..359.741 rows=212528.00 loops=1)
        Sort Key: d.survey_week_key, c.uf, d.week_start_date, f.station_key
        Sort Method: external merge  Disk: 8760kB
        Buffers: shared hit=7199, temp read=1095 written=1098
        ->  Hash Join  (cost=2157.79..18240.31 rows=212826 width=25) (actual time=6.082..161.732 rows=212528.00 loops=1)
              Hash Cond: (s.city_key = c.city_key)
              Buffers: shared hit=7199
              ->  Hash Join  (cost=2143.42..17662.14 rows=212826 width=26) (actual time=5.983..132.856 rows=212528.00 loops=1)
                    Hash Cond: (f.station_key = s.station_key)
                    Buffers: shared hit=7195
                    ->  Hash Join  (cost=1328.72..16288.65 rows=212826 width=22) (actual time=1.964..82.440 rows=212528.00 loops=1)
                          Hash Cond: (f.collection_date = d.full_date)
                          Buffers: shared hit=6777
                          ->  Append  (cost=1268.64..15668.59 rows=212826 width=18) (actual time=1.570..55.231 rows=212528.00 loops=1)
                                Buffers: shared hit=6758
                                ->  Bitmap Heap Scan on fct_price_observation_2025q3 f_1  (cost=1268.64..3356.52 rows=49192 width=18) (actual time=1.569..8.613 rows=48601.00 loops=1)
                                      Recheck Cond: ((product_key = 1) AND (collection_date >= '2025-07-01'::date))
                                      Heap Blocks: exact=1350
                                      Buffers: shared hit=1539
                                      ->  Bitmap Index Scan on fct_price_observation_2025q3_product_key_collection_date_sa_idx  (cost=0.00..1256.34 rows=49192 width=0) (actual time=1.413..1.414 rows=48601.00 loops=1)
                                            Index Cond: ((product_key = 1) AND (collection_date >= '2025-07-01'::date))
                                            Index Searches: 1
                                            Buffers: shared hit=189
                                ->  Bitmap Heap Scan on fct_price_observation_2025q4 f_2  (cost=1357.73..3625.90 rows=52811 width=18) (actual time=1.576..9.640 rows=53004.00 loops=1)
                                      Recheck Cond: ((product_key = 1) AND (collection_date >= '2025-07-01'::date))
                                      Heap Blocks: exact=1476
                                      Buffers: shared hit=1682
                                      ->  Bitmap Index Scan on fct_price_observation_2025q4_product_key_collection_date_sa_idx  (cost=0.00..1344.53 rows=52811 width=0) (actual time=1.419..1.419 rows=53004.00 loops=1)
                                            Index Cond: ((product_key = 1) AND (collection_date >= '2025-07-01'::date))
                                            Index Searches: 1
                                            Buffers: shared hit=206
                                ->  Bitmap Heap Scan on fct_price_observation_2026q1 f_3  (cost=1397.08..3740.70 rows=54308 width=18) (actual time=1.691..10.651 rows=54662.00 loops=1)
                                      Recheck Cond: ((product_key = 1) AND (collection_date >= '2025-07-01'::date))
                                      Heap Blocks: exact=1529
                                      Buffers: shared hit=1741
                                      ->  Bitmap Index Scan on fct_price_observation_2026q1_product_key_collection_date_sa_idx  (cost=0.00..1383.50 rows=54308 width=0) (actual time=1.526..1.526 rows=54662.00 loops=1)
                                            Index Cond: ((product_key = 1) AND (collection_date >= '2025-07-01'::date))
                                            Index Searches: 1
                                            Buffers: shared hit=212
                                ->  Bitmap Heap Scan on fct_price_observation_2026q2 f_4  (cost=1455.67..3881.35 rows=56512 width=18) (actual time=1.714..10.979 rows=56261.00 loops=1)
                                      Recheck Cond: ((product_key = 1) AND (collection_date >= '2025-07-01'::date))
                                      Heap Blocks: exact=1578
                                      Buffers: shared hit=1796
                                      ->  Bitmap Index Scan on fct_price_observation_2026q2_product_key_collection_date_sa_idx  (cost=0.00..1441.54 rows=56512 width=0) (actual time=1.547..1.547 rows=56261.00 loops=1)
                                            Index Cond: ((product_key = 1) AND (collection_date >= '2025-07-01'::date))
                                            Index Searches: 1
                                            Buffers: shared hit=218
                                ->  Seq Scan on fct_price_observation_2026q3 f_5  (cost=0.00..0.00 rows=1 width=26) (actual time=0.016..0.017 rows=0.00 loops=1)
                                      Filter: ((collection_date >= '2025-07-01'::date) AND (product_key = 1))
                                ->  Seq Scan on fct_price_observation_2026q4 f_6  (cost=0.00..0.00 rows=1 width=26) (actual time=0.004..0.004 rows=0.00 loops=1)
                                      Filter: ((collection_date >= '2025-07-01'::date) AND (product_key = 1))
                                ->  Seq Scan on fct_price_observation_default f_7  (cost=0.00..0.00 rows=1 width=26) (actual time=0.005..0.005 rows=0.00 loops=1)
                                      Filter: ((collection_date >= '2025-07-01'::date) AND (product_key = 1))
                          ->  Hash  (cost=37.26..37.26 rows=1826 width=12) (actual time=0.386..0.387 rows=1826.00 loops=1)
                                Buckets: 2048  Batches: 1  Memory Usage: 95kB
                                Buffers: shared hit=19
                                ->  Seq Scan on dim_date d  (cost=0.00..37.26 rows=1826 width=12) (actual time=0.013..0.209 rows=1826.00 loops=1)
                                      Buffers: shared hit=19
                    ->  Hash  (cost=594.31..594.31 rows=17631 width=12) (actual time=3.991..3.991 rows=17631.00 loops=1)
                          Buckets: 32768  Batches: 1  Memory Usage: 1014kB
                          Buffers: shared hit=418
                          ->  Seq Scan on dim_station s  (cost=0.00..594.31 rows=17631 width=12) (actual time=0.005..2.140 rows=17631.00 loops=1)
                                Buffers: shared hit=418
              ->  Hash  (cost=8.61..8.61 rows=461 width=7) (actual time=0.095..0.096 rows=462.00 loops=1)
                    Buckets: 1024  Batches: 1  Memory Usage: 27kB
                    Buffers: shared hit=4
                    ->  Seq Scan on dim_city c  (cost=0.00..8.61 rows=461 width=7) (actual time=0.011..0.047 rows=462.00 loops=1)
                          Buffers: shared hit=4
Planning:
  Buffers: shared hit=26
Planning Time: 1.024 ms
Execution Time: 434.004 ms
```

</details>

<details><summary><code>01_serie_semanal_por_uf</code> — <code>btree_posto_data</code></summary>

```
GroupAggregate  (cost=45609.49..49956.46 rows=7074 width=35) (actual time=367.672..455.925 rows=1425.00 loops=1)
  Group Key: d.survey_week_key, c.uf, d.week_start_date
  Buffers: shared hit=6374, temp read=1095 written=1098
  ->  Sort  (cost=45609.49..46141.81 rows=212927 width=25) (actual time=367.621..385.455 rows=212528.00 loops=1)
        Sort Key: d.survey_week_key, c.uf, d.week_start_date, f.station_key
        Sort Method: external merge  Disk: 8760kB
        Buffers: shared hit=6374, temp read=1095 written=1098
        ->  Hash Join  (cost=889.16..21669.45 rows=212927 width=25) (actual time=4.453..186.342 rows=212528.00 loops=1)
              Hash Cond: (s.city_key = c.city_key)
              Buffers: shared hit=6374
              ->  Hash Join  (cost=874.78..21091.02 rows=212927 width=26) (actual time=4.349..157.619 rows=212528.00 loops=1)
                    Hash Cond: (f.station_key = s.station_key)
                    Buffers: shared hit=6370
                    ->  Hash Join  (cost=60.09..19717.25 rows=212927 width=22) (actual time=0.371..101.044 rows=212528.00 loops=1)
                          Hash Cond: (f.collection_date = d.full_date)
                          Buffers: shared hit=5952
                          ->  Append  (cost=0.00..19096.93 rows=212927 width=18) (actual time=0.007..73.159 rows=212528.00 loops=1)
                                Buffers: shared hit=5933
                                ->  Seq Scan on fct_price_observation_2025q3 f_1  (cost=0.00..4102.59 rows=48727 width=18) (actual time=0.006..14.376 rows=48601.00 loops=1)
                                      Filter: ((collection_date >= '2025-07-01'::date) AND (product_key = 1))
                                      Rows Removed by Filter: 134905
                                      Buffers: shared hit=1350
                                ->  Seq Scan on fct_price_observation_2025q4 f_2  (cost=0.00..4486.53 rows=53213 width=18) (actual time=0.024..14.811 rows=53004.00 loops=1)
                                      Filter: ((collection_date >= '2025-07-01'::date) AND (product_key = 1))
                                      Rows Removed by Filter: 147698
                                      Buffers: shared hit=1476
                                ->  Seq Scan on fct_price_observation_2026q1 f_3  (cost=0.00..4646.54 rows=54980 width=18) (actual time=0.028..14.749 rows=54662.00 loops=1)
                                      Filter: ((collection_date >= '2025-07-01'::date) AND (product_key = 1))
                                      Rows Removed by Filter: 153174
                                      Buffers: shared hit=1529
                                ->  Seq Scan on fct_price_observation_2026q2 f_4  (cost=0.00..4796.64 rows=56004 width=18) (actual time=0.026..14.499 rows=56261.00 loops=1)
                                      Filter: ((collection_date >= '2025-07-01'::date) AND (product_key = 1))
                                      Rows Removed by Filter: 158315
                                      Buffers: shared hit=1578
                                ->  Seq Scan on fct_price_observation_2026q3 f_5  (cost=0.00..0.00 rows=1 width=26) (actual time=0.020..0.020 rows=0.00 loops=1)
                                      Filter: ((collection_date >= '2025-07-01'::date) AND (product_key = 1))
                                ->  Seq Scan on fct_price_observation_2026q4 f_6  (cost=0.00..0.00 rows=1 width=26) (actual time=0.005..0.005 rows=0.00 loops=1)
                                      Filter: ((collection_date >= '2025-07-01'::date) AND (product_key = 1))
                                ->  Seq Scan on fct_price_observation_default f_7  (cost=0.00..0.00 rows=1 width=26) (actual time=0.004..0.004 rows=0.00 loops=1)
                                      Filter: ((collection_date >= '2025-07-01'::date) AND (product_key = 1))
                          ->  Hash  (cost=37.26..37.26 rows=1826 width=12) (actual time=0.360..0.361 rows=1826.00 loops=1)
                                Buckets: 2048  Batches: 1  Memory Usage: 95kB
                                Buffers: shared hit=19
                                ->  Seq Scan on dim_date d  (cost=0.00..37.26 rows=1826 width=12) (actual time=0.005..0.183 rows=1826.00 loops=1)
                                      Buffers: shared hit=19
                    ->  Hash  (cost=594.31..594.31 rows=17631 width=12) (actual time=3.942..3.944 rows=17631.00 loops=1)
                          Buckets: 32768  Batches: 1  Memory Usage: 1014kB
                          Buffers: shared hit=418
                          ->  Seq Scan on dim_station s  (cost=0.00..594.31 rows=17631 width=12) (actual time=0.007..2.236 rows=17631.00 loops=1)
                                Buffers: shared hit=418
              ->  Hash  (cost=8.61..8.61 rows=461 width=7) (actual time=0.099..0.099 rows=462.00 loops=1)
                    Buckets: 1024  Batches: 1  Memory Usage: 27kB
                    Buffers: shared hit=4
                    ->  Seq Scan on dim_city c  (cost=0.00..8.61 rows=461 width=7) (actual time=0.013..0.051 rows=462.00 loops=1)
                          Buffers: shared hit=4
Planning:
  Buffers: shared hit=31
Planning Time: 2.291 ms
Execution Time: 456.859 ms
```

</details>

<details><summary><code>02_dispersao_intramunicipal</code> — <code>sem_indice</code></summary>

```
Limit  (cost=55188.22..55188.34 rows=50 width=121) (actual time=632.975..632.994 rows=50.00 loops=1)
  Buffers: shared hit=6359, temp read=1221 written=1225
  ->  Sort  (cost=55188.22..55288.65 rows=40173 width=121) (actual time=632.973..632.987 rows=50.00 loops=1)
        Sort Key: (round(((percentile_cont('0.9'::double precision) WITHIN GROUP (ORDER BY ((f.sale_price)::double precision)) - percentile_cont('0.1'::double precision) WITHIN GROUP (ORDER BY ((f.sale_price)::double precision))))::numeric, 3)) DESC
        Sort Method: top-N heapsort  Memory: 29kB
        Buffers: shared hit=6359, temp read=1221 written=1225
        ->  GroupAggregate  (cost=47345.69..53853.70 rows=40173 width=121) (actual time=484.056..630.716 rows=8414.00 loops=1)
              Group Key: c.uf, c.city_name, d.survey_week_key
              Filter: (count(DISTINCT f.station_key) >= 10)
              Rows Removed by Filter: 9597
              Buffers: shared hit=6359, temp read=1221 written=1225
              ->  Sort  (cost=47345.69..47873.68 rows=211193 width=31) (actual time=483.817..532.620 rows=212423.00 loops=1)
                    Sort Key: c.uf, c.city_name, d.survey_week_key, f.station_key
                    Sort Method: external merge  Disk: 9768kB
                    Buffers: shared hit=6359, temp read=1221 written=1225
                    ->  Hash Join  (cost=889.16..23613.57 rows=211193 width=31) (actual time=4.857..193.548 rows=212423.00 loops=1)
                          Hash Cond: (s.city_key = c.city_key)
                          Buffers: shared hit=6359
                          ->  Hash Join  (cost=874.78..23039.73 rows=211193 width=22) (actual time=4.733..163.243 rows=212423.00 loops=1)
                                Hash Cond: (f.station_key = s.station_key)
                                Buffers: shared hit=6355
                                ->  Hash Join  (cost=60.09..21670.52 rows=211193 width=18) (actual time=0.368..101.677 rows=212423.00 loops=1)
                                      Hash Cond: (f.collection_date = d.full_date)
                                      Buffers: shared hit=5937
                                      ->  Append  (cost=0.00..21054.76 rows=211193 width=18) (actual time=0.007..73.927 rows=212423.00 loops=1)
                                            Buffers: shared hit=5918
                                            ->  Seq Scan on fct_price_observation_2025q1 f_1  (cost=0.00..5159.77 rows=54026 width=18) (actual time=0.006..17.268 rows=54652.00 loops=1)
                                                  Filter: ((collection_date >= '2025-01-01'::date) AND (collection_date < '2026-01-01'::date) AND (product_key = 1))
                                                  Rows Removed by Filter: 152935
                                                  Buffers: shared hit=1527
                                            ->  Seq Scan on fct_price_observation_2025q2 f_2  (cost=0.00..5289.39 rows=55802 width=18) (actual time=0.019..15.149 rows=56166.00 loops=1)
                                                  Filter: ((collection_date >= '2025-01-01'::date) AND (collection_date < '2026-01-01'::date) AND (product_key = 1))
                                                  Rows Removed by Filter: 156656
                                                  Buffers: shared hit=1565
                                            ->  Seq Scan on fct_price_observation_2025q3 f_3  (cost=0.00..4561.36 rows=48152 width=18) (actual time=0.021..13.701 rows=48601.00 loops=1)
                                                  Filter: ((collection_date >= '2025-01-01'::date) AND (collection_date < '2026-01-01'::date) AND (product_key = 1))
                                                  Rows Removed by Filter: 134905
                                                  Buffers: shared hit=1350
                                            ->  Seq Scan on fct_price_observation_2025q4 f_4  (cost=0.00..4988.28 rows=53213 width=18) (actual time=0.018..15.179 rows=53004.00 loops=1)
                                                  Filter: ((collection_date >= '2025-01-01'::date) AND (collection_date < '2026-01-01'::date) AND (product_key = 1))
                                                  Rows Removed by Filter: 147698
                                                  Buffers: shared hit=1476
                                      ->  Hash  (cost=37.26..37.26 rows=1826 width=8) (actual time=0.356..0.357 rows=1826.00 loops=1)
                                            Buckets: 2048  Batches: 1  Memory Usage: 88kB
                                            Buffers: shared hit=19
                                            ->  Seq Scan on dim_date d  (cost=0.00..37.26 rows=1826 width=8) (actual time=0.006..0.178 rows=1826.00 loops=1)
                                                  Buffers: shared hit=19
                                ->  Hash  (cost=594.31..594.31 rows=17631 width=12) (actual time=4.330..4.331 rows=17631.00 loops=1)
                                      Buckets: 32768  Batches: 1  Memory Usage: 1014kB
                                      Buffers: shared hit=418
                                      ->  Seq Scan on dim_station s  (cost=0.00..594.31 rows=17631 width=12) (actual time=0.006..2.411 rows=17631.00 loops=1)
                                            Buffers: shared hit=418
                          ->  Hash  (cost=8.61..8.61 rows=461 width=17) (actual time=0.117..0.118 rows=462.00 loops=1)
                                Buckets: 1024  Batches: 1  Memory Usage: 32kB
                                Buffers: shared hit=4
                                ->  Seq Scan on dim_city c  (cost=0.00..8.61 rows=461 width=17) (actual time=0.013..0.054 rows=462.00 loops=1)
                                      Buffers: shared hit=4
Planning:
  Buffers: shared hit=30
Planning Time: 1.215 ms
Execution Time: 633.921 ms
```

</details>

<details><summary><code>02_dispersao_intramunicipal</code> — <code>brin_date</code></summary>

```
Limit  (cost=55396.45..55396.57 rows=50 width=121) (actual time=647.070..647.086 rows=50.00 loops=1)
  Buffers: shared hit=6359, temp read=1221 written=1225
  ->  Sort  (cost=55396.45..55496.88 rows=40173 width=121) (actual time=647.068..647.079 rows=50.00 loops=1)
        Sort Key: (round(((percentile_cont('0.9'::double precision) WITHIN GROUP (ORDER BY ((f.sale_price)::double precision)) - percentile_cont('0.1'::double precision) WITHIN GROUP (ORDER BY ((f.sale_price)::double precision))))::numeric, 3)) DESC
        Sort Method: top-N heapsort  Memory: 29kB
        Buffers: shared hit=6359, temp read=1221 written=1225
        ->  GroupAggregate  (cost=47529.88..54061.93 rows=40173 width=121) (actual time=486.248..644.723 rows=8414.00 loops=1)
              Group Key: c.uf, c.city_name, d.survey_week_key
              Filter: (count(DISTINCT f.station_key) >= 10)
              Rows Removed by Filter: 9597
              Buffers: shared hit=6359, temp read=1221 written=1225
              ->  Sort  (cost=47529.88..48061.30 rows=212567 width=31) (actual time=486.006..538.903 rows=212423.00 loops=1)
                    Sort Key: c.uf, c.city_name, d.survey_week_key, f.station_key
                    Sort Method: external merge  Disk: 9768kB
                    Buffers: shared hit=6359, temp read=1221 written=1225
                    ->  Hash Join  (cost=889.16..23631.29 rows=212567 width=31) (actual time=5.024..192.431 rows=212423.00 loops=1)
                          Hash Cond: (s.city_key = c.city_key)
                          Buffers: shared hit=6359
                          ->  Hash Join  (cost=874.78..23053.82 rows=212567 width=22) (actual time=4.900..161.366 rows=212423.00 loops=1)
                                Hash Cond: (f.station_key = s.station_key)
                                Buffers: shared hit=6355
                                ->  Hash Join  (cost=60.09..21681.00 rows=212567 width=18) (actual time=0.385..103.028 rows=212423.00 loops=1)
                                      Hash Cond: (f.collection_date = d.full_date)
                                      Buffers: shared hit=5937
                                      ->  Append  (cost=0.00..21061.63 rows=212567 width=18) (actual time=0.007..74.572 rows=212423.00 loops=1)
                                            Buffers: shared hit=5918
                                            ->  Seq Scan on fct_price_observation_2025q1 f_1  (cost=0.00..5159.77 rows=55239 width=18) (actual time=0.007..17.130 rows=54652.00 loops=1)
                                                  Filter: ((collection_date >= '2025-01-01'::date) AND (collection_date < '2026-01-01'::date) AND (product_key = 1))
                                                  Rows Removed by Filter: 152935
                                                  Buffers: shared hit=1527
                                            ->  Seq Scan on fct_price_observation_2025q2 f_2  (cost=0.00..5289.39 rows=56554 width=18) (actual time=0.023..15.557 rows=56166.00 loops=1)
                                                  Filter: ((collection_date >= '2025-01-01'::date) AND (collection_date < '2026-01-01'::date) AND (product_key = 1))
                                                  Rows Removed by Filter: 156656
                                                  Buffers: shared hit=1565
                                            ->  Seq Scan on fct_price_observation_2025q3 f_3  (cost=0.00..4561.36 rows=48384 width=18) (actual time=0.026..13.919 rows=48601.00 loops=1)
                                                  Filter: ((collection_date >= '2025-01-01'::date) AND (collection_date < '2026-01-01'::date) AND (product_key = 1))
                                                  Rows Removed by Filter: 134905
                                                  Buffers: shared hit=1350
                                            ->  Seq Scan on fct_price_observation_2025q4 f_4  (cost=0.00..4988.28 rows=52390 width=18) (actual time=0.020..14.674 rows=53004.00 loops=1)
                                                  Filter: ((collection_date >= '2025-01-01'::date) AND (collection_date < '2026-01-01'::date) AND (product_key = 1))
                                                  Rows Removed by Filter: 147698
                                                  Buffers: shared hit=1476
                                      ->  Hash  (cost=37.26..37.26 rows=1826 width=8) (actual time=0.374..0.375 rows=1826.00 loops=1)
                                            Buckets: 2048  Batches: 1  Memory Usage: 88kB
                                            Buffers: shared hit=19
                                            ->  Seq Scan on dim_date d  (cost=0.00..37.26 rows=1826 width=8) (actual time=0.005..0.179 rows=1826.00 loops=1)
                                                  Buffers: shared hit=19
                                ->  Hash  (cost=594.31..594.31 rows=17631 width=12) (actual time=4.478..4.478 rows=17631.00 loops=1)
                                      Buckets: 32768  Batches: 1  Memory Usage: 1014kB
                                      Buffers: shared hit=418
                                      ->  Seq Scan on dim_station s  (cost=0.00..594.31 rows=17631 width=12) (actual time=0.006..2.466 rows=17631.00 loops=1)
                                            Buffers: shared hit=418
                          ->  Hash  (cost=8.61..8.61 rows=461 width=17) (actual time=0.118..0.118 rows=462.00 loops=1)
                                Buckets: 1024  Batches: 1  Memory Usage: 32kB
                                Buffers: shared hit=4
                                ->  Seq Scan on dim_city c  (cost=0.00..8.61 rows=461 width=17) (actual time=0.013..0.055 rows=462.00 loops=1)
                                      Buffers: shared hit=4
Planning:
  Buffers: shared hit=48
Planning Time: 1.457 ms
Execution Time: 648.055 ms
```

</details>

<details><summary><code>02_dispersao_intramunicipal</code> — <code>btree_produto_data</code></summary>

```
Limit  (cost=51274.36..51274.48 rows=50 width=121) (actual time=615.441..615.457 rows=50.00 loops=1)
  Buffers: shared hit=7184, temp read=1221 written=1225
  ->  Sort  (cost=51274.36..51374.79 rows=40173 width=121) (actual time=615.439..615.451 rows=50.00 loops=1)
        Sort Key: (round(((percentile_cont('0.9'::double precision) WITHIN GROUP (ORDER BY ((f.sale_price)::double precision)) - percentile_cont('0.1'::double precision) WITHIN GROUP (ORDER BY ((f.sale_price)::double precision))))::numeric, 3)) DESC
        Sort Method: top-N heapsort  Memory: 29kB
        Buffers: shared hit=7184, temp read=1221 written=1225
        ->  GroupAggregate  (cost=43386.88..49939.84 rows=40173 width=121) (actual time=458.934..613.113 rows=8414.00 loops=1)
              Group Key: c.uf, c.city_name, d.survey_week_key
              Filter: (count(DISTINCT f.station_key) >= 10)
              Rows Removed by Filter: 9597
              Buffers: shared hit=7184, temp read=1221 written=1225
              ->  Sort  (cost=43386.88..43921.28 rows=213762 width=31) (actual time=458.707..511.289 rows=212423.00 loops=1)
                    Sort Key: c.uf, c.city_name, d.survey_week_key, f.station_key
                    Sort Method: external merge  Disk: 9768kB
                    Buffers: shared hit=7184, temp read=1221 written=1225
                    ->  Hash Join  (cost=2441.28..19345.91 rows=213762 width=31) (actual time=5.886..167.833 rows=212423.00 loops=1)
                          Hash Cond: (s.city_key = c.city_key)
                          Buffers: shared hit=7184
                          ->  Hash Join  (cost=2426.91..18765.26 rows=213762 width=22) (actual time=5.768..136.922 rows=212423.00 loops=1)
                                Hash Cond: (f.station_key = s.station_key)
                                Buffers: shared hit=7180
                                ->  Hash Join  (cost=1612.21..17389.30 rows=213762 width=18) (actual time=1.996..82.873 rows=212423.00 loops=1)
                                      Hash Cond: (f.collection_date = d.full_date)
                                      Buffers: shared hit=6762
                                      ->  Append  (cost=1552.13..16766.79 rows=213762 width=18) (actual time=1.633..56.237 rows=212423.00 loops=1)
                                            Buffers: shared hit=6743
                                            ->  Bitmap Heap Scan on fct_price_observation_2025q1 f_1  (cost=1552.13..4039.51 rows=54879 width=18) (actual time=1.632..9.515 rows=54652.00 loops=1)
                                                  Recheck Cond: ((product_key = 1) AND (collection_date >= '2025-01-01'::date) AND (collection_date < '2026-01-01'::date))
                                                  Heap Blocks: exact=1527
                                                  Buffers: shared hit=1739
                                                  ->  Bitmap Index Scan on fct_price_observation_2025q1_product_key_collection_date_sa_idx  (cost=0.00..1538.41 rows=54879 width=0) (actual time=1.472..1.472 rows=54652.00 loops=1)
                                                        Index Cond: ((product_key = 1) AND (collection_date >= '2025-01-01'::date) AND (collection_date < '2026-01-01'::date))
                                                        Index Searches: 1
                                                        Buffers: shared hit=212
                                            ->  Bitmap Heap Scan on fct_price_observation_2025q2 f_2  (cost=1605.64..4166.04 rows=56880 width=18) (actual time=1.657..10.917 rows=56166.00 loops=1)
                                                  Recheck Cond: ((product_key = 1) AND (collection_date >= '2025-01-01'::date) AND (collection_date < '2026-01-01'::date))
                                                  Heap Blocks: exact=1565
                                                  Buffers: shared hit=1783
                                                  ->  Bitmap Index Scan on fct_price_observation_2025q2_product_key_collection_date_sa_idx  (cost=0.00..1591.42 rows=56880 width=0) (actual time=1.496..1.496 rows=56166.00 loops=1)
                                                        Index Cond: ((product_key = 1) AND (collection_date >= '2025-01-01'::date) AND (collection_date < '2026-01-01'::date))
                                                        Index Searches: 1
                                                        Buffers: shared hit=218
                                            ->  Bitmap Heap Scan on fct_price_observation_2025q3 f_3  (cost=1391.62..3602.48 rows=49192 width=18) (actual time=1.466..8.417 rows=48601.00 loops=1)
                                                  Recheck Cond: ((product_key = 1) AND (collection_date >= '2025-01-01'::date) AND (collection_date < '2026-01-01'::date))
                                                  Heap Blocks: exact=1350
                                                  Buffers: shared hit=1539
                                                  ->  Bitmap Index Scan on fct_price_observation_2025q3_product_key_collection_date_sa_idx  (cost=0.00..1379.32 rows=49192 width=0) (actual time=1.320..1.320 rows=48601.00 loops=1)
                                                        Index Cond: ((product_key = 1) AND (collection_date >= '2025-01-01'::date) AND (collection_date < '2026-01-01'::date))
                                                        Index Searches: 1
                                                        Buffers: shared hit=189
                                            ->  Bitmap Heap Scan on fct_price_observation_2025q4 f_4  (cost=1489.76..3889.95 rows=52811 width=18) (actual time=1.679..14.373 rows=53004.00 loops=1)
                                                  Recheck Cond: ((product_key = 1) AND (collection_date >= '2025-01-01'::date) AND (collection_date < '2026-01-01'::date))
                                                  Heap Blocks: exact=1476
                                                  Buffers: shared hit=1682
                                                  ->  Bitmap Index Scan on fct_price_observation_2025q4_product_key_collection_date_sa_idx  (cost=0.00..1476.56 rows=52811 width=0) (actual time=1.517..1.517 rows=53004.00 loops=1)
                                                        Index Cond: ((product_key = 1) AND (collection_date >= '2025-01-01'::date) AND (collection_date < '2026-01-01'::date))
                                                        Index Searches: 1
                                                        Buffers: shared hit=206
                                      ->  Hash  (cost=37.26..37.26 rows=1826 width=8) (actual time=0.356..0.357 rows=1826.00 loops=1)
                                            Buckets: 2048  Batches: 1  Memory Usage: 88kB
                                            Buffers: shared hit=19
                                            ->  Seq Scan on dim_date d  (cost=0.00..37.26 rows=1826 width=8) (actual time=0.008..0.176 rows=1826.00 loops=1)
                                                  Buffers: shared hit=19
                                ->  Hash  (cost=594.31..594.31 rows=17631 width=12) (actual time=3.747..3.747 rows=17631.00 loops=1)
                                      Buckets: 32768  Batches: 1  Memory Usage: 1014kB
                                      Buffers: shared hit=418
                                      ->  Seq Scan on dim_station s  (cost=0.00..594.31 rows=17631 width=12) (actual time=0.004..2.025 rows=17631.00 loops=1)
                                            Buffers: shared hit=418
                          ->  Hash  (cost=8.61..8.61 rows=461 width=17) (actual time=0.113..0.113 rows=462.00 loops=1)
                                Buckets: 1024  Batches: 1  Memory Usage: 32kB
                                Buffers: shared hit=4
                                ->  Seq Scan on dim_city c  (cost=0.00..8.61 rows=461 width=17) (actual time=0.011..0.049 rows=462.00 loops=1)
                                      Buffers: shared hit=4
Planning:
  Buffers: shared hit=30
Planning Time: 1.277 ms
Execution Time: 616.415 ms
```

</details>

<details><summary><code>02_dispersao_intramunicipal</code> — <code>btree_posto_data</code></summary>

```
Limit  (cost=55383.24..55383.36 rows=50 width=121) (actual time=647.176..647.194 rows=50.00 loops=1)
  Buffers: shared hit=6359, temp read=1221 written=1225
  ->  Sort  (cost=55383.24..55483.67 rows=40173 width=121) (actual time=647.174..647.187 rows=50.00 loops=1)
        Sort Key: (round(((percentile_cont('0.9'::double precision) WITHIN GROUP (ORDER BY ((f.sale_price)::double precision)) - percentile_cont('0.1'::double precision) WITHIN GROUP (ORDER BY ((f.sale_price)::double precision))))::numeric, 3)) DESC
        Sort Method: top-N heapsort  Memory: 29kB
        Buffers: shared hit=6359, temp read=1221 written=1225
        ->  GroupAggregate  (cost=47518.02..54048.72 rows=40173 width=121) (actual time=497.292..644.919 rows=8414.00 loops=1)
              Group Key: c.uf, c.city_name, d.survey_week_key
              Filter: (count(DISTINCT f.station_key) >= 10)
              Rows Removed by Filter: 9597
              Buffers: shared hit=6359, temp read=1221 written=1225
              ->  Sort  (cost=47518.02..48049.24 rows=212490 width=31) (actual time=497.050..544.619 rows=212423.00 loops=1)
                    Sort Key: c.uf, c.city_name, d.survey_week_key, f.station_key
                    Sort Method: external merge  Disk: 9768kB
                    Buffers: shared hit=6359, temp read=1221 written=1225
                    ->  Hash Join  (cost=889.16..23630.30 rows=212490 width=31) (actual time=4.554..199.472 rows=212423.00 loops=1)
                          Hash Cond: (s.city_key = c.city_key)
                          Buffers: shared hit=6359
                          ->  Hash Join  (cost=874.78..23053.03 rows=212490 width=22) (actual time=4.427..166.950 rows=212423.00 loops=1)
                                Hash Cond: (f.station_key = s.station_key)
                                Buffers: shared hit=6355
                                ->  Hash Join  (cost=60.09..21680.41 rows=212490 width=18) (actual time=0.367..107.916 rows=212423.00 loops=1)
                                      Hash Cond: (f.collection_date = d.full_date)
                                      Buffers: shared hit=5937
                                      ->  Append  (cost=0.00..21061.25 rows=212490 width=18) (actual time=0.008..79.219 rows=212423.00 loops=1)
                                            Buffers: shared hit=5918
                                            ->  Seq Scan on fct_price_observation_2025q1 f_1  (cost=0.00..5159.77 rows=54649 width=18) (actual time=0.007..16.465 rows=54652.00 loops=1)
                                                  Filter: ((collection_date >= '2025-01-01'::date) AND (collection_date < '2026-01-01'::date) AND (product_key = 1))
                                                  Rows Removed by Filter: 152935
                                                  Buffers: shared hit=1527
                                            ->  Seq Scan on fct_price_observation_2025q2 f_2  (cost=0.00..5289.39 rows=55901 width=18) (actual time=0.014..15.862 rows=56166.00 loops=1)
                                                  Filter: ((collection_date >= '2025-01-01'::date) AND (collection_date < '2026-01-01'::date) AND (product_key = 1))
                                                  Rows Removed by Filter: 156656
                                                  Buffers: shared hit=1565
                                            ->  Seq Scan on fct_price_observation_2025q3 f_3  (cost=0.00..4561.36 rows=48727 width=18) (actual time=0.015..17.715 rows=48601.00 loops=1)
                                                  Filter: ((collection_date >= '2025-01-01'::date) AND (collection_date < '2026-01-01'::date) AND (product_key = 1))
                                                  Rows Removed by Filter: 134905
                                                  Buffers: shared hit=1350
                                            ->  Seq Scan on fct_price_observation_2025q4 f_4  (cost=0.00..4988.28 rows=53213 width=18) (actual time=0.018..14.762 rows=53004.00 loops=1)
                                                  Filter: ((collection_date >= '2025-01-01'::date) AND (collection_date < '2026-01-01'::date) AND (product_key = 1))
                                                  Rows Removed by Filter: 147698
                                                  Buffers: shared hit=1476
                                      ->  Hash  (cost=37.26..37.26 rows=1826 width=8) (actual time=0.354..0.356 rows=1826.00 loops=1)
                                            Buckets: 2048  Batches: 1  Memory Usage: 88kB
                                            Buffers: shared hit=19
                                            ->  Seq Scan on dim_date d  (cost=0.00..37.26 rows=1826 width=8) (actual time=0.005..0.174 rows=1826.00 loops=1)
                                                  Buffers: shared hit=19
                                ->  Hash  (cost=594.31..594.31 rows=17631 width=12) (actual time=4.025..4.026 rows=17631.00 loops=1)
                                      Buckets: 32768  Batches: 1  Memory Usage: 1014kB
                                      Buffers: shared hit=418
                                      ->  Seq Scan on dim_station s  (cost=0.00..594.31 rows=17631 width=12) (actual time=0.006..2.301 rows=17631.00 loops=1)
                                            Buffers: shared hit=418
                          ->  Hash  (cost=8.61..8.61 rows=461 width=17) (actual time=0.120..0.121 rows=462.00 loops=1)
                                Buckets: 1024  Batches: 1  Memory Usage: 32kB
                                Buffers: shared hit=4
                                ->  Seq Scan on dim_city c  (cost=0.00..8.61 rows=461 width=17) (actual time=0.013..0.057 rows=462.00 loops=1)
                                      Buffers: shared hit=4
Planning:
  Buffers: shared hit=30
Planning Time: 1.961 ms
Execution Time: 648.141 ms
```

</details>

<details><summary><code>03_paridade_etanol_gasolina</code> — <code>sem_indice</code></summary>

```
GroupAggregate  (cost=163949.79..168848.89 rows=460 width=114) (actual time=923.327..938.154 rows=11698.00 loops=1)
  Group Key: d.month_start_date, c.uf, c.city_name
  Filter: (count(*) = 2)
  Rows Removed by Filter: 102
  Buffers: shared hit=16074, temp read=476 written=1236
  ->  Sort  (cost=163949.79..164365.59 rows=166320 width=51) (actual time=923.298..924.763 rows=23498.00 loops=1)
        Sort Key: d.month_start_date, c.uf, c.city_name
        Sort Method: quicksort  Memory: 1957kB
        Buffers: shared hit=16074, temp read=476 written=1236
        ->  Hash Join  (cost=129653.45..143839.35 rows=166320 width=51) (actual time=870.822..908.823 rows=23498.00 loops=1)
              Hash Cond: (s.city_key = c.city_key)
              Buffers: shared hit=16074, temp read=476 written=1236
              ->  HashAggregate  (cost=129639.08..141721.17 rows=166320 width=50) (actual time=870.696..904.869 rows=23498.00 loops=1)
                    Group Key: s.city_key, d.month_start_date, f.product_key
                    Planned Partitions: 8  Batches: 9  Memory Usage: 8273kB  Disk Usage: 6672kB
                    Buffers: shared hit=16070, temp read=476 written=1236
                    ->  Hash Join  (cost=874.78..58897.18 rows=1024317 width=16) (actual time=4.524..632.065 rows=1025310.00 loops=1)
                          Hash Cond: (f.station_key = s.station_key)
                          Buffers: shared hit=16070
                          ->  Hash Join  (cost=60.09..55393.01 rows=1024317 width=20) (actual time=0.379..427.970 rows=1025310.00 loops=1)
                                Hash Cond: (f.collection_date = d.full_date)
                                Buffers: shared hit=15652
                                ->  Append  (cost=0.00..52637.85 rows=1024317 width=20) (actual time=0.007..289.874 rows=1025310.00 loops=1)
                                      Buffers: shared hit=15633
                                      ->  Seq Scan on fct_price_observation_2024q1 f_1  (cost=0.00..5331.62 rows=113490 width=20) (actual time=0.007..26.191 rows=112966.00 loops=1)
                                            Filter: ((product_key = ANY ('{1,3}'::integer[])) AND (collection_date >= '2024-01-01'::date))
                                            Rows Removed by Filter: 125542
                                            Buffers: shared hit=1754
                                      ->  Seq Scan on fct_price_observation_2024q2 f_2  (cost=0.00..5334.48 rows=114297 width=20) (actual time=0.028..26.497 rows=113350.00 loops=1)
                                            Filter: ((product_key = ANY ('{1,3}'::integer[])) AND (collection_date >= '2024-01-01'::date))
                                            Rows Removed by Filter: 125282
                                            Buffers: shared hit=1755
                                      ->  Seq Scan on fct_price_observation_2024q3 f_3  (cost=0.00..4866.00 rows=104799 width=20) (actual time=0.028..21.925 rows=105303.00 loops=1)
                                            Filter: ((product_key = ANY ('{1,3}'::integer[])) AND (collection_date >= '2024-01-01'::date))
                                            Rows Removed by Filter: 112364
                                            Buffers: shared hit=1601
                                      ->  Seq Scan on fct_price_observation_2024q4 f_4  (cost=0.00..4553.73 rows=98788 width=20) (actual time=0.024..20.742 rows=98701.00 loops=1)
                                            Filter: ((product_key = ANY ('{1,3}'::integer[])) AND (collection_date >= '2024-01-01'::date))
                                            Rows Removed by Filter: 105014
                                            Buffers: shared hit=1498
                                      ->  Seq Scan on fct_price_observation_2025q1 f_5  (cost=0.00..4640.81 rows=99004 width=20) (actual time=0.028..20.902 rows=100273.00 loops=1)
                                            Filter: ((product_key = ANY ('{1,3}'::integer[])) AND (collection_date >= '2024-01-01'::date))
                                            Rows Removed by Filter: 107314
                                            Buffers: shared hit=1527
                                      ->  Seq Scan on fct_price_observation_2025q2 f_6  (cost=0.00..4757.33 rows=102758 width=20) (actual time=0.024..20.880 rows=103143.00 loops=1)
                                            Filter: ((product_key = ANY ('{1,3}'::integer[])) AND (collection_date >= '2024-01-01'::date))
                                            Rows Removed by Filter: 109679
                                            Buffers: shared hit=1565
                                      ->  Seq Scan on fct_price_observation_2025q3 f_7  (cost=0.00..4102.59 rows=88774 width=20) (actual time=0.025..19.310 rows=89348.00 loops=1)
                                            Filter: ((product_key = ANY ('{1,3}'::integer[])) AND (collection_date >= '2024-01-01'::date))
                                            Rows Removed by Filter: 94158
                                            Buffers: shared hit=1350
                                      ->  Seq Scan on fct_price_observation_2025q4 f_8  (cost=0.00..4486.53 rows=97280 width=20) (actual time=0.025..20.667 rows=97412.00 loops=1)
                                            Filter: ((product_key = ANY ('{1,3}'::integer[])) AND (collection_date >= '2024-01-01'::date))
                                            Rows Removed by Filter: 103290
                                            Buffers: shared hit=1476
                                      ->  Seq Scan on fct_price_observation_2026q1 f_9  (cost=0.00..4646.54 rows=100683 width=20) (actual time=0.026..21.959 rows=100809.00 loops=1)
                                            Filter: ((product_key = ANY ('{1,3}'::integer[])) AND (collection_date >= '2024-01-01'::date))
                                            Rows Removed by Filter: 107027
                                            Buffers: shared hit=1529
                                      ->  Seq Scan on fct_price_observation_2026q2 f_10  (cost=0.00..4796.64 rows=104441 width=20) (actual time=0.027..22.247 rows=104005.00 loops=1)
                                            Filter: ((product_key = ANY ('{1,3}'::integer[])) AND (collection_date >= '2024-01-01'::date))
                                            Rows Removed by Filter: 110571
                                            Buffers: shared hit=1578
                                      ->  Seq Scan on fct_price_observation_2026q3 f_11  (cost=0.00..0.00 rows=1 width=28) (actual time=0.016..0.016 rows=0.00 loops=1)
                                            Filter: ((product_key = ANY ('{1,3}'::integer[])) AND (collection_date >= '2024-01-01'::date))
                                      ->  Seq Scan on fct_price_observation_2026q4 f_12  (cost=0.00..0.00 rows=1 width=28) (actual time=0.004..0.005 rows=0.00 loops=1)
                                            Filter: ((product_key = ANY ('{1,3}'::integer[])) AND (collection_date >= '2024-01-01'::date))
                                      ->  Seq Scan on fct_price_observation_default f_13  (cost=0.00..0.00 rows=1 width=28) (actual time=0.003..0.004 rows=0.00 loops=1)
                                            Filter: ((product_key = ANY ('{1,3}'::integer[])) AND (collection_date >= '2024-01-01'::date))
                                ->  Hash  (cost=37.26..37.26 rows=1826 width=8) (actual time=0.368..0.369 rows=1826.00 loops=1)
                                      Buckets: 2048  Batches: 1  Memory Usage: 88kB
                                      Buffers: shared hit=19
                                      ->  Seq Scan on dim_date d  (cost=0.00..37.26 rows=1826 width=8) (actual time=0.004..0.187 rows=1826.00 loops=1)
                                            Buffers: shared hit=19
                          ->  Hash  (cost=594.31..594.31 rows=17631 width=12) (actual time=4.110..4.111 rows=17631.00 loops=1)
                                Buckets: 32768  Batches: 1  Memory Usage: 1083kB
                                Buffers: shared hit=418
                                ->  Seq Scan on dim_station s  (cost=0.00..594.31 rows=17631 width=12) (actual time=0.006..2.249 rows=17631.00 loops=1)
                                      Buffers: shared hit=418
              ->  Hash  (cost=8.61..8.61 rows=461 width=17) (actual time=0.119..0.119 rows=462.00 loops=1)
                    Buckets: 1024  Batches: 1  Memory Usage: 32kB
                    Buffers: shared hit=4
                    ->  Seq Scan on dim_city c  (cost=0.00..8.61 rows=461 width=17) (actual time=0.014..0.057 rows=462.00 loops=1)
                          Buffers: shared hit=4
Planning:
  Buffers: shared hit=35
Planning Time: 2.650 ms
Execution Time: 939.342 ms
```

</details>

<details><summary><code>03_paridade_etanol_gasolina</code> — <code>brin_date</code></summary>

```
GroupAggregate  (cost=164252.94..169152.04 rows=460 width=114) (actual time=989.765..1004.580 rows=11698.00 loops=1)
  Group Key: d.month_start_date, c.uf, c.city_name
  Filter: (count(*) = 2)
  Rows Removed by Filter: 102
  Buffers: shared hit=16074, temp read=476 written=1236
  ->  Sort  (cost=164252.94..164668.74 rows=166320 width=51) (actual time=989.739..991.251 rows=23498.00 loops=1)
        Sort Key: d.month_start_date, c.uf, c.city_name
        Sort Method: quicksort  Memory: 1957kB
        Buffers: shared hit=16074, temp read=476 written=1236
        ->  Hash Join  (cost=129923.37..144142.51 rows=166320 width=51) (actual time=937.870..974.898 rows=23498.00 loops=1)
              Hash Cond: (s.city_key = c.city_key)
              Buffers: shared hit=16074, temp read=476 written=1236
              ->  HashAggregate  (cost=129909.00..142024.33 rows=166320 width=50) (actual time=937.743..971.202 rows=23498.00 loops=1)
                    Group Key: s.city_key, d.month_start_date, f.product_key
                    Planned Partitions: 8  Batches: 9  Memory Usage: 8273kB  Disk Usage: 6672kB
                    Buffers: shared hit=16070, temp read=476 written=1236
                    ->  Hash Join  (cost=874.78..58932.09 rows=1027720 width=16) (actual time=4.566..686.288 rows=1025310.00 loops=1)
                          Hash Cond: (f.station_key = s.station_key)
                          Buffers: shared hit=16070
                          ->  Hash Join  (cost=60.09..55418.98 rows=1027720 width=20) (actual time=0.412..435.817 rows=1025310.00 loops=1)
                                Hash Cond: (f.collection_date = d.full_date)
                                Buffers: shared hit=15652
                                ->  Append  (cost=0.00..52654.86 rows=1027720 width=20) (actual time=0.010..298.716 rows=1025310.00 loops=1)
                                      Buffers: shared hit=15633
                                      ->  Seq Scan on fct_price_observation_2024q1 f_1  (cost=0.00..5331.62 rows=113911 width=20) (actual time=0.009..23.564 rows=112966.00 loops=1)
                                            Filter: ((product_key = ANY ('{1,3}'::integer[])) AND (collection_date >= '2024-01-01'::date))
                                            Rows Removed by Filter: 125542
                                            Buffers: shared hit=1754
                                      ->  Seq Scan on fct_price_observation_2024q2 f_2  (cost=0.00..5334.48 rows=113995 width=20) (actual time=0.028..24.984 rows=113350.00 loops=1)
                                            Filter: ((product_key = ANY ('{1,3}'::integer[])) AND (collection_date >= '2024-01-01'::date))
                                            Rows Removed by Filter: 125282
                                            Buffers: shared hit=1755
                                      ->  Seq Scan on fct_price_observation_2024q3 f_3  (cost=0.00..4866.00 rows=106294 width=20) (actual time=0.027..22.432 rows=105303.00 loops=1)
                                            Filter: ((product_key = ANY ('{1,3}'::integer[])) AND (collection_date >= '2024-01-01'::date))
                                            Rows Removed by Filter: 112364
                                            Buffers: shared hit=1601
                                      ->  Seq Scan on fct_price_observation_2024q4 f_4  (cost=0.00..4553.73 rows=98394 width=20) (actual time=0.022..23.677 rows=98701.00 loops=1)
                                            Filter: ((product_key = ANY ('{1,3}'::integer[])) AND (collection_date >= '2024-01-01'::date))
                                            Rows Removed by Filter: 105014
                                            Buffers: shared hit=1498
                                      ->  Seq Scan on fct_price_observation_2025q1 f_5  (cost=0.00..4640.81 rows=101164 width=20) (actual time=0.027..22.563 rows=100273.00 loops=1)
                                            Filter: ((product_key = ANY ('{1,3}'::integer[])) AND (collection_date >= '2024-01-01'::date))
                                            Rows Removed by Filter: 107314
                                            Buffers: shared hit=1527
                                      ->  Seq Scan on fct_price_observation_2025q2 f_6  (cost=0.00..4757.33 rows=103141 width=20) (actual time=0.030..21.519 rows=103143.00 loops=1)
                                            Filter: ((product_key = ANY ('{1,3}'::integer[])) AND (collection_date >= '2024-01-01'::date))
                                            Rows Removed by Filter: 109679
                                            Buffers: shared hit=1565
                                      ->  Seq Scan on fct_price_observation_2025q3 f_7  (cost=0.00..4102.59 rows=89612 width=20) (actual time=0.026..18.882 rows=89348.00 loops=1)
                                            Filter: ((product_key = ANY ('{1,3}'::integer[])) AND (collection_date >= '2024-01-01'::date))
                                            Rows Removed by Filter: 94158
                                            Buffers: shared hit=1350
                                      ->  Seq Scan on fct_price_observation_2025q4 f_8  (cost=0.00..4486.53 rows=96966 width=20) (actual time=0.026..21.496 rows=97412.00 loops=1)
                                            Filter: ((product_key = ANY ('{1,3}'::integer[])) AND (collection_date >= '2024-01-01'::date))
                                            Rows Removed by Filter: 103290
                                            Buffers: shared hit=1476
                                      ->  Seq Scan on fct_price_observation_2026q1 f_9  (cost=0.00..4646.54 rows=100600 width=20) (actual time=0.028..22.639 rows=100809.00 loops=1)
                                            Filter: ((product_key = ANY ('{1,3}'::integer[])) AND (collection_date >= '2024-01-01'::date))
                                            Rows Removed by Filter: 107027
                                            Buffers: shared hit=1529
                                      ->  Seq Scan on fct_price_observation_2026q2 f_10  (cost=0.00..4796.64 rows=103640 width=20) (actual time=0.025..28.494 rows=104005.00 loops=1)
                                            Filter: ((product_key = ANY ('{1,3}'::integer[])) AND (collection_date >= '2024-01-01'::date))
                                            Rows Removed by Filter: 110571
                                            Buffers: shared hit=1578
                                      ->  Seq Scan on fct_price_observation_2026q3 f_11  (cost=0.00..0.00 rows=1 width=28) (actual time=0.019..0.019 rows=0.00 loops=1)
                                            Filter: ((product_key = ANY ('{1,3}'::integer[])) AND (collection_date >= '2024-01-01'::date))
                                      ->  Seq Scan on fct_price_observation_2026q4 f_12  (cost=0.00..0.00 rows=1 width=28) (actual time=0.006..0.006 rows=0.00 loops=1)
                                            Filter: ((product_key = ANY ('{1,3}'::integer[])) AND (collection_date >= '2024-01-01'::date))
                                      ->  Seq Scan on fct_price_observation_default f_13  (cost=0.00..0.00 rows=1 width=28) (actual time=0.003..0.004 rows=0.00 loops=1)
                                            Filter: ((product_key = ANY ('{1,3}'::integer[])) AND (collection_date >= '2024-01-01'::date))
                                ->  Hash  (cost=37.26..37.26 rows=1826 width=8) (actual time=0.397..0.398 rows=1826.00 loops=1)
                                      Buckets: 2048  Batches: 1  Memory Usage: 88kB
                                      Buffers: shared hit=19
                                      ->  Seq Scan on dim_date d  (cost=0.00..37.26 rows=1826 width=8) (actual time=0.011..0.203 rows=1826.00 loops=1)
                                            Buffers: shared hit=19
                          ->  Hash  (cost=594.31..594.31 rows=17631 width=12) (actual time=4.118..4.119 rows=17631.00 loops=1)
                                Buckets: 32768  Batches: 1  Memory Usage: 1083kB
                                Buffers: shared hit=418
                                ->  Seq Scan on dim_station s  (cost=0.00..594.31 rows=17631 width=12) (actual time=0.007..2.258 rows=17631.00 loops=1)
                                      Buffers: shared hit=418
              ->  Hash  (cost=8.61..8.61 rows=461 width=17) (actual time=0.120..0.121 rows=462.00 loops=1)
                    Buckets: 1024  Batches: 1  Memory Usage: 32kB
                    Buffers: shared hit=4
                    ->  Seq Scan on dim_city c  (cost=0.00..8.61 rows=461 width=17) (actual time=0.014..0.057 rows=462.00 loops=1)
                          Buffers: shared hit=4
Planning:
  Buffers: shared hit=61
Planning Time: 2.759 ms
Execution Time: 1005.836 ms
```

</details>

<details><summary><code>03_paridade_etanol_gasolina</code> — <code>btree_produto_data</code></summary>

```
GroupAggregate  (cost=164164.57..169063.67 rows=460 width=114) (actual time=933.830..949.801 rows=11698.00 loops=1)
  Group Key: d.month_start_date, c.uf, c.city_name
  Filter: (count(*) = 2)
  Rows Removed by Filter: 102
  Buffers: shared hit=16074, temp read=476 written=1236
  ->  Sort  (cost=164164.57..164580.37 rows=166320 width=51) (actual time=933.807..935.882 rows=23498.00 loops=1)
        Sort Key: d.month_start_date, c.uf, c.city_name
        Sort Method: quicksort  Memory: 1957kB
        Buffers: shared hit=16074, temp read=476 written=1236
        ->  Hash Join  (cost=129844.68..144054.13 rows=166320 width=51) (actual time=880.650..918.552 rows=23498.00 loops=1)
              Hash Cond: (s.city_key = c.city_key)
              Buffers: shared hit=16074, temp read=476 written=1236
              ->  HashAggregate  (cost=129830.31..141935.95 rows=166320 width=50) (actual time=880.531..915.059 rows=23498.00 loops=1)
                    Group Key: s.city_key, d.month_start_date, f.product_key
                    Planned Partitions: 8  Batches: 9  Memory Usage: 8273kB  Disk Usage: 6672kB
                    Buffers: shared hit=16070, temp read=476 written=1236
                    ->  Hash Join  (cost=874.78..58921.91 rows=1026728 width=16) (actual time=4.162..639.461 rows=1025310.00 loops=1)
                          Hash Cond: (f.station_key = s.station_key)
                          Buffers: shared hit=16070
                          ->  Hash Join  (cost=60.09..55411.40 rows=1026728 width=20) (actual time=0.399..435.051 rows=1025310.00 loops=1)
                                Hash Cond: (f.collection_date = d.full_date)
                                Buffers: shared hit=15652
                                ->  Append  (cost=0.00..52649.90 rows=1026728 width=20) (actual time=0.006..294.976 rows=1025310.00 loops=1)
                                      Buffers: shared hit=15633
                                      ->  Seq Scan on fct_price_observation_2024q1 f_1  (cost=0.00..5331.62 rows=114086 width=20) (actual time=0.006..25.989 rows=112966.00 loops=1)
                                            Filter: ((product_key = ANY ('{1,3}'::integer[])) AND (collection_date >= '2024-01-01'::date))
                                            Rows Removed by Filter: 125542
                                            Buffers: shared hit=1754
                                      ->  Seq Scan on fct_price_observation_2024q2 f_2  (cost=0.00..5334.48 rows=114042 width=20) (actual time=0.027..27.012 rows=113350.00 loops=1)
                                            Filter: ((product_key = ANY ('{1,3}'::integer[])) AND (collection_date >= '2024-01-01'::date))
                                            Rows Removed by Filter: 125282
                                            Buffers: shared hit=1755
                                      ->  Seq Scan on fct_price_observation_2024q3 f_3  (cost=0.00..4866.00 rows=104342 width=20) (actual time=0.028..21.863 rows=105303.00 loops=1)
                                            Filter: ((product_key = ANY ('{1,3}'::integer[])) AND (collection_date >= '2024-01-01'::date))
                                            Rows Removed by Filter: 112364
                                            Buffers: shared hit=1601
                                      ->  Seq Scan on fct_price_observation_2024q4 f_4  (cost=0.00..4553.73 rows=99406 width=20) (actual time=0.026..23.591 rows=98701.00 loops=1)
                                            Filter: ((product_key = ANY ('{1,3}'::integer[])) AND (collection_date >= '2024-01-01'::date))
                                            Rows Removed by Filter: 105014
                                            Buffers: shared hit=1498
                                      ->  Seq Scan on fct_price_observation_2025q1 f_5  (cost=0.00..4640.81 rows=100306 width=20) (actual time=0.026..20.336 rows=100273.00 loops=1)
                                            Filter: ((product_key = ANY ('{1,3}'::integer[])) AND (collection_date >= '2024-01-01'::date))
                                            Rows Removed by Filter: 107314
                                            Buffers: shared hit=1527
                                      ->  Seq Scan on fct_price_observation_2025q2 f_6  (cost=0.00..4757.33 rows=103119 width=20) (actual time=0.023..22.040 rows=103143.00 loops=1)
                                            Filter: ((product_key = ANY ('{1,3}'::integer[])) AND (collection_date >= '2024-01-01'::date))
                                            Rows Removed by Filter: 109679
                                            Buffers: shared hit=1565
                                      ->  Seq Scan on fct_price_observation_2025q3 f_7  (cost=0.00..4102.59 rows=90309 width=20) (actual time=0.029..19.785 rows=89348.00 loops=1)
                                            Filter: ((product_key = ANY ('{1,3}'::integer[])) AND (collection_date >= '2024-01-01'::date))
                                            Rows Removed by Filter: 94158
                                            Buffers: shared hit=1350
                                      ->  Seq Scan on fct_price_observation_2025q4 f_8  (cost=0.00..4486.53 rows=96879 width=20) (actual time=0.024..21.302 rows=97412.00 loops=1)
                                            Filter: ((product_key = ANY ('{1,3}'::integer[])) AND (collection_date >= '2024-01-01'::date))
                                            Rows Removed by Filter: 103290
                                            Buffers: shared hit=1476
                                      ->  Seq Scan on fct_price_observation_2026q1 f_9  (cost=0.00..4646.54 rows=100031 width=20) (actual time=0.023..22.730 rows=100809.00 loops=1)
                                            Filter: ((product_key = ANY ('{1,3}'::integer[])) AND (collection_date >= '2024-01-01'::date))
                                            Rows Removed by Filter: 107027
                                            Buffers: shared hit=1529
                                      ->  Seq Scan on fct_price_observation_2026q2 f_10  (cost=0.00..4796.64 rows=104205 width=20) (actual time=0.025..23.997 rows=104005.00 loops=1)
                                            Filter: ((product_key = ANY ('{1,3}'::integer[])) AND (collection_date >= '2024-01-01'::date))
                                            Rows Removed by Filter: 110571
                                            Buffers: shared hit=1578
                                      ->  Seq Scan on fct_price_observation_2026q3 f_11  (cost=0.00..0.00 rows=1 width=28) (actual time=0.017..0.017 rows=0.00 loops=1)
                                            Filter: ((product_key = ANY ('{1,3}'::integer[])) AND (collection_date >= '2024-01-01'::date))
                                      ->  Seq Scan on fct_price_observation_2026q4 f_12  (cost=0.00..0.00 rows=1 width=28) (actual time=0.004..0.004 rows=0.00 loops=1)
                                            Filter: ((product_key = ANY ('{1,3}'::integer[])) AND (collection_date >= '2024-01-01'::date))
                                      ->  Seq Scan on fct_price_observation_default f_13  (cost=0.00..0.00 rows=1 width=28) (actual time=0.004..0.005 rows=0.00 loops=1)
                                            Filter: ((product_key = ANY ('{1,3}'::integer[])) AND (collection_date >= '2024-01-01'::date))
                                ->  Hash  (cost=37.26..37.26 rows=1826 width=8) (actual time=0.388..0.388 rows=1826.00 loops=1)
                                      Buckets: 2048  Batches: 1  Memory Usage: 88kB
                                      Buffers: shared hit=19
                                      ->  Seq Scan on dim_date d  (cost=0.00..37.26 rows=1826 width=8) (actual time=0.004..0.184 rows=1826.00 loops=1)
                                            Buffers: shared hit=19
                          ->  Hash  (cost=594.31..594.31 rows=17631 width=12) (actual time=3.736..3.737 rows=17631.00 loops=1)
                                Buckets: 32768  Batches: 1  Memory Usage: 1083kB
                                Buffers: shared hit=418
                                ->  Seq Scan on dim_station s  (cost=0.00..594.31 rows=17631 width=12) (actual time=0.005..1.922 rows=17631.00 loops=1)
                                      Buffers: shared hit=418
              ->  Hash  (cost=8.61..8.61 rows=461 width=17) (actual time=0.113..0.114 rows=462.00 loops=1)
                    Buckets: 1024  Batches: 1  Memory Usage: 32kB
                    Buffers: shared hit=4
                    ->  Seq Scan on dim_city c  (cost=0.00..8.61 rows=461 width=17) (actual time=0.013..0.052 rows=462.00 loops=1)
                          Buffers: shared hit=4
Planning:
  Buffers: shared hit=28
Planning Time: 1.551 ms
Execution Time: 951.012 ms
```

</details>

<details><summary><code>03_paridade_etanol_gasolina</code> — <code>btree_posto_data</code></summary>

```
GroupAggregate  (cost=164119.58..169018.68 rows=460 width=114) (actual time=1047.434..1064.674 rows=11698.00 loops=1)
  Group Key: d.month_start_date, c.uf, c.city_name
  Filter: (count(*) = 2)
  Rows Removed by Filter: 102
  Buffers: shared hit=16074, temp read=476 written=1236
  ->  Sort  (cost=164119.58..164535.38 rows=166320 width=51) (actual time=1047.410..1049.851 rows=23498.00 loops=1)
        Sort Key: d.month_start_date, c.uf, c.city_name
        Sort Method: quicksort  Memory: 1957kB
        Buffers: shared hit=16074, temp read=476 written=1236
        ->  Hash Join  (cost=129804.63..144009.14 rows=166320 width=51) (actual time=987.703..1031.551 rows=23498.00 loops=1)
              Hash Cond: (s.city_key = c.city_key)
              Buffers: shared hit=16074, temp read=476 written=1236
              ->  HashAggregate  (cost=129790.26..141890.97 rows=166320 width=50) (actual time=987.581..1027.752 rows=23498.00 loops=1)
                    Group Key: s.city_key, d.month_start_date, f.product_key
                    Planned Partitions: 8  Batches: 9  Memory Usage: 8273kB  Disk Usage: 6672kB
                    Buffers: shared hit=16070, temp read=476 written=1236
                    ->  Hash Join  (cost=874.78..58916.73 rows=1026223 width=16) (actual time=4.989..720.901 rows=1025310.00 loops=1)
                          Hash Cond: (f.station_key = s.station_key)
                          Buffers: shared hit=16070
                          ->  Hash Join  (cost=60.09..55407.55 rows=1026223 width=20) (actual time=0.750..457.155 rows=1025310.00 loops=1)
                                Hash Cond: (f.collection_date = d.full_date)
                                Buffers: shared hit=15652
                                ->  Append  (cost=0.00..52647.38 rows=1026223 width=20) (actual time=0.007..309.074 rows=1025310.00 loops=1)
                                      Buffers: shared hit=15633
                                      ->  Seq Scan on fct_price_observation_2024q1 f_1  (cost=0.00..5331.62 rows=112838 width=20) (actual time=0.007..28.740 rows=112966.00 loops=1)
                                            Filter: ((product_key = ANY ('{1,3}'::integer[])) AND (collection_date >= '2024-01-01'::date))
                                            Rows Removed by Filter: 125542
                                            Buffers: shared hit=1754
                                      ->  Seq Scan on fct_price_observation_2024q2 f_2  (cost=0.00..5334.48 rows=114329 width=20) (actual time=0.028..29.730 rows=113350.00 loops=1)
                                            Filter: ((product_key = ANY ('{1,3}'::integer[])) AND (collection_date >= '2024-01-01'::date))
                                            Rows Removed by Filter: 125282
                                            Buffers: shared hit=1755
                                      ->  Seq Scan on fct_price_observation_2024q3 f_3  (cost=0.00..4866.00 rows=106076 width=20) (actual time=0.028..24.062 rows=105303.00 loops=1)
                                            Filter: ((product_key = ANY ('{1,3}'::integer[])) AND (collection_date >= '2024-01-01'::date))
                                            Rows Removed by Filter: 112364
                                            Buffers: shared hit=1601
                                      ->  Seq Scan on fct_price_observation_2024q4 f_4  (cost=0.00..4553.73 rows=98836 width=20) (actual time=0.024..24.245 rows=98701.00 loops=1)
                                            Filter: ((product_key = ANY ('{1,3}'::integer[])) AND (collection_date >= '2024-01-01'::date))
                                            Rows Removed by Filter: 105014
                                            Buffers: shared hit=1498
                                      ->  Seq Scan on fct_price_observation_2025q1 f_5  (cost=0.00..4640.81 rows=100387 width=20) (actual time=0.027..21.052 rows=100273.00 loops=1)
                                            Filter: ((product_key = ANY ('{1,3}'::integer[])) AND (collection_date >= '2024-01-01'::date))
                                            Rows Removed by Filter: 107314
                                            Buffers: shared hit=1527
                                      ->  Seq Scan on fct_price_observation_2025q2 f_6  (cost=0.00..4757.33 rows=103048 width=20) (actual time=0.025..21.684 rows=103143.00 loops=1)
                                            Filter: ((product_key = ANY ('{1,3}'::integer[])) AND (collection_date >= '2024-01-01'::date))
                                            Rows Removed by Filter: 109679
                                            Buffers: shared hit=1565
                                      ->  Seq Scan on fct_price_observation_2025q3 f_7  (cost=0.00..4102.59 rows=88890 width=20) (actual time=0.027..18.164 rows=89348.00 loops=1)
                                            Filter: ((product_key = ANY ('{1,3}'::integer[])) AND (collection_date >= '2024-01-01'::date))
                                            Rows Removed by Filter: 94158
                                            Buffers: shared hit=1350
                                      ->  Seq Scan on fct_price_observation_2025q4 f_8  (cost=0.00..4486.53 rows=97026 width=20) (actual time=0.021..21.535 rows=97412.00 loops=1)
                                            Filter: ((product_key = ANY ('{1,3}'::integer[])) AND (collection_date >= '2024-01-01'::date))
                                            Rows Removed by Filter: 103290
                                            Buffers: shared hit=1476
                                      ->  Seq Scan on fct_price_observation_2026q1 f_9  (cost=0.00..4646.54 rows=101064 width=20) (actual time=0.028..22.429 rows=100809.00 loops=1)
                                            Filter: ((product_key = ANY ('{1,3}'::integer[])) AND (collection_date >= '2024-01-01'::date))
                                            Rows Removed by Filter: 107027
                                            Buffers: shared hit=1529
                                      ->  Seq Scan on fct_price_observation_2026q2 f_10  (cost=0.00..4796.64 rows=103726 width=20) (actual time=0.029..26.909 rows=104005.00 loops=1)
                                            Filter: ((product_key = ANY ('{1,3}'::integer[])) AND (collection_date >= '2024-01-01'::date))
                                            Rows Removed by Filter: 110571
                                            Buffers: shared hit=1578
                                      ->  Seq Scan on fct_price_observation_2026q3 f_11  (cost=0.00..0.00 rows=1 width=28) (actual time=0.017..0.017 rows=0.00 loops=1)
                                            Filter: ((product_key = ANY ('{1,3}'::integer[])) AND (collection_date >= '2024-01-01'::date))
                                      ->  Seq Scan on fct_price_observation_2026q4 f_12  (cost=0.00..0.00 rows=1 width=28) (actual time=0.003..0.003 rows=0.00 loops=1)
                                            Filter: ((product_key = ANY ('{1,3}'::integer[])) AND (collection_date >= '2024-01-01'::date))
                                      ->  Seq Scan on fct_price_observation_default f_13  (cost=0.00..0.00 rows=1 width=28) (actual time=0.004..0.004 rows=0.00 loops=1)
                                            Filter: ((product_key = ANY ('{1,3}'::integer[])) AND (collection_date >= '2024-01-01'::date))
                                ->  Hash  (cost=37.26..37.26 rows=1826 width=8) (actual time=0.737..0.738 rows=1826.00 loops=1)
                                      Buckets: 2048  Batches: 1  Memory Usage: 88kB
                                      Buffers: shared hit=19
                                      ->  Seq Scan on dim_date d  (cost=0.00..37.26 rows=1826 width=8) (actual time=0.004..0.232 rows=1826.00 loops=1)
                                            Buffers: shared hit=19
                          ->  Hash  (cost=594.31..594.31 rows=17631 width=12) (actual time=4.211..4.212 rows=17631.00 loops=1)
                                Buckets: 32768  Batches: 1  Memory Usage: 1083kB
                                Buffers: shared hit=418
                                ->  Seq Scan on dim_station s  (cost=0.00..594.31 rows=17631 width=12) (actual time=0.008..2.051 rows=17631.00 loops=1)
                                      Buffers: shared hit=418
              ->  Hash  (cost=8.61..8.61 rows=461 width=17) (actual time=0.116..0.116 rows=462.00 loops=1)
                    Buckets: 1024  Batches: 1  Memory Usage: 32kB
                    Buffers: shared hit=4
                    ->  Seq Scan on dim_city c  (cost=0.00..8.61 rows=461 width=17) (actual time=0.014..0.053 rows=462.00 loops=1)
                          Buffers: shared hit=4
Planning:
  Buffers: shared hit=28
Planning Time: 2.750 ms
Execution Time: 1066.132 ms
```

</details>

<details><summary><code>04_evento_troca_bandeira</code> — <code>sem_indice</code></summary>

```
Aggregate  (cost=1528.48..1528.50 rows=1 width=88) (actual time=215.011..215.022 rows=1.00 loops=1)
  Buffers: shared hit=317668
  ->  GroupAggregate  (cost=1527.87..1528.44 rows=1 width=99) (actual time=213.474..214.868 rows=213.00 loops=1)
        Group Key: curr.cnpj, s.city_key
        Filter: ((count(*) FILTER (WHERE (CASE WHEN (f.collection_date < curr.valid_from) THEN 'antes'::text ELSE 'depois'::text END = 'antes'::text)) >= 4) AND (count(*) FILTER (WHERE (CASE WHEN (f.collection_date < curr.valid_from) THEN 'antes'::text ELSE 'depois'::text END = 'depois'::text)) >= 4))
        Rows Removed by Filter: 254
        Buffers: shared hit=317668
        ->  Sort  (cost=1527.87..1527.89 rows=10 width=33) (actual time=213.450..213.620 rows=4102.00 loops=1)
              Sort Key: curr.cnpj, s.city_key
              Sort Method: quicksort  Memory: 417kB
              Buffers: shared hit=317668
              ->  Nested Loop  (cost=543.51..1527.70 rows=10 width=33) (actual time=62.748..212.058 rows=4102.00 loops=1)
                    Buffers: shared hit=317668
                    ->  Nested Loop  (cost=543.22..1524.63 rows=10 width=37) (actual time=62.741..206.487 rows=4102.00 loops=1)
                          Buffers: shared hit=305362
                          ->  Hash Join  (cost=542.80..1401.58 rows=1 width=35) (actual time=62.679..71.554 rows=476.00 loops=1)
                                Hash Cond: ((prev.cnpj = curr.cnpj) AND (prev.valid_to = curr.valid_from) AND (prev.brand_key = b_prev.brand_key))
                                Join Filter: (prev.brand_key <> curr.brand_key)
                                Buffers: shared hit=99640
                                ->  Seq Scan on dim_station prev  (cost=0.00..594.31 rows=17631 width=31) (actual time=0.011..1.607 rows=17631.00 loops=1)
                                      Buffers: shared hit=418
                                ->  Hash  (cost=522.37..522.37 rows=1167 width=35) (actual time=62.605..62.608 rows=101035.00 loops=1)
                                      Buckets: 131072 (originally 2048)  Batches: 1 (originally 1)  Memory Usage: 7734kB
                                      Buffers: shared hit=99222
                                      ->  Nested Loop  (cost=0.29..522.37 rows=1167 width=35) (actual time=0.049..43.327 rows=101035.00 loops=1)
                                            Buffers: shared hit=99222
                                            ->  Nested Loop  (cost=0.00..42.16 rows=13 width=8) (actual time=0.034..0.404 rows=55.00 loops=1)
                                                  Join Filter: (CASE WHEN (b_prev.is_unbranded AND (NOT b_curr.is_unbranded)) THEN 'bandeiramento'::text WHEN ((NOT b_prev.is_unbranded) AND b_curr.is_unbranded) THEN 'desbandeiramento'::text ELSE 'troca de distribuidora'::text END = 'desbandeiramento'::text)
                                                  Rows Removed by Join Filter: 3081
                                                  Buffers: shared hit=2
                                                  ->  Seq Scan on dim_brand b_prev  (cost=0.00..1.51 rows=51 width=5) (actual time=0.005..0.011 rows=56.00 loops=1)
                                                        Buffers: shared hit=1
                                                  ->  Materialize  (cost=0.00..1.77 rows=51 width=5) (actual time=0.000..0.002 rows=56.00 loops=56)
                                                        Storage: Memory  Maximum Storage: 18kB
                                                        Buffers: shared hit=1
                                                        ->  Seq Scan on dim_brand b_curr  (cost=0.00..1.51 rows=51 width=5) (actual time=0.006..0.010 rows=56.00 loops=1)
                                                              Buffers: shared hit=1
                                            ->  Index Scan using dim_station_brand_idx on dim_station curr  (cost=0.29..36.12 rows=82 width=31) (actual time=0.004..0.541 rows=1837.00 loops=55)
                                                  Index Cond: ((brand_key = b_curr.brand_key) AND (valid_from >= '2024-01-01'::date) AND (valid_from < '2025-07-01'::date))
                                                  Index Searches: 55
                                                  Buffers: shared hit=99220
                          ->  Append  (cost=0.42..122.74 rows=31 width=18) (actual time=0.058..0.281 rows=8.62 loops=476)
                                Buffers: shared hit=205722
                                ->  Index Scan using fct_price_observation_2023q1_pkey on fct_price_observation_2023q1 f_1  (cost=0.42..8.31 rows=2 width=18) (never executed)
                                      Index Cond: ((collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)) AND (station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (product_key = 1))
                                      Index Searches: 0
                                ->  Index Scan using fct_price_observation_2023q2_pkey on fct_price_observation_2023q2 f_2  (cost=0.42..8.57 rows=2 width=18) (never executed)
                                      Index Cond: ((collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)) AND (station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (product_key = 1))
                                      Index Searches: 0
                                ->  Index Scan using fct_price_observation_2023q3_pkey on fct_price_observation_2023q3 f_3  (cost=0.42..8.66 rows=2 width=18) (never executed)
                                      Index Cond: ((collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)) AND (station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (product_key = 1))
                                      Index Searches: 0
                                ->  Index Scan using fct_price_observation_2023q4_pkey on fct_price_observation_2023q4 f_4  (cost=0.42..8.66 rows=2 width=18) (actual time=0.033..0.065 rows=1.49 loops=41)
                                      Index Cond: ((collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)) AND (station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (product_key = 1))
                                      Index Searches: 1194
                                      Buffers: shared hit=3689
                                ->  Index Scan using fct_price_observation_2024q1_pkey on fct_price_observation_2024q1 f_5  (cost=0.42..8.68 rows=2 width=18) (actual time=0.034..0.134 rows=4.35 loops=109)
                                      Index Cond: ((collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)) AND (station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (product_key = 1))
                                      Index Searches: 7427
                                      Buffers: shared hit=22755
                                ->  Index Scan using fct_price_observation_2024q2_pkey on fct_price_observation_2024q2 f_6  (cost=0.42..8.68 rows=2 width=18) (actual time=0.035..0.137 rows=4.41 loops=143)
                                      Index Cond: ((collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)) AND (station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (product_key = 1))
                                      Index Searches: 9747
                                      Buffers: shared hit=29906
                                ->  Index Scan using fct_price_observation_2024q3_pkey on fct_price_observation_2024q3 f_7  (cost=0.42..9.33 rows=2 width=18) (actual time=0.039..0.119 rows=3.20 loops=164)
                                      Index Cond: ((collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)) AND (station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (product_key = 1))
                                      Index Searches: 9412
                                      Buffers: shared hit=28760
                                ->  Index Scan using fct_price_observation_2024q4_pkey on fct_price_observation_2024q4 f_8  (cost=0.42..9.18 rows=2 width=18) (actual time=0.042..0.128 rows=3.86 loops=198)
                                      Index Cond: ((collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)) AND (station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (product_key = 1))
                                      Index Searches: 12862
                                      Buffers: shared hit=39351
                                ->  Index Scan using fct_price_observation_2025q1_pkey on fct_price_observation_2025q1 f_9  (cost=0.42..8.35 rows=2 width=18) (actual time=0.039..0.126 rows=4.19 loops=211)
                                      Index Cond: ((collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)) AND (station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (product_key = 1))
                                      Index Searches: 14431
                                      Buffers: shared hit=44180
                                ->  Index Scan using fct_price_observation_2025q2_pkey on fct_price_observation_2025q2 f_10  (cost=0.42..9.28 rows=2 width=18) (actual time=0.034..0.141 rows=4.84 loops=145)
                                      Index Cond: ((collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)) AND (station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (product_key = 1))
                                      Index Searches: 10499
                                      Buffers: shared hit=32247
                                ->  Index Scan using fct_price_observation_2025q3_pkey on fct_price_observation_2025q3 f_11  (cost=0.42..8.96 rows=2 width=18) (actual time=0.053..0.086 rows=1.33 loops=46)
                                      Index Cond: ((collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)) AND (station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (product_key = 1))
                                      Index Searches: 1591
                                      Buffers: shared hit=4834
                                ->  Index Scan using fct_price_observation_2025q4_pkey on fct_price_observation_2025q4 f_12  (cost=0.42..9.15 rows=2 width=18) (never executed)
                                      Index Cond: ((collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)) AND (station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (product_key = 1))
                                      Index Searches: 0
                                ->  Index Scan using fct_price_observation_2026q1_pkey on fct_price_observation_2026q1 f_13  (cost=0.42..8.35 rows=2 width=18) (never executed)
                                      Index Cond: ((collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)) AND (station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (product_key = 1))
                                      Index Searches: 0
                                ->  Index Scan using fct_price_observation_2026q2_pkey on fct_price_observation_2026q2 f_14  (cost=0.42..8.43 rows=2 width=18) (never executed)
                                      Index Cond: ((collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)) AND (station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (product_key = 1))
                                      Index Searches: 0
                                ->  Seq Scan on fct_price_observation_2026q3 f_15  (cost=0.00..0.00 rows=1 width=26) (never executed)
                                      Filter: ((product_key = 1) AND ((station_key = prev.station_key) OR (station_key = curr.station_key)) AND (collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)))
                                ->  Seq Scan on fct_price_observation_2026q4 f_16  (cost=0.00..0.00 rows=1 width=26) (never executed)
                                      Filter: ((product_key = 1) AND ((station_key = prev.station_key) OR (station_key = curr.station_key)) AND (collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)))
                                ->  Seq Scan on fct_price_observation_default f_17  (cost=0.00..0.00 rows=1 width=26) (never executed)
                                      Filter: ((product_key = 1) AND ((station_key = prev.station_key) OR (station_key = curr.station_key)) AND (collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)))
                    ->  Index Scan using dim_station_pkey on dim_station s  (cost=0.29..0.31 rows=1 width=12) (actual time=0.001..0.001 rows=1.00 loops=4102)
                          Index Cond: (station_key = f.station_key)
                          Index Searches: 4102
                          Buffers: shared hit=12306
Planning:
  Buffers: shared hit=43
Planning Time: 4.922 ms
Execution Time: 215.304 ms
```

</details>

<details><summary><code>04_evento_troca_bandeira</code> — <code>brin_date</code></summary>

```
Aggregate  (cost=1530.22..1530.24 rows=1 width=88) (actual time=230.892..230.904 rows=1.00 loops=1)
  Buffers: shared hit=317668
  ->  GroupAggregate  (cost=1529.61..1530.18 rows=1 width=99) (actual time=229.287..230.744 rows=213.00 loops=1)
        Group Key: curr.cnpj, s.city_key
        Filter: ((count(*) FILTER (WHERE (CASE WHEN (f.collection_date < curr.valid_from) THEN 'antes'::text ELSE 'depois'::text END = 'antes'::text)) >= 4) AND (count(*) FILTER (WHERE (CASE WHEN (f.collection_date < curr.valid_from) THEN 'antes'::text ELSE 'depois'::text END = 'depois'::text)) >= 4))
        Rows Removed by Filter: 254
        Buffers: shared hit=317668
        ->  Sort  (cost=1529.61..1529.63 rows=10 width=33) (actual time=229.259..229.437 rows=4102.00 loops=1)
              Sort Key: curr.cnpj, s.city_key
              Sort Method: quicksort  Memory: 417kB
              Buffers: shared hit=317668
              ->  Nested Loop  (cost=543.51..1529.44 rows=10 width=33) (actual time=71.451..227.722 rows=4102.00 loops=1)
                    Buffers: shared hit=317668
                    ->  Nested Loop  (cost=543.22..1526.37 rows=10 width=37) (actual time=71.443..222.029 rows=4102.00 loops=1)
                          Buffers: shared hit=305362
                          ->  Hash Join  (cost=542.80..1401.58 rows=1 width=35) (actual time=71.370..80.396 rows=476.00 loops=1)
                                Hash Cond: ((prev.cnpj = curr.cnpj) AND (prev.valid_to = curr.valid_from) AND (prev.brand_key = b_prev.brand_key))
                                Join Filter: (prev.brand_key <> curr.brand_key)
                                Buffers: shared hit=99640
                                ->  Seq Scan on dim_station prev  (cost=0.00..594.31 rows=17631 width=31) (actual time=0.015..1.640 rows=17631.00 loops=1)
                                      Buffers: shared hit=418
                                ->  Hash  (cost=522.37..522.37 rows=1167 width=35) (actual time=71.290..71.293 rows=101035.00 loops=1)
                                      Buckets: 131072 (originally 2048)  Batches: 1 (originally 1)  Memory Usage: 7734kB
                                      Buffers: shared hit=99222
                                      ->  Nested Loop  (cost=0.29..522.37 rows=1167 width=35) (actual time=0.054..49.964 rows=101035.00 loops=1)
                                            Buffers: shared hit=99222
                                            ->  Nested Loop  (cost=0.00..42.16 rows=13 width=8) (actual time=0.035..0.456 rows=55.00 loops=1)
                                                  Join Filter: (CASE WHEN (b_prev.is_unbranded AND (NOT b_curr.is_unbranded)) THEN 'bandeiramento'::text WHEN ((NOT b_prev.is_unbranded) AND b_curr.is_unbranded) THEN 'desbandeiramento'::text ELSE 'troca de distribuidora'::text END = 'desbandeiramento'::text)
                                                  Rows Removed by Join Filter: 3081
                                                  Buffers: shared hit=2
                                                  ->  Seq Scan on dim_brand b_prev  (cost=0.00..1.51 rows=51 width=5) (actual time=0.006..0.014 rows=56.00 loops=1)
                                                        Buffers: shared hit=1
                                                  ->  Materialize  (cost=0.00..1.77 rows=51 width=5) (actual time=0.000..0.003 rows=56.00 loops=56)
                                                        Storage: Memory  Maximum Storage: 18kB
                                                        Buffers: shared hit=1
                                                        ->  Seq Scan on dim_brand b_curr  (cost=0.00..1.51 rows=51 width=5) (actual time=0.005..0.009 rows=56.00 loops=1)
                                                              Buffers: shared hit=1
                                            ->  Index Scan using dim_station_brand_idx on dim_station curr  (cost=0.29..36.12 rows=82 width=31) (actual time=0.005..0.601 rows=1837.00 loops=55)
                                                  Index Cond: ((brand_key = b_curr.brand_key) AND (valid_from >= '2024-01-01'::date) AND (valid_from < '2025-07-01'::date))
                                                  Index Searches: 55
                                                  Buffers: shared hit=99220
                          ->  Append  (cost=0.42..124.48 rows=31 width=18) (actual time=0.063..0.295 rows=8.62 loops=476)
                                Buffers: shared hit=205722
                                ->  Index Scan using fct_price_observation_2023q1_pkey on fct_price_observation_2023q1 f_1  (cost=0.42..8.31 rows=2 width=18) (never executed)
                                      Index Cond: ((collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)) AND (station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (product_key = 1))
                                      Index Searches: 0
                                ->  Index Scan using fct_price_observation_2023q2_pkey on fct_price_observation_2023q2 f_2  (cost=0.42..8.57 rows=2 width=18) (never executed)
                                      Index Cond: ((collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)) AND (station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (product_key = 1))
                                      Index Searches: 0
                                ->  Index Scan using fct_price_observation_2023q3_pkey on fct_price_observation_2023q3 f_3  (cost=0.42..8.66 rows=2 width=18) (never executed)
                                      Index Cond: ((collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)) AND (station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (product_key = 1))
                                      Index Searches: 0
                                ->  Index Scan using fct_price_observation_2023q4_pkey on fct_price_observation_2023q4 f_4  (cost=0.42..8.66 rows=2 width=18) (actual time=0.037..0.070 rows=1.49 loops=41)
                                      Index Cond: ((collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)) AND (station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (product_key = 1))
                                      Index Searches: 1194
                                      Buffers: shared hit=3689
                                ->  Index Scan using fct_price_observation_2024q1_pkey on fct_price_observation_2024q1 f_5  (cost=0.42..8.68 rows=2 width=18) (actual time=0.035..0.138 rows=4.35 loops=109)
                                      Index Cond: ((collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)) AND (station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (product_key = 1))
                                      Index Searches: 7427
                                      Buffers: shared hit=22755
                                ->  Index Scan using fct_price_observation_2024q2_pkey on fct_price_observation_2024q2 f_6  (cost=0.42..8.68 rows=2 width=18) (actual time=0.037..0.141 rows=4.41 loops=143)
                                      Index Cond: ((collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)) AND (station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (product_key = 1))
                                      Index Searches: 9747
                                      Buffers: shared hit=29906
                                ->  Index Scan using fct_price_observation_2024q3_pkey on fct_price_observation_2024q3 f_7  (cost=0.42..9.33 rows=2 width=18) (actual time=0.041..0.123 rows=3.20 loops=164)
                                      Index Cond: ((collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)) AND (station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (product_key = 1))
                                      Index Searches: 9412
                                      Buffers: shared hit=28760
                                ->  Index Scan using fct_price_observation_2024q4_pkey on fct_price_observation_2024q4 f_8  (cost=0.42..9.18 rows=2 width=18) (actual time=0.045..0.134 rows=3.86 loops=198)
                                      Index Cond: ((collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)) AND (station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (product_key = 1))
                                      Index Searches: 12862
                                      Buffers: shared hit=39351
                                ->  Index Scan using fct_price_observation_2025q1_pkey on fct_price_observation_2025q1 f_9  (cost=0.42..9.22 rows=2 width=18) (actual time=0.043..0.135 rows=4.19 loops=211)
                                      Index Cond: ((collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)) AND (station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (product_key = 1))
                                      Index Searches: 14431
                                      Buffers: shared hit=44180
                                ->  Index Scan using fct_price_observation_2025q2_pkey on fct_price_observation_2025q2 f_10  (cost=0.42..9.28 rows=2 width=18) (actual time=0.037..0.150 rows=4.84 loops=145)
                                      Index Cond: ((collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)) AND (station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (product_key = 1))
                                      Index Searches: 10499
                                      Buffers: shared hit=32247
                                ->  Index Scan using fct_price_observation_2025q3_pkey on fct_price_observation_2025q3 f_11  (cost=0.42..8.96 rows=2 width=18) (actual time=0.055..0.090 rows=1.33 loops=46)
                                      Index Cond: ((collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)) AND (station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (product_key = 1))
                                      Index Searches: 1591
                                      Buffers: shared hit=4834
                                ->  Index Scan using fct_price_observation_2025q4_pkey on fct_price_observation_2025q4 f_12  (cost=0.42..9.15 rows=2 width=18) (never executed)
                                      Index Cond: ((collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)) AND (station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (product_key = 1))
                                      Index Searches: 0
                                ->  Index Scan using fct_price_observation_2026q1_pkey on fct_price_observation_2026q1 f_13  (cost=0.42..8.35 rows=2 width=18) (never executed)
                                      Index Cond: ((collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)) AND (station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (product_key = 1))
                                      Index Searches: 0
                                ->  Index Scan using fct_price_observation_2026q2_pkey on fct_price_observation_2026q2 f_14  (cost=0.42..9.30 rows=2 width=18) (never executed)
                                      Index Cond: ((collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)) AND (station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (product_key = 1))
                                      Index Searches: 0
                                ->  Seq Scan on fct_price_observation_2026q3 f_15  (cost=0.00..0.00 rows=1 width=26) (never executed)
                                      Filter: ((product_key = 1) AND ((station_key = prev.station_key) OR (station_key = curr.station_key)) AND (collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)))
                                ->  Seq Scan on fct_price_observation_2026q4 f_16  (cost=0.00..0.00 rows=1 width=26) (never executed)
                                      Filter: ((product_key = 1) AND ((station_key = prev.station_key) OR (station_key = curr.station_key)) AND (collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)))
                                ->  Seq Scan on fct_price_observation_default f_17  (cost=0.00..0.00 rows=1 width=26) (never executed)
                                      Filter: ((product_key = 1) AND ((station_key = prev.station_key) OR (station_key = curr.station_key)) AND (collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)))
                    ->  Index Scan using dim_station_pkey on dim_station s  (cost=0.29..0.31 rows=1 width=12) (actual time=0.001..0.001 rows=1.00 loops=4102)
                          Index Cond: (station_key = f.station_key)
                          Index Searches: 4102
                          Buffers: shared hit=12306
Planning:
  Buffers: shared hit=60
Planning Time: 4.671 ms
Execution Time: 231.187 ms
```

</details>

<details><summary><code>04_evento_troca_bandeira</code> — <code>btree_produto_data</code></summary>

```
Aggregate  (cost=1529.35..1529.37 rows=1 width=88) (actual time=253.459..253.473 rows=1.00 loops=1)
  Buffers: shared hit=317668
  ->  GroupAggregate  (cost=1528.74..1529.31 rows=1 width=99) (actual time=251.884..253.312 rows=213.00 loops=1)
        Group Key: curr.cnpj, s.city_key
        Filter: ((count(*) FILTER (WHERE (CASE WHEN (f.collection_date < curr.valid_from) THEN 'antes'::text ELSE 'depois'::text END = 'antes'::text)) >= 4) AND (count(*) FILTER (WHERE (CASE WHEN (f.collection_date < curr.valid_from) THEN 'antes'::text ELSE 'depois'::text END = 'depois'::text)) >= 4))
        Rows Removed by Filter: 254
        Buffers: shared hit=317668
        ->  Sort  (cost=1528.74..1528.76 rows=10 width=33) (actual time=251.858..252.028 rows=4102.00 loops=1)
              Sort Key: curr.cnpj, s.city_key
              Sort Method: quicksort  Memory: 417kB
              Buffers: shared hit=317668
              ->  Nested Loop  (cost=543.51..1528.57 rows=10 width=33) (actual time=67.513..250.011 rows=4102.00 loops=1)
                    Buffers: shared hit=317668
                    ->  Nested Loop  (cost=543.22..1525.50 rows=10 width=37) (actual time=67.504..243.450 rows=4102.00 loops=1)
                          Buffers: shared hit=305362
                          ->  Hash Join  (cost=542.80..1401.58 rows=1 width=35) (actual time=67.432..79.747 rows=476.00 loops=1)
                                Hash Cond: ((prev.cnpj = curr.cnpj) AND (prev.valid_to = curr.valid_from) AND (prev.brand_key = b_prev.brand_key))
                                Join Filter: (prev.brand_key <> curr.brand_key)
                                Buffers: shared hit=99640
                                ->  Seq Scan on dim_station prev  (cost=0.00..594.31 rows=17631 width=31) (actual time=0.012..1.705 rows=17631.00 loops=1)
                                      Buffers: shared hit=418
                                ->  Hash  (cost=522.37..522.37 rows=1167 width=35) (actual time=67.344..67.350 rows=101035.00 loops=1)
                                      Buckets: 131072 (originally 2048)  Batches: 1 (originally 1)  Memory Usage: 7734kB
                                      Buffers: shared hit=99222
                                      ->  Nested Loop  (cost=0.29..522.37 rows=1167 width=35) (actual time=0.054..46.834 rows=101035.00 loops=1)
                                            Buffers: shared hit=99222
                                            ->  Nested Loop  (cost=0.00..42.16 rows=13 width=8) (actual time=0.038..0.453 rows=55.00 loops=1)
                                                  Join Filter: (CASE WHEN (b_prev.is_unbranded AND (NOT b_curr.is_unbranded)) THEN 'bandeiramento'::text WHEN ((NOT b_prev.is_unbranded) AND b_curr.is_unbranded) THEN 'desbandeiramento'::text ELSE 'troca de distribuidora'::text END = 'desbandeiramento'::text)
                                                  Rows Removed by Join Filter: 3081
                                                  Buffers: shared hit=2
                                                  ->  Seq Scan on dim_brand b_prev  (cost=0.00..1.51 rows=51 width=5) (actual time=0.006..0.017 rows=56.00 loops=1)
                                                        Buffers: shared hit=1
                                                  ->  Materialize  (cost=0.00..1.77 rows=51 width=5) (actual time=0.000..0.003 rows=56.00 loops=56)
                                                        Storage: Memory  Maximum Storage: 18kB
                                                        Buffers: shared hit=1
                                                        ->  Seq Scan on dim_brand b_curr  (cost=0.00..1.51 rows=51 width=5) (actual time=0.006..0.010 rows=56.00 loops=1)
                                                              Buffers: shared hit=1
                                            ->  Index Scan using dim_station_brand_idx on dim_station curr  (cost=0.29..36.12 rows=82 width=31) (actual time=0.006..0.580 rows=1837.00 loops=55)
                                                  Index Cond: ((brand_key = b_curr.brand_key) AND (valid_from >= '2024-01-01'::date) AND (valid_from < '2025-07-01'::date))
                                                  Index Searches: 55
                                                  Buffers: shared hit=99220
                          ->  Append  (cost=0.42..123.61 rows=31 width=18) (actual time=0.070..0.342 rows=8.62 loops=476)
                                Buffers: shared hit=205722
                                ->  Index Scan using fct_price_observation_2023q1_pkey on fct_price_observation_2023q1 f_1  (cost=0.42..8.31 rows=2 width=18) (never executed)
                                      Index Cond: ((collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)) AND (station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (product_key = 1))
                                      Index Searches: 0
                                ->  Index Scan using fct_price_observation_2023q2_pkey on fct_price_observation_2023q2 f_2  (cost=0.42..8.57 rows=2 width=18) (never executed)
                                      Index Cond: ((collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)) AND (station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (product_key = 1))
                                      Index Searches: 0
                                ->  Index Scan using fct_price_observation_2023q3_pkey on fct_price_observation_2023q3 f_3  (cost=0.42..8.66 rows=2 width=18) (never executed)
                                      Index Cond: ((collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)) AND (station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (product_key = 1))
                                      Index Searches: 0
                                ->  Index Scan using fct_price_observation_2023q4_pkey on fct_price_observation_2023q4 f_4  (cost=0.42..8.66 rows=2 width=18) (actual time=0.043..0.088 rows=1.49 loops=41)
                                      Index Cond: ((collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)) AND (station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (product_key = 1))
                                      Index Searches: 1194
                                      Buffers: shared hit=3689
                                ->  Index Scan using fct_price_observation_2024q1_pkey on fct_price_observation_2024q1 f_5  (cost=0.42..8.68 rows=2 width=18) (actual time=0.041..0.170 rows=4.35 loops=109)
                                      Index Cond: ((collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)) AND (station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (product_key = 1))
                                      Index Searches: 7427
                                      Buffers: shared hit=22755
                                ->  Index Scan using fct_price_observation_2024q2_pkey on fct_price_observation_2024q2 f_6  (cost=0.42..8.68 rows=2 width=18) (actual time=0.041..0.161 rows=4.41 loops=143)
                                      Index Cond: ((collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)) AND (station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (product_key = 1))
                                      Index Searches: 9747
                                      Buffers: shared hit=29906
                                ->  Index Scan using fct_price_observation_2024q3_pkey on fct_price_observation_2024q3 f_7  (cost=0.42..9.33 rows=2 width=18) (actual time=0.046..0.141 rows=3.20 loops=164)
                                      Index Cond: ((collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)) AND (station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (product_key = 1))
                                      Index Searches: 9412
                                      Buffers: shared hit=28760
                                ->  Index Scan using fct_price_observation_2024q4_pkey on fct_price_observation_2024q4 f_8  (cost=0.42..9.18 rows=2 width=18) (actual time=0.050..0.150 rows=3.86 loops=198)
                                      Index Cond: ((collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)) AND (station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (product_key = 1))
                                      Index Searches: 12862
                                      Buffers: shared hit=39351
                                ->  Index Scan using fct_price_observation_2025q1_pkey on fct_price_observation_2025q1 f_9  (cost=0.42..8.35 rows=2 width=18) (actual time=0.048..0.151 rows=4.19 loops=211)
                                      Index Cond: ((collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)) AND (station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (product_key = 1))
                                      Index Searches: 14431
                                      Buffers: shared hit=44180
                                ->  Index Scan using fct_price_observation_2025q2_pkey on fct_price_observation_2025q2 f_10  (cost=0.42..9.28 rows=2 width=18) (actual time=0.042..0.179 rows=4.84 loops=145)
                                      Index Cond: ((collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)) AND (station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (product_key = 1))
                                      Index Searches: 10499
                                      Buffers: shared hit=32247
                                ->  Index Scan using fct_price_observation_2025q3_pkey on fct_price_observation_2025q3 f_11  (cost=0.42..8.96 rows=2 width=18) (actual time=0.067..0.113 rows=1.33 loops=46)
                                      Index Cond: ((collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)) AND (station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (product_key = 1))
                                      Index Searches: 1591
                                      Buffers: shared hit=4834
                                ->  Index Scan using fct_price_observation_2025q4_pkey on fct_price_observation_2025q4 f_12  (cost=0.42..9.15 rows=2 width=18) (never executed)
                                      Index Cond: ((collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)) AND (station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (product_key = 1))
                                      Index Searches: 0
                                ->  Index Scan using fct_price_observation_2026q1_pkey on fct_price_observation_2026q1 f_13  (cost=0.42..8.35 rows=2 width=18) (never executed)
                                      Index Cond: ((collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)) AND (station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (product_key = 1))
                                      Index Searches: 0
                                ->  Index Scan using fct_price_observation_2026q2_pkey on fct_price_observation_2026q2 f_14  (cost=0.42..9.30 rows=2 width=18) (never executed)
                                      Index Cond: ((collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)) AND (station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (product_key = 1))
                                      Index Searches: 0
                                ->  Seq Scan on fct_price_observation_2026q3 f_15  (cost=0.00..0.00 rows=1 width=26) (never executed)
                                      Filter: ((product_key = 1) AND ((station_key = prev.station_key) OR (station_key = curr.station_key)) AND (collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)))
                                ->  Seq Scan on fct_price_observation_2026q4 f_16  (cost=0.00..0.00 rows=1 width=26) (never executed)
                                      Filter: ((product_key = 1) AND ((station_key = prev.station_key) OR (station_key = curr.station_key)) AND (collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)))
                                ->  Seq Scan on fct_price_observation_default f_17  (cost=0.00..0.00 rows=1 width=26) (never executed)
                                      Filter: ((product_key = 1) AND ((station_key = prev.station_key) OR (station_key = curr.station_key)) AND (collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)))
                    ->  Index Scan using dim_station_pkey on dim_station s  (cost=0.29..0.31 rows=1 width=12) (actual time=0.001..0.001 rows=1.00 loops=4102)
                          Index Cond: (station_key = f.station_key)
                          Index Searches: 4102
                          Buffers: shared hit=12306
Planning:
  Buffers: shared hit=46
Planning Time: 4.585 ms
Execution Time: 253.759 ms
```

</details>

<details><summary><code>04_evento_troca_bandeira</code> — <code>btree_posto_data</code></summary>

```
Aggregate  (cost=1444.88..1444.90 rows=1 width=88) (actual time=100.158..100.176 rows=1.00 loops=1)
  Buffers: shared hit=121816
  ->  GroupAggregate  (cost=1444.26..1444.84 rows=1 width=99) (actual time=98.562..100.021 rows=213.00 loops=1)
        Group Key: curr.cnpj, s.city_key
        Filter: ((count(*) FILTER (WHERE (CASE WHEN (f.collection_date < curr.valid_from) THEN 'antes'::text ELSE 'depois'::text END = 'antes'::text)) >= 4) AND (count(*) FILTER (WHERE (CASE WHEN (f.collection_date < curr.valid_from) THEN 'antes'::text ELSE 'depois'::text END = 'depois'::text)) >= 4))
        Rows Removed by Filter: 254
        Buffers: shared hit=121816
        ->  Sort  (cost=1444.26..1444.29 rows=10 width=33) (actual time=98.537..98.718 rows=4102.00 loops=1)
              Sort Key: curr.cnpj, s.city_key
              Sort Method: quicksort  Memory: 417kB
              Buffers: shared hit=121816
              ->  Nested Loop  (cost=543.51..1444.10 rows=10 width=33) (actual time=68.961..97.096 rows=4102.00 loops=1)
                    Buffers: shared hit=121816
                    ->  Nested Loop  (cost=543.22..1441.02 rows=10 width=37) (actual time=68.951..91.580 rows=4102.00 loops=1)
                          Buffers: shared hit=109510
                          ->  Hash Join  (cost=542.80..1401.58 rows=1 width=35) (actual time=68.895..77.823 rows=476.00 loops=1)
                                Hash Cond: ((prev.cnpj = curr.cnpj) AND (prev.valid_to = curr.valid_from) AND (prev.brand_key = b_prev.brand_key))
                                Join Filter: (prev.brand_key <> curr.brand_key)
                                Buffers: shared hit=99640
                                ->  Seq Scan on dim_station prev  (cost=0.00..594.31 rows=17631 width=31) (actual time=0.013..1.383 rows=17631.00 loops=1)
                                      Buffers: shared hit=418
                                ->  Hash  (cost=522.37..522.37 rows=1167 width=35) (actual time=68.816..68.822 rows=101035.00 loops=1)
                                      Buckets: 131072 (originally 2048)  Batches: 1 (originally 1)  Memory Usage: 7734kB
                                      Buffers: shared hit=99222
                                      ->  Nested Loop  (cost=0.29..522.37 rows=1167 width=35) (actual time=0.059..47.547 rows=101035.00 loops=1)
                                            Buffers: shared hit=99222
                                            ->  Nested Loop  (cost=0.00..42.16 rows=13 width=8) (actual time=0.036..0.483 rows=55.00 loops=1)
                                                  Join Filter: (CASE WHEN (b_prev.is_unbranded AND (NOT b_curr.is_unbranded)) THEN 'bandeiramento'::text WHEN ((NOT b_prev.is_unbranded) AND b_curr.is_unbranded) THEN 'desbandeiramento'::text ELSE 'troca de distribuidora'::text END = 'desbandeiramento'::text)
                                                  Rows Removed by Join Filter: 3081
                                                  Buffers: shared hit=2
                                                  ->  Seq Scan on dim_brand b_prev  (cost=0.00..1.51 rows=51 width=5) (actual time=0.007..0.024 rows=56.00 loops=1)
                                                        Buffers: shared hit=1
                                                  ->  Materialize  (cost=0.00..1.77 rows=51 width=5) (actual time=0.000..0.003 rows=56.00 loops=56)
                                                        Storage: Memory  Maximum Storage: 18kB
                                                        Buffers: shared hit=1
                                                        ->  Seq Scan on dim_brand b_curr  (cost=0.00..1.51 rows=51 width=5) (actual time=0.006..0.011 rows=56.00 loops=1)
                                                              Buffers: shared hit=1
                                            ->  Index Scan using dim_station_brand_idx on dim_station curr  (cost=0.29..36.12 rows=82 width=31) (actual time=0.006..0.586 rows=1837.00 loops=55)
                                                  Index Cond: ((brand_key = b_curr.brand_key) AND (valid_from >= '2024-01-01'::date) AND (valid_from < '2025-07-01'::date))
                                                  Index Searches: 55
                                                  Buffers: shared hit=99220
                          ->  Append  (cost=0.42..39.13 rows=31 width=18) (actual time=0.007..0.027 rows=8.62 loops=476)
                                Buffers: shared hit=9870
                                ->  Index Scan using fct_price_observation_2023q1_station_key_collection_date_idx on fct_price_observation_2023q1 f_1  (cost=0.42..2.66 rows=2 width=18) (never executed)
                                      Index Cond: ((station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)))
                                      Filter: (product_key = 1)
                                      Index Searches: 0
                                ->  Index Scan using fct_price_observation_2023q2_station_key_collection_date_idx on fct_price_observation_2023q2 f_2  (cost=0.42..2.89 rows=2 width=18) (never executed)
                                      Index Cond: ((station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)))
                                      Filter: (product_key = 1)
                                      Index Searches: 0
                                ->  Index Scan using fct_price_observation_2023q3_station_key_collection_date_idx on fct_price_observation_2023q3 f_3  (cost=0.42..2.95 rows=2 width=18) (never executed)
                                      Index Cond: ((station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)))
                                      Filter: (product_key = 1)
                                      Index Searches: 0
                                ->  Index Scan using fct_price_observation_2023q4_station_key_collection_date_idx on fct_price_observation_2023q4 f_4  (cost=0.42..2.96 rows=2 width=18) (actual time=0.005..0.007 rows=1.49 loops=41)
                                      Index Cond: ((station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)))
                                      Filter: (product_key = 1)
                                      Rows Removed by Filter: 4
                                      Index Searches: 71
                                      Buffers: shared hit=279
                                ->  Index Scan using fct_price_observation_2024q1_station_key_collection_date_idx on fct_price_observation_2024q1 f_5  (cost=0.42..2.97 rows=2 width=18) (actual time=0.005..0.012 rows=4.35 loops=109)
                                      Index Cond: ((station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)))
                                      Filter: (product_key = 1)
                                      Rows Removed by Filter: 12
                                      Index Searches: 193
                                      Buffers: shared hit=1072
                                ->  Index Scan using fct_price_observation_2024q2_station_key_collection_date_idx on fct_price_observation_2024q2 f_6  (cost=0.42..2.95 rows=2 width=18) (actual time=0.005..0.012 rows=4.41 loops=143)
                                      Index Cond: ((station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)))
                                      Filter: (product_key = 1)
                                      Rows Removed by Filter: 12
                                      Index Searches: 252
                                      Buffers: shared hit=1423
                                ->  Index Scan using fct_price_observation_2024q3_station_key_collection_date_idx on fct_price_observation_2024q3 f_7  (cost=0.42..2.80 rows=2 width=18) (actual time=0.005..0.011 rows=3.20 loops=164)
                                      Index Cond: ((station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)))
                                      Filter: (product_key = 1)
                                      Rows Removed by Filter: 9
                                      Index Searches: 286
                                      Buffers: shared hit=1400
                                ->  Index Scan using fct_price_observation_2024q4_station_key_collection_date_idx on fct_price_observation_2024q4 f_8  (cost=0.42..2.66 rows=2 width=18) (actual time=0.005..0.011 rows=3.86 loops=198)
                                      Index Cond: ((station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)))
                                      Filter: (product_key = 1)
                                      Rows Removed by Filter: 11
                                      Index Searches: 346
                                      Buffers: shared hit=1826
                                ->  Index Scan using fct_price_observation_2025q1_station_key_collection_date_idx on fct_price_observation_2025q1 f_9  (cost=0.42..2.72 rows=2 width=18) (actual time=0.005..0.011 rows=4.19 loops=211)
                                      Index Cond: ((station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)))
                                      Filter: (product_key = 1)
                                      Rows Removed by Filter: 12
                                      Index Searches: 373
                                      Buffers: shared hit=2044
                                ->  Index Scan using fct_price_observation_2025q2_station_key_collection_date_idx on fct_price_observation_2025q2 f_10  (cost=0.42..2.78 rows=2 width=18) (actual time=0.005..0.013 rows=4.84 loops=145)
                                      Index Cond: ((station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)))
                                      Filter: (product_key = 1)
                                      Rows Removed by Filter: 14
                                      Index Searches: 259
                                      Buffers: shared hit=1521
                                ->  Index Scan using fct_price_observation_2025q3_station_key_collection_date_idx on fct_price_observation_2025q3 f_11  (cost=0.42..2.50 rows=2 width=18) (actual time=0.007..0.008 rows=1.33 loops=46)
                                      Index Cond: ((station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)))
                                      Filter: (product_key = 1)
                                      Rows Removed by Filter: 4
                                      Index Searches: 80
                                      Buffers: shared hit=305
                                ->  Index Scan using fct_price_observation_2025q4_station_key_collection_date_idx on fct_price_observation_2025q4 f_12  (cost=0.42..2.64 rows=2 width=18) (never executed)
                                      Index Cond: ((station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)))
                                      Filter: (product_key = 1)
                                      Index Searches: 0
                                ->  Index Scan using fct_price_observation_2026q1_station_key_collection_date_idx on fct_price_observation_2026q1 f_13  (cost=0.42..2.72 rows=2 width=18) (never executed)
                                      Index Cond: ((station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)))
                                      Filter: (product_key = 1)
                                      Index Searches: 0
                                ->  Index Scan using fct_price_observation_2026q2_station_key_collection_date_idx on fct_price_observation_2026q2 f_14  (cost=0.42..2.77 rows=2 width=18) (never executed)
                                      Index Cond: ((station_key = ANY (ARRAY[prev.station_key, curr.station_key])) AND (collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)))
                                      Filter: (product_key = 1)
                                      Index Searches: 0
                                ->  Seq Scan on fct_price_observation_2026q3 f_15  (cost=0.00..0.00 rows=1 width=26) (never executed)
                                      Filter: ((product_key = 1) AND ((station_key = prev.station_key) OR (station_key = curr.station_key)) AND (collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)))
                                ->  Seq Scan on fct_price_observation_2026q4 f_16  (cost=0.00..0.00 rows=1 width=26) (never executed)
                                      Filter: ((product_key = 1) AND ((station_key = prev.station_key) OR (station_key = curr.station_key)) AND (collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)))
                                ->  Seq Scan on fct_price_observation_default f_17  (cost=0.00..0.00 rows=1 width=26) (never executed)
                                      Filter: ((product_key = 1) AND ((station_key = prev.station_key) OR (station_key = curr.station_key)) AND (collection_date >= (curr.valid_from - '56 days'::interval)) AND (collection_date < (curr.valid_from + '56 days'::interval)))
                    ->  Index Scan using dim_station_pkey on dim_station s  (cost=0.29..0.31 rows=1 width=12) (actual time=0.001..0.001 rows=1.00 loops=4102)
                          Index Cond: (station_key = f.station_key)
                          Index Searches: 4102
                          Buffers: shared hit=12306
Planning:
  Buffers: shared hit=46
Planning Time: 5.744 ms
Execution Time: 100.455 ms
```

</details>

---

## Conclusão

Quatro consultas medidas em quatro cenários de índice e quatro níveis de memória
de trabalho. O resumo:

| Intervenção | Efeito medido | Custo | Decisão |
|---|---|---|---|
| BRIN em `collection_date` | nulo | 0,4 MB | Rejeitado |
| B-tree `(product_key, collection_date)` | 4-5% em duas consultas, −18% numa terceira | 91,5 MB | Rejeitado |
| B-tree `(station_key, collection_date)` | 2,15x na análise de evento | 46,2 MB | Aceito |
| `work_mem` de 4MB para 16MB | 7-9%, elimina ordenação em disco | nenhum | Aceito |

### Por que quase nada funcionou

O plano do cenário sem índice mostra onde o tempo é gasto na consulta 01: o
`Append` que lê as três partições relevantes consome 70 ms dos 452 ms totais. Os
outros 380 ms são ordenação de 212 mil linhas, junções em hash e cálculo de
percentil.

Índice serve para localizar linhas. Nestas consultas, localizar já era barato —
o descarte de partições resolve o recorte temporal antes de qualquer índice
entrar em jogo, e o filtro por produto elimina pouco, já que os seis produtos têm
volumes da mesma ordem. O trabalho caro é agregar as linhas encontradas, e isso
nenhum índice reduz.

O B-tree por produto ilustra bem o ponto: ele **é** usado pelo planejador, que
troca `Seq Scan` por `Bitmap Heap Scan` e reduz a leitura de 70 ms para 55 ms.
Ganho real, na parte errada do problema, ao custo de 18% do orçamento de
armazenamento.

### Por que o BRIN não tinha chance

A rejeição do BRIN é estrutural, não de desempenho. Ele resolve o mesmo problema
que o particionamento por intervalo de data — restringir a leitura a um recorte
temporal — e o particionamento age antes, durante o planejamento, descartando
partições inteiras. Restou ao BRIN operar sobre dados que já haviam sido
recortados. Os planos dos dois cenários são idênticos.

Isso não desqualifica o BRIN: numa tabela grande e não particionada, com a mesma
correlação física entre a coluna e a ordem das páginas, o resultado seria outro.
A conclusão é sobre a combinação, não sobre o índice.

### Por que o índice por posto funcionou

É o único candidato que atende um padrão de acesso que a chave primária não
serve. `(collection_date, station_key, product_key)` responde bem a "quais
observações neste período"; a análise de evento pergunta "quais observações
destes postos, cada um na sua janela". Sem o índice, o planejador percorre treze
partições com laços de `Index Scan` na chave primária, um por evento.

### Por que a memória importou pouco

Os planos mostravam ordenação em disco — `external merge Disk: 8760kB` — e
agregação em nove lotes, sinais clássicos de `work_mem` insuficiente. Eliminar o
transbordo custou nada e rendeu 9%. A hipótese de que ali estava o gargalo não se
sustentou: a partir de 16MB tudo cabe em memória, e 64MB e 256MB não trazem ganho
adicional nenhum.

### O que isso significa para o modelo

Para agregação analítica sobre três milhões de linhas já particionadas, o retorno
de índice secundário é baixo, e a intuição de indexar as colunas de filtro mais
comuns teria custado 91,5 MB por 5%. O ganho relevante veio de um padrão de
acesso específico, identificado por medição e não por regra geral.

Os números favoreceriam mais o indexamento numa tabela maior, com filtros mais
seletivos, ou com consultas que retornassem poucas linhas em vez de agregar
muitas. A conclusão vale para este modelo neste volume, e a medição é
reproduzível por `src/benchmark.py`.
