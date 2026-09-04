-- =============================================================================
-- 05_controle_placebo.sql
--
-- Pergunta: o efeito medido em analytics.v_brand_change_effect é do evento ou do
-- método?
--
-- A medição de desbandeiramento apontou variação de preço abaixo da do próprio
-- município. Só que o bandeiramento, que deveria apontar na direção oposta,
-- apontou na mesma. Isso é sintoma de viés no cálculo, não de mecanismo
-- econômico.
--
-- O teste: aplicar exatamente o mesmo cálculo a postos que NÃO trocaram de
-- bandeira, atribuindo a eles as datas dos eventos reais ocorridos no mesmo
-- município. Se o placebo produzir efeito parecido, o número da medição original
-- é artefato — provavelmente reversão à média, já que o posto entra no cálculo da
-- mediana municipal que serve de controle.
--
-- Posto estável é definido como CNPJ com uma única versão em dim_station: nunca
-- mudou bandeira, endereço nem razão social em toda a janela.
-- =============================================================================

WITH eventos AS (
    SELECT
        e.cnpj,
        e.changed_on,
        sa.city_key
    FROM core.v_brand_changes e
    JOIN core.dim_station sa ON sa.station_key = e.station_key_after
    WHERE e.change_type = 'desbandeiramento'
),
estaveis AS (
    SELECT
        cnpj,
        min(station_key) AS station_key,
        min(city_key)    AS city_key
    FROM core.dim_station
    GROUP BY cnpj
    HAVING count(*) = 1
),
pares AS (
    -- Cada evento real empresta sua data aos postos estáveis do mesmo município.
    SELECT
        ev.changed_on AS pseudo_date,
        es.station_key,
        es.cnpj,
        es.city_key
    FROM eventos ev
    JOIN estaveis es ON es.city_key = ev.city_key
),
observacoes AS (
    SELECT
        p.cnpj,
        p.pseudo_date,
        p.city_key,
        CASE WHEN f.collection_date < p.pseudo_date THEN 'before' ELSE 'after' END AS phase,
        f.sale_price
    FROM pares p
    JOIN core.fct_price_observation f
      ON  f.station_key = p.station_key
      AND f.collection_date >= p.pseudo_date - INTERVAL '56 days'
      AND f.collection_date <  p.pseudo_date + INTERVAL '56 days'
    WHERE f.product_key = 1
),
por_posto AS (
    SELECT
        cnpj,
        pseudo_date,
        city_key,
        avg(sale_price) FILTER (WHERE phase = 'before') AS price_before,
        avg(sale_price) FILTER (WHERE phase = 'after')  AS price_after,
        count(*)        FILTER (WHERE phase = 'before') AS obs_before,
        count(*)        FILTER (WHERE phase = 'after')  AS obs_after
    FROM observacoes
    GROUP BY cnpj, pseudo_date, city_key
),
com_controle AS (
    SELECT
        s.*,
        (s.price_after - s.price_before)
          - (mkt.median_after - mkt.median_before) AS excess_change
    FROM por_posto s
    LEFT JOIN LATERAL (
        SELECT
            avg(m.median_price) FILTER (
                WHERE m.week_start_date <  s.pseudo_date) AS median_before,
            avg(m.median_price) FILTER (
                WHERE m.week_start_date >= s.pseudo_date) AS median_after
        FROM analytics.mv_weekly_price m
        WHERE m.city_key    = s.city_key
          AND m.product_key = 1
          AND m.week_start_date >= s.pseudo_date - INTERVAL '56 days'
          AND m.week_start_date <  s.pseudo_date + INTERVAL '56 days'
    ) mkt ON true
    WHERE s.obs_before >= 4 AND s.obs_after >= 4
)
SELECT
    'placebo (postos estáveis)'                                    AS grupo,
    count(*)                                                       AS casos,
    round(avg(excess_change)::numeric, 4)                          AS efeito_medio,
    round((percentile_cont(0.5) WITHIN GROUP
            (ORDER BY excess_change))::numeric, 4)                 AS efeito_mediano,
    round(stddev_samp(excess_change)::numeric, 4)                  AS desvio_padrao,
    round((stddev_samp(excess_change) / sqrt(count(*)))::numeric, 4) AS erro_padrao,
    count(*) FILTER (WHERE excess_change < 0)                      AS abaixo_do_mercado,
    round(100.0 * count(*) FILTER (WHERE excess_change < 0) / count(*), 1) AS pct_abaixo
FROM com_controle

UNION ALL

SELECT
    'evento (' || change_type || ')',
    count(*),
    round(avg(excess_change)::numeric, 4),
    round((percentile_cont(0.5) WITHIN GROUP (ORDER BY excess_change))::numeric, 4),
    round(stddev_samp(excess_change)::numeric, 4),
    round((stddev_samp(excess_change) / sqrt(count(*)))::numeric, 4),
    count(*) FILTER (WHERE excess_change < 0),
    round(100.0 * count(*) FILTER (WHERE excess_change < 0) / count(*), 1)
FROM analytics.v_brand_change_effect
WHERE product_name = 'Gasolina comum'
GROUP BY change_type
ORDER BY 1;
