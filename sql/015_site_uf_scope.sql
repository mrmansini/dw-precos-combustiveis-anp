-- Aplica o escopo temporal tambem a serie por UF.
--
-- v_site_price_weekly_uf foi criada em 013 sem passar por v_site_week_scope, e
-- por isso o panorama calculava a manchete sobre 2026-06-29, a semana truncada
-- pelo fim do arquivo: 26 estados no lugar de 27, e preco medio de uma amostra
-- parcial. O mesmo defeito que 014 corrigiu na paridade.
--
-- A definicao e repetida aqui em vez de renomeada. 013 permanece intacta,
-- descrevendo o estado anterior, e esta migracao e repetivel desde um banco
-- vazio.
--
-- v_site_coverage continua de fora do escopo de proposito: a pagina de
-- cobertura existe para mostrar as bordas truncadas.

DROP VIEW IF EXISTS analytics.v_site_price_weekly_uf;

CREATE VIEW analytics.v_site_price_weekly_uf AS
WITH por_uf AS (
    SELECT
        w.week_start_date,
        ct.uf::text     AS uf,
        ct.region::text AS region,
        p.product_name,
        p.fuel_family,
        ROUND(SUM(w.median_price * w.observations) / SUM(w.observations), 3)
            AS weighted_mean_of_medians,
        ROUND(SUM(w.p10_price * w.observations) / SUM(w.observations), 3) AS p10_weighted,
        ROUND(SUM(w.p90_price * w.observations) / SUM(w.observations), 3) AS p90_weighted,
        SUM(w.observations)        AS observations,
        -- stations e somavel aqui: cada linha tem um unico produto.
        SUM(w.stations)            AS stations,
        COUNT(DISTINCT w.city_key) AS cities
    FROM analytics.mv_weekly_price w
    JOIN core.dim_city    ct ON ct.city_key   = w.city_key
    JOIN core.dim_product p  ON p.product_key = w.product_key
    WHERE p.in_default_scope
      AND p.is_liquid_fuel   -- exclui GNV: R$/m3 nao e comparavel com R$/litro
    GROUP BY 1, 2, 3, 4, 5
)
SELECT u.*
FROM por_uf u
JOIN analytics.v_site_week_scope s USING (week_start_date);

COMMENT ON VIEW analytics.v_site_price_weekly_uf IS
    'Preco semanal por UF e produto, restrito as semanas de cobertura '
    'completa. Media das medianas municipais ponderada por observacao, nao a '
    'mediana da UF.';
