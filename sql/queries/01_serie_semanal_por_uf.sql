-- =============================================================================
-- 01_serie_semanal_por_uf.sql
--
-- Pergunta: como evoluiu o preço da gasolina comum em cada UF, semana a semana,
-- no último ano?
--
-- Agrega pela semana da pesquisa, não pela data de coleta: cada posto é
-- pesquisado no máximo uma vez por semana e a data é apenas quando o
-- pesquisador passou. Usa mediana em vez de média porque a distribuição de
-- preços num mesmo mercado é assimétrica à direita.
--
-- Padrão de acesso: filtro por produto e por faixa de data, agregação ampla.
-- =============================================================================

SELECT
    d.survey_week_key,
    d.week_start_date,
    c.uf,
    percentile_cont(0.5) WITHIN GROUP (ORDER BY f.sale_price) AS preco_mediano,
    count(*)                                                   AS observacoes,
    count(DISTINCT f.station_key)                              AS postos
FROM core.fct_price_observation f
JOIN core.dim_date    d ON d.full_date   = f.collection_date
JOIN core.dim_station s ON s.station_key = f.station_key
JOIN core.dim_city    c ON c.city_key    = s.city_key
WHERE f.product_key = 1
  AND f.collection_date >= DATE '2025-07-01'
GROUP BY d.survey_week_key, d.week_start_date, c.uf
ORDER BY d.survey_week_key, c.uf;
