# Modelo de dados completo

Todas as tabelas com chave estrangeira, nas cinco camadas. O núcleo dimensional
sozinho está no [README](../README.md#modelo-de-dados).

Não aparecem aqui, por não terem chave estrangeira: as views de `analytics`
(série semanal, dispersão, paridade, efeito de bandeira, cobertura), as views de
saúde em `ops`, e as dezessete partições do fato, que são objetos físicos da
mesma tabela.

```mermaid
erDiagram
  ETL_SOURCE_FILES ||--o{ STAGING_STG_PRICE_SURVEY : "alimenta"
  ETL_SOURCE_FILES ||--o{ CORE_FCT_PRICE_OBSERVATION : "origem"
  ETL_SOURCE_FILES ||--o{ OPS_LOAD_RUNS : "registra"
  CORE_DIM_DATE ||--o{ CORE_FCT_PRICE_OBSERVATION : "data da coleta"
  CORE_DIM_PRODUCT ||--o{ CORE_FCT_PRICE_OBSERVATION : "produto"
  CORE_DIM_STATION ||--o{ CORE_FCT_PRICE_OBSERVATION : "versao vigente"
  CORE_DIM_BRAND ||--o{ CORE_DIM_STATION : "bandeira"
  CORE_DIM_CITY ||--o{ CORE_DIM_STATION : "municipio"
  CORE_DIM_BRAND ||--o{ CORE_BRAND_ALIAS : "grafias da fonte"
  CORE_FCT_PRICE_OBSERVATION ||--o{ ANALYTICS_MV_WEEKLY_PRICE : "agrega"
  ETL_SOURCE_FILES {
    int source_file_id PK
    text semester_label UK
    text file_encoding "governa a leitura"
    date period_start
    date period_end
    text status
  }
  STAGING_STG_PRICE_SURVEY {
    int source_file_id PK,FK
    int line_number PK
    text cnpj_da_revenda "tudo texto"
    text produto
    text data_da_coleta
    text valor_de_venda
  }
  CORE_DIM_STATION {
    bigint station_key PK
    char cnpj "chave natural"
    text legal_name
    int brand_key FK
    int city_key FK
    date valid_from "SCD tipo 2"
    date valid_to "infinity se vigente"
    boolean is_current
    uuid attribute_hash "coluna gerada"
  }
  CORE_DIM_BRAND {
    int brand_key PK
    text brand_name UK
    boolean is_unbranded "BRANCA"
    boolean needs_review
  }
  CORE_BRAND_ALIAS {
    text alias_text PK
    int brand_key FK
    boolean is_rename "rotulo, nao identidade"
  }
  CORE_DIM_CITY {
    int city_key PK
    text city_name
    char uf
    char region
  }
  CORE_DIM_DATE {
    int date_key PK
    date full_date UK
    int survey_week_key "grao analitico"
    date week_start_date
    smallint iso_year
  }
  CORE_DIM_PRODUCT {
    smallint product_key PK
    text source_product_name UK
    text product_name
    text unit_of_measure "litro ou m3"
  }
  CORE_FCT_PRICE_OBSERVATION {
    date collection_date PK,FK "chave de particao"
    bigint station_key PK,FK
    smallint product_key PK,FK
    numeric sale_price
    int source_file_id FK
  }
  ANALYTICS_MV_WEEKLY_PRICE {
    int survey_week_key PK
    int city_key PK,FK
    smallint product_key PK,FK
    int stations
    numeric median_price
    numeric p10_price
    numeric p90_price
  }
  OPS_LOAD_RUNS {
    bigint run_id PK
    int source_file_id FK
    text step
    text status
    int rows_out
  }
```

## Como ler

**O catálogo alcança as três pontas.** `etl.source_files` liga-se à staging, ao
fato e ao registro de execuções. É por isso que rastrear uma observação até o
arquivo que a trouxe, com o encoding e o layout usados na leitura, é uma consulta
e não uma investigação.

**`brand_alias` pendura em `dim_brand`, não em `dim_station`.** A normalização de
grafia acontece uma vez, no catálogo. Se estivesse na dimensão de postos, cada
carga precisaria reaplicá-la, e duas grafias da mesma empresa abririam versões
distintas no SCD Tipo 2.

**A staging referencia o catálogo, não o contrário.** A tabela bruta é truncada a
cada arquivo; o catálogo permanece. A chave primária composta de arquivo e número
de linha é o que permite apontar uma rejeição para a linha exata do CSV.

**`mv_weekly_price` deriva do fato sem chave estrangeira formal.** A ligação no
diagrama registra a dependência lógica: ela agrega o fato por semana, município e
produto, e o município vem da versão do posto vigente na data da observação, não
da atual.
