-- =============================================================================
-- 011_analytics.sql
-- Camada de consumo. As regras vivem aqui, versionadas; o BI não reimplementa
-- nenhuma delas.
--
-- Duas escolhas atravessam o arquivo:
--
-- 1. A agregação é sempre por SEMANA DE PESQUISA, nunca por data de coleta. Cada
--    posto é pesquisado no máximo uma vez por semana e a data é apenas quando o
--    pesquisador passou; a distribuição por dia da semana muda entre os arquivos.
--    Série por data crua capta mudança de rota de coleta, não de preço.
--
-- 2. Preço central é MEDIANA, não média. A distribuição de preços num mesmo
--    mercado é assimétrica à direita — poucos postos muito caros puxam a média e
--    não deslocam a mediana.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Rollup semanal materializado
--
-- Grão: semana da pesquisa, município e produto. Todas as views seguintes leem
-- daqui em vez do fato, o que troca a leitura de milhões de linhas por dezenas
-- de milhares.
--
-- O município vem da versão do posto vigente na data da observação, não da
-- versão corrente: um posto que mudou de endereço contribui para o município em
-- que estava à época.
-- -----------------------------------------------------------------------------

DROP MATERIALIZED VIEW IF EXISTS analytics.mv_weekly_price CASCADE;

CREATE MATERIALIZED VIEW analytics.mv_weekly_price AS
SELECT
    d.survey_week_key,
    min(d.week_start_date)                                            AS week_start_date,
    min(d.iso_year)::smallint                                         AS iso_year,
    -- A semana ISO atravessa a virada do mês, então o mês não é função da
    -- semana: agrupar pelos dois produziria duas linhas para a mesma semana.
    -- Regra declarada: a semana pertence ao mês da sua segunda-feira.
    date_trunc('month', min(d.week_start_date))::date                 AS month_start_date,
    s.city_key,
    f.product_key,
    count(*)                                                          AS observations,
    count(DISTINCT f.station_key)                                     AS stations,
    (percentile_cont(0.1) WITHIN GROUP (ORDER BY f.sale_price))::numeric(8,3) AS p10_price,
    (percentile_cont(0.5) WITHIN GROUP (ORDER BY f.sale_price))::numeric(8,3) AS median_price,
    (percentile_cont(0.9) WITHIN GROUP (ORDER BY f.sale_price))::numeric(8,3) AS p90_price,
    min(f.sale_price)                                                 AS min_price,
    max(f.sale_price)                                                 AS max_price,
    (avg(f.sale_price))::numeric(8,3)                                 AS avg_price
FROM core.fct_price_observation f
JOIN core.dim_date    d ON d.full_date   = f.collection_date
JOIN core.dim_station s ON s.station_key = f.station_key
GROUP BY d.survey_week_key, s.city_key, f.product_key;

COMMENT ON MATERIALIZED VIEW analytics.mv_weekly_price IS
    'Rollup semanal por município e produto. Base de todas as views analíticas.';

-- O índice único é exigência do REFRESH CONCURRENTLY, que evita bloquear
-- leituras durante a atualização.
CREATE UNIQUE INDEX mv_weekly_price_uidx
    ON analytics.mv_weekly_price (survey_week_key, city_key, product_key);

CREATE INDEX mv_weekly_price_product_week_idx
    ON analytics.mv_weekly_price (product_key, week_start_date);

-- -----------------------------------------------------------------------------
-- View achatada para BI
--
-- Uma linha por observação, com as dimensões já resolvidas. Existe para que a
-- ferramenta de BI não precise reconstruir os joins nem conhecer a mecânica do
-- SCD Tipo 2 — inclusive a resolução temporal, que é a parte fácil de errar.
--
-- São três milhões de linhas: usar sempre com filtro de período.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE VIEW analytics.v_price_observation AS
SELECT
    f.collection_date,
    d.survey_week_key,
    d.week_start_date,
    d.month_start_date,
    d.iso_year,
    p.product_name,
    p.fuel_family,
    p.unit_of_measure,
    c.region,
    c.uf,
    c.city_name,
    b.brand_name,
    b.is_unbranded,
    s.cnpj,
    s.legal_name,
    s.district,
    f.sale_price
FROM core.fct_price_observation f
JOIN core.dim_date    d ON d.full_date    = f.collection_date
JOIN core.dim_product p ON p.product_key  = f.product_key
JOIN core.dim_station s ON s.station_key  = f.station_key
JOIN core.dim_city    c ON c.city_key     = s.city_key
JOIN core.dim_brand   b ON b.brand_key    = s.brand_key;

COMMENT ON VIEW analytics.v_price_observation IS
    'Observação com dimensões resolvidas. Bandeira e município são os vigentes '
    'na data da coleta, não os atuais.';

-- -----------------------------------------------------------------------------
-- Série semanal por UF
-- -----------------------------------------------------------------------------

CREATE OR REPLACE VIEW analytics.v_weekly_price_by_uf AS
SELECT
    m.survey_week_key,
    m.week_start_date,
    c.region,
    c.uf,
    p.product_name,
    sum(m.observations)                                  AS observations,
    sum(m.stations)                                      AS stations,
    (sum(m.median_price * m.stations) / nullif(sum(m.stations), 0))::numeric(8,3)
                                                         AS median_price
FROM analytics.mv_weekly_price m
JOIN core.dim_city    c ON c.city_key    = m.city_key
JOIN core.dim_product p ON p.product_key = m.product_key
GROUP BY m.survey_week_key, m.week_start_date, c.region, c.uf, p.product_name;

COMMENT ON VIEW analytics.v_weekly_price_by_uf IS
    'Mediana municipal ponderada pelo número de postos. Não é a mediana da UF: '
    'agregar medianas não devolve a mediana do conjunto. É a medida disponível '
    'a partir do rollup, e a diferença é pequena quando as amostras municipais '
    'têm tamanhos parecidos.';

-- -----------------------------------------------------------------------------
-- Variação semana a semana
-- -----------------------------------------------------------------------------

CREATE OR REPLACE VIEW analytics.v_weekly_change AS
SELECT
    m.survey_week_key,
    m.week_start_date,
    c.uf,
    c.city_name,
    p.product_name,
    m.median_price,
    lag(m.median_price) OVER w                              AS previous_price,
    (m.median_price - lag(m.median_price) OVER w)::numeric(8,3) AS change_value,
    round(100 * (m.median_price / nullif(lag(m.median_price) OVER w, 0) - 1), 2)
                                                            AS change_pct,
    m.stations
FROM analytics.mv_weekly_price m
JOIN core.dim_city    c ON c.city_key    = m.city_key
JOIN core.dim_product p ON p.product_key = m.product_key
WINDOW w AS (PARTITION BY m.city_key, m.product_key ORDER BY m.survey_week_key);

-- -----------------------------------------------------------------------------
-- Dispersão dentro do município
--
-- Amplitude entre o percentil 90 e o 10 na mesma semana e município. O piso de
-- dez postos existe porque amplitude sobre amostra pequena mede ruído, não
-- concorrência.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE VIEW analytics.v_price_dispersion AS
SELECT
    m.survey_week_key,
    m.week_start_date,
    c.uf,
    c.city_name,
    p.product_name,
    m.p10_price,
    m.median_price,
    m.p90_price,
    (m.p90_price - m.p10_price)::numeric(8,3)                       AS spread_value,
    round(100 * (m.p90_price - m.p10_price) / nullif(m.median_price, 0), 2)
                                                                    AS spread_pct,
    m.stations
FROM analytics.mv_weekly_price m
JOIN core.dim_city    c ON c.city_key    = m.city_key
JOIN core.dim_product p ON p.product_key = m.product_key
WHERE m.stations >= 10;

-- -----------------------------------------------------------------------------
-- Paridade etanol/gasolina
--
-- A regra prática de mercado é a dos 70%: abaixo dessa razão o etanol tende a
-- compensar, porque rende menos por litro. Só entram semana e município com os
-- dois combustíveis presentes.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE VIEW analytics.v_ethanol_parity AS
SELECT
    m.survey_week_key,
    m.week_start_date,
    c.uf,
    c.city_name,
    max(m.median_price) FILTER (WHERE m.product_key = 3)            AS ethanol_price,
    max(m.median_price) FILTER (WHERE m.product_key = 1)            AS gasoline_price,
    round(max(m.median_price) FILTER (WHERE m.product_key = 3)
        / nullif(max(m.median_price) FILTER (WHERE m.product_key = 1), 0), 4)
                                                                    AS parity_ratio,
    (max(m.median_price) FILTER (WHERE m.product_key = 3)
   / nullif(max(m.median_price) FILTER (WHERE m.product_key = 1), 0)) < 0.70
                                                                    AS ethanol_wins,
    min(m.stations)                                                 AS min_stations
FROM analytics.mv_weekly_price m
JOIN core.dim_city c ON c.city_key = m.city_key
WHERE m.product_key IN (1, 3)
GROUP BY m.survey_week_key, m.week_start_date, c.uf, c.city_name
HAVING count(*) = 2;

-- -----------------------------------------------------------------------------
-- Efeito da troca de bandeira
--
-- A análise que justifica o SCD Tipo 2: só é possível porque core.dim_station
-- guarda a bandeira vigente em cada intervalo, o que permite localizar o instante
-- da troca e separar as observações anteriores das posteriores.
--
-- Compara o posto com ele mesmo em janelas de oito semanas, e traz a variação do
-- próprio município no mesmo período como controle — sem ele, qualquer movimento
-- geral de mercado seria atribuído ao evento.
--
-- É view, não tabela materializada: percorre o fato por conjunto de postos, o
-- que o índice da migração 010 atende. Filtre por change_type ou por período.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE VIEW analytics.v_brand_change_effect AS
WITH observations AS (
    SELECT
        e.cnpj,
        e.change_type,
        e.brand_before,
        e.brand_after,
        e.changed_on,
        st.city_key,
        f.product_key,
        CASE WHEN f.collection_date < e.changed_on THEN 'before' ELSE 'after' END AS phase,
        f.sale_price
    FROM core.v_brand_changes e
    JOIN core.fct_price_observation f
      ON  f.station_key IN (e.station_key_before, e.station_key_after)
      AND f.collection_date >= e.changed_on - INTERVAL '56 days'
      AND f.collection_date <  e.changed_on + INTERVAL '56 days'
    JOIN core.dim_station st ON st.station_key = f.station_key
),
per_station AS (
    SELECT
        cnpj, change_type, brand_before, brand_after, changed_on,
        city_key, product_key,
        avg(sale_price) FILTER (WHERE phase = 'before') AS price_before,
        avg(sale_price) FILTER (WHERE phase = 'after')  AS price_after,
        count(*)        FILTER (WHERE phase = 'before') AS obs_before,
        count(*)        FILTER (WHERE phase = 'after')  AS obs_after
    FROM observations
    GROUP BY cnpj, change_type, brand_before, brand_after, changed_on,
             city_key, product_key
)
SELECT
    s.cnpj,
    s.change_type,
    s.brand_before,
    s.brand_after,
    s.changed_on,
    c.uf,
    c.city_name,
    p.product_name,
    s.price_before::numeric(8,3),
    s.price_after::numeric(8,3),
    (s.price_after - s.price_before)::numeric(8,3)      AS station_change,
    (mkt.median_after - mkt.median_before)::numeric(8,3) AS market_change,
    ((s.price_after - s.price_before)
     - (mkt.median_after - mkt.median_before))::numeric(8,3) AS excess_change,
    s.obs_before,
    s.obs_after
FROM per_station s
JOIN core.dim_city    c ON c.city_key    = s.city_key
JOIN core.dim_product p ON p.product_key = s.product_key
LEFT JOIN LATERAL (
    SELECT
        avg(m.median_price) FILTER (
            WHERE m.week_start_date <  s.changed_on)  AS median_before,
        avg(m.median_price) FILTER (
            WHERE m.week_start_date >= s.changed_on)  AS median_after
    FROM analytics.mv_weekly_price m
    WHERE m.city_key     = s.city_key
      AND m.product_key  = s.product_key
      AND m.week_start_date >= s.changed_on - INTERVAL '56 days'
      AND m.week_start_date <  s.changed_on + INTERVAL '56 days'
) mkt ON true
WHERE s.obs_before >= 4 AND s.obs_after >= 4;

COMMENT ON VIEW analytics.v_brand_change_effect IS
    'excess_change é a variação do posto menos a do próprio município no mesmo '
    'período. É a coluna que isola o efeito do evento do movimento de mercado.';

-- -----------------------------------------------------------------------------
-- Cobertura da amostra
--
-- Deixa de ser diagnóstico e passa a ser pré-requisito: a amostra encolheu ao
-- longo da janela, e comparação plurianual que não controle isso mede
-- rotatividade de postos, não preço.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE VIEW analytics.v_sample_coverage AS
SELECT
    m.survey_week_key,
    m.week_start_date,
    p.product_name,
    count(DISTINCT m.city_key) AS cities,
    sum(m.stations)            AS stations,
    sum(m.observations)        AS observations
FROM analytics.mv_weekly_price m
JOIN core.dim_product p ON p.product_key = m.product_key
GROUP BY m.survey_week_key, m.week_start_date, p.product_name;

-- -----------------------------------------------------------------------------
-- Atualização
-- CONCURRENTLY não bloqueia leitura, ao custo de exigir o índice único e de ser
-- mais lento que a atualização comum.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION analytics.fn_refresh()
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_run_id bigint;
BEGIN
    INSERT INTO ops.load_runs (step) VALUES ('refresh') RETURNING run_id INTO v_run_id;

    REFRESH MATERIALIZED VIEW CONCURRENTLY analytics.mv_weekly_price;

    UPDATE ops.load_runs
       SET status = 'success', finished_at = now(),
           rows_out = (SELECT count(*) FROM analytics.mv_weekly_price)
     WHERE run_id = v_run_id;
END $$;

COMMENT ON FUNCTION analytics.fn_refresh IS
    'Atualiza o rollup semanal. Chamar após cada carga de semestre.';
