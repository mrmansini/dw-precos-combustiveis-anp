-- =============================================================================
-- 02_dispersao_intramunicipal.sql
--
-- Pergunta: em quais municípios a diferença de preço entre postos é maior na
-- mesma semana? Amplitude alta com muitos postos pesquisados sugere concorrência
-- frouxa ou segmentação de mercado; amplitude baixa sugere alinhamento.
--
-- Exige pelo menos dez postos distintos na semana: amplitude calculada sobre
-- amostra pequena mede ruído, não dispersão de mercado.
--
-- Padrão de acesso: filtro por produto e ano, agregação por município e semana,
-- ordenação sobre o resultado agregado.
-- =============================================================================

SELECT
    c.uf,
    c.city_name,
    d.survey_week_key,
    round(percentile_cont(0.9) WITHIN GROUP (ORDER BY f.sale_price)::numeric, 3) AS p90,
    round(percentile_cont(0.1) WITHIN GROUP (ORDER BY f.sale_price)::numeric, 3) AS p10,
    round((percentile_cont(0.9) WITHIN GROUP (ORDER BY f.sale_price)
         - percentile_cont(0.1) WITHIN GROUP (ORDER BY f.sale_price))::numeric, 3)
        AS amplitude,
    count(DISTINCT f.station_key) AS postos
FROM core.fct_price_observation f
JOIN core.dim_date    d ON d.full_date   = f.collection_date
JOIN core.dim_station s ON s.station_key = f.station_key
JOIN core.dim_city    c ON c.city_key    = s.city_key
WHERE f.product_key = 1
  AND f.collection_date >= DATE '2025-01-01'
  AND f.collection_date <  DATE '2026-01-01'
GROUP BY c.uf, c.city_name, d.survey_week_key
HAVING count(DISTINCT f.station_key) >= 10
ORDER BY amplitude DESC
LIMIT 50;
