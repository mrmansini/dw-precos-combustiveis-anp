-- =============================================================================
-- 04_evento_troca_bandeira.sql
--
-- Pergunta: o que acontece com o preço quando um posto larga a bandeira?
--
-- Esta é a consulta que justifica o SCD Tipo 2. Ela só é possível porque
-- core.dim_station guarda a bandeira vigente em cada intervalo, o que permite
-- localizar o instante da troca e separar as observações anteriores das
-- posteriores usando as duas versões do mesmo CNPJ.
--
-- Compara o posto com ele mesmo, oito semanas antes e oito depois, e traz o
-- movimento do próprio município no mesmo período como controle — sem ele,
-- qualquer variação de mercado seria atribuída ao evento.
--
-- Padrão de acesso: filtro por conjunto de station_key e faixas de data
-- deslocadas por evento. É o padrão mais distante da chave primária, que começa
-- por collection_date.
-- =============================================================================

WITH eventos AS (
    SELECT
        cnpj,
        station_key_before,
        station_key_after,
        changed_on,
        change_type
    FROM core.v_brand_changes
    WHERE change_type = 'desbandeiramento'
      AND changed_on >= DATE '2024-01-01'
      AND changed_on <  DATE '2025-07-01'
),
observacoes AS (
    SELECT
        e.cnpj,
        e.changed_on,
        CASE WHEN f.collection_date < e.changed_on THEN 'antes' ELSE 'depois' END AS fase,
        s.city_key,
        f.collection_date,
        f.sale_price
    FROM eventos e
    JOIN core.fct_price_observation f
      ON  f.station_key IN (e.station_key_before, e.station_key_after)
      AND f.collection_date >= e.changed_on - INTERVAL '56 days'
      AND f.collection_date <  e.changed_on + INTERVAL '56 days'
    JOIN core.dim_station s ON s.station_key = f.station_key
    WHERE f.product_key = 1
),
por_posto AS (
    SELECT
        cnpj,
        city_key,
        avg(sale_price) FILTER (WHERE fase = 'antes')  AS preco_antes,
        avg(sale_price) FILTER (WHERE fase = 'depois') AS preco_depois,
        count(*) FILTER (WHERE fase = 'antes')         AS obs_antes,
        count(*) FILTER (WHERE fase = 'depois')        AS obs_depois
    FROM observacoes
    GROUP BY cnpj, city_key
)
SELECT
    count(*)                                                   AS postos,
    round(avg(preco_depois - preco_antes)::numeric, 4)         AS variacao_media,
    round((percentile_cont(0.5) WITHIN GROUP
            (ORDER BY preco_depois - preco_antes))::numeric, 4) AS variacao_mediana,
    count(*) FILTER (WHERE preco_depois < preco_antes)         AS baixaram,
    count(*) FILTER (WHERE preco_depois > preco_antes)         AS subiram
FROM por_posto
WHERE obs_antes >= 4 AND obs_depois >= 4;
