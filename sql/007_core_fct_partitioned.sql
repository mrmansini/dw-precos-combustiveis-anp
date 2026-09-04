-- =============================================================================
-- 007_core_fct_partitioned.sql
-- Fato particionado por trimestre.
--
-- IMPORTANTE: esta migração cria o fato com a PK e NADA MAIS. Os índices
-- secundários ficam na 008, deliberadamente, para que docs/performance.md possa
-- mostrar EXPLAIN (ANALYZE, BUFFERS) da mesma consulta antes e depois — incluindo
-- a comparação entre BRIN e B-tree em collection_date, que numa tabela carregada
-- em ordem cronológica não é óbvia a priori.
--
-- =============================================================================

CREATE TABLE IF NOT EXISTS core.fct_price_observation (
    collection_date  date         NOT NULL REFERENCES core.dim_date (full_date),
    station_key      bigint       NOT NULL REFERENCES core.dim_station (station_key),
    product_key      smallint     NOT NULL REFERENCES core.dim_product (product_key),
    sale_price       numeric(8,3) NOT NULL,
    source_file_id   integer      NOT NULL REFERENCES etl.source_files (source_file_id),

    CONSTRAINT fct_price_positive CHECK (sale_price > 0),

    -- Grão validado por medição: zero duplicatas de cnpj+produto por dia nos dois
    -- arquivos perfilados. A data precisa entrar na PK porque é a chave de partição.
    PRIMARY KEY (collection_date, station_key, product_key)
) PARTITION BY RANGE (collection_date);

COMMENT ON TABLE core.fct_price_observation IS
    'Uma linha por posto, produto e dia de coleta. Preço de venda apenas: '
    'valor_de_compra vem 100% vazio na fonte desde pelo menos 2023.';

COMMENT ON COLUMN core.fct_price_observation.collection_date IS
    'Chave de partição e FK para dim_date.full_date. Não há date_key inteiro no '
    'fato: seria a mesma informação repetida em ~2,9 milhões de linhas, e a chave '
    'de partição tem de ser a data de qualquer forma.';

-- Bandeira e município NÃO estão no fato de propósito: eles são atributos da
-- versão do posto e vivem em dim_station, que já os carrega na vigência correta.
-- Duplicá-los aqui criaria duas fontes de verdade para o mesmo atributo e
-- desmontaria a razão de existir do SCD2.

-- -----------------------------------------------------------------------------
-- Partições trimestrais, 2023Q1 a 2026Q4
-- -----------------------------------------------------------------------------

DO $$
DECLARE
    d          date := DATE '2023-01-01';
    part_name  text;
BEGIN
    WHILE d < DATE '2027-01-01' LOOP
        part_name := format('fct_price_observation_%sq%s',
                            EXTRACT(year FROM d)::int,
                            EXTRACT(quarter FROM d)::int);

        EXECUTE format(
            'CREATE TABLE IF NOT EXISTS core.%I
                 PARTITION OF core.fct_price_observation
                 FOR VALUES FROM (%L) TO (%L)',
            part_name, d, (d + interval '3 months')::date
        );

        d := (d + interval '3 months')::date;
    END LOOP;
END $$;

-- Partição DEFAULT: rede de segurança para data fora da janela. Deve permanecer
-- vazia — linha aqui é erro de dado, não dado novo. Custo assumido: com DEFAULT
-- não vazia, criar partição nova exige varrer a default para validar. Por isso a
-- view de monitoramento logo abaixo.
CREATE TABLE IF NOT EXISTS core.fct_price_observation_default
    PARTITION OF core.fct_price_observation DEFAULT;

CREATE OR REPLACE VIEW ops.v_partition_health AS
SELECT
    c.relname                                        AS partition_name,
    pg_get_expr(c.relpartbound, c.oid)               AS bounds,
    c.reltuples::bigint                              AS estimated_rows,
    pg_size_pretty(pg_total_relation_size(c.oid))    AS total_size,
    c.relname = 'fct_price_observation_default'
        AND c.reltuples > 0                          AS is_anomaly
FROM pg_class c
JOIN pg_inherits i ON i.inhrelid = c.oid
JOIN pg_class p    ON p.oid = i.inhparent
JOIN pg_namespace n ON n.oid = p.relnamespace
WHERE p.relname = 'fct_price_observation' AND n.nspname = 'core'
ORDER BY c.relname;

COMMENT ON VIEW ops.v_partition_health IS
    'Tamanho e volume por partição, mais a flag de anomalia quando a partição '
    'DEFAULT tem linha. Também é a consulta para decidir qual trimestre antigo '
    'derrubar se o espaço do plano gratuito apertar — ciclo de vida do dado, '
    'não só performance.';
