-- =============================================================================
-- 03_paridade_etanol_gasolina.sql
--
-- Pergunta: em quais municípios e meses o etanol compensou? A regra prática de
-- mercado é a dos 70%: abaixo dessa razão o etanol tende a compensar, acima dela
-- a gasolina leva vantagem, porque o etanol rende menos por litro.
--
-- Só entram município e mês com os dois produtos presentes; comparar um mercado
-- que só publicou um dos combustíveis produziria paridade sem contraparte.
--
-- Padrão de acesso: filtro por dois produtos e faixa de data, dupla agregação,
-- pivô por FILTER.
-- =============================================================================

WITH preco_mensal AS (
    SELECT
        s.city_key,
        d.month_start_date,
        f.product_key,
        avg(f.sale_price)             AS preco_medio,
        count(DISTINCT f.station_key) AS postos
    FROM core.fct_price_observation f
    JOIN core.dim_date    d ON d.full_date   = f.collection_date
    JOIN core.dim_station s ON s.station_key = f.station_key
    WHERE f.product_key IN (1, 3)          -- 1 = gasolina comum, 3 = etanol
      AND f.collection_date >= DATE '2024-01-01'
    GROUP BY s.city_key, d.month_start_date, f.product_key
)
SELECT
    c.uf,
    c.city_name,
    p.month_start_date,
    round(max(preco_medio) FILTER (WHERE product_key = 3)::numeric, 3) AS etanol,
    round(max(preco_medio) FILTER (WHERE product_key = 1)::numeric, 3) AS gasolina,
    round((max(preco_medio) FILTER (WHERE product_key = 3)
         / max(preco_medio) FILTER (WHERE product_key = 1))::numeric, 4) AS paridade,
    (max(preco_medio) FILTER (WHERE product_key = 3)
   / max(preco_medio) FILTER (WHERE product_key = 1)) < 0.70 AS etanol_compensa
FROM preco_mensal p
JOIN core.dim_city c ON c.city_key = p.city_key
GROUP BY c.uf, c.city_name, p.month_start_date
HAVING count(*) = 2
ORDER BY p.month_start_date, c.uf, c.city_name;
