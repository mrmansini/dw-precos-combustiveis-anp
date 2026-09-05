-- Camada de consumo do dashboard publicado.
--
-- Todas as views deste arquivo leem de analytics.mv_weekly_price (011) e nunca
-- do fato: o site carrega o conjunto inteiro no navegador do visitante.
--
-- O prefixo v_site_ funciona como contrato: sao as unicas views que o
-- dashboard consome. Mudanca em view interna de analytics nao quebra o site
-- em silencio.
--
-- ibge_code nao entra em lugar nenhum: a coluna vem inteiramente nula da
-- fonte (462 de 462 municipios), o que inviabiliza join com malha geografica.

-- DROP antes de cada CREATE: CREATE OR REPLACE VIEW recusa remocao ou
-- renomeacao de coluna (SQLSTATE 42P16), entao sem isso a migracao deixa de
-- ser idempotente na primeira mudanca de assinatura. Nada depende destas
-- views alem do site, que e reconstruido a cada deploy.
DROP VIEW IF EXISTS analytics.v_site_parity_weekly;
DROP VIEW IF EXISTS analytics.v_site_city;
DROP VIEW IF EXISTS analytics.v_site_price_weekly_uf;
DROP VIEW IF EXISTS analytics.v_site_brand_effect;
DROP VIEW IF EXISTS analytics.v_site_coverage;

-- ---------------------------------------------------------------------------
-- Paridade etanol/gasolina por municipio e semana.
--
-- A chave e city_key; nome e UF vem de v_site_city, juntados no navegador
-- para nao repetir o nome do municipio em dezenas de milhares de linhas.
--
-- O filtro usa product_name e nao source_product_name porque core.dim_product
-- existe para isolar o consumo da grafia da fonte.
-- ---------------------------------------------------------------------------
CREATE VIEW analytics.v_site_parity_weekly AS
WITH pivot AS (
    SELECT
        w.week_start_date,
        w.city_key,
        MAX(w.median_price) FILTER (WHERE p.product_name = 'Etanol hidratado') AS ethanol_price,
        MAX(w.median_price) FILTER (WHERE p.product_name = 'Gasolina comum')   AS gasoline_price,
        -- observations soma entre produtos; stations nao, porque o
        -- count(DISTINCT station_key) de 011 e calculado por produto e o
        -- mesmo posto seria contado duas vezes.
        SUM(w.observations) AS observations
    FROM analytics.mv_weekly_price w
    JOIN core.dim_product p ON p.product_key = w.product_key
    WHERE p.product_name IN ('Etanol hidratado', 'Gasolina comum')
    GROUP BY 1, 2
)
SELECT
    week_start_date,
    city_key,
    ethanol_price,
    gasoline_price,
    ROUND(ethanol_price / gasoline_price, 4) AS parity_ratio,
    observations
FROM pivot
WHERE ethanol_price IS NOT NULL
  AND gasoline_price IS NOT NULL;

COMMENT ON VIEW analytics.v_site_parity_weekly IS
    'Paridade etanol/gasolina por municipio e semana ISO. Descarta '
    'municipio-semana sem as duas series: 1.327 de 70.981 pesquisados, '
    'ou 1,9 por cento, sendo 1.298 apenas com gasolina.';

-- ---------------------------------------------------------------------------
-- Lookup de municipio, restrito aos que aparecem no rollup.
-- ---------------------------------------------------------------------------
CREATE VIEW analytics.v_site_city AS
SELECT ct.city_key,
       ct.city_name,
       ct.uf::text     AS uf,
       ct.region::text AS region
FROM core.dim_city ct
WHERE EXISTS (
    SELECT 1 FROM analytics.mv_weekly_price w WHERE w.city_key = ct.city_key
);

COMMENT ON VIEW analytics.v_site_city IS
    'Dimensao de municipio para join no navegador. ibge_code omitido de '
    'proposito: vem inteiramente nulo da fonte.';

-- ---------------------------------------------------------------------------
-- Panorama: serie semanal por UF e produto.
--
-- Media das medianas municipais ponderada por observacao. NAO e a mediana da
-- UF: o rollup de 011 ja colapsou o preco em mediana por municipio, e mediana
-- de medianas nao reconstitui a mediana da distribuicao original. O nome da
-- coluna declara isso.
-- ---------------------------------------------------------------------------
CREATE VIEW analytics.v_site_price_weekly_uf AS
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
GROUP BY 1, 2, 3, 4, 5;

-- ---------------------------------------------------------------------------
-- Passagens diretas. Ja estao no grao certo e sao pequenas; existem apenas
-- para que o site dependa do contrato v_site_ e nao das views internas.
-- ---------------------------------------------------------------------------
CREATE VIEW analytics.v_site_brand_effect AS
SELECT * FROM analytics.v_brand_change_effect;

CREATE VIEW analytics.v_site_coverage AS
SELECT * FROM analytics.v_sample_coverage;