-- Escopo temporal do consumo: exclui as semanas de borda da janela.
--
-- A primeira e a ultima semana vem cortadas ao meio pelo recorte dos arquivos
-- da fonte, nao por falha de coleta: em 2026-06-29 a cobertura nacional cai
-- de ~375 para 280 municipios, e 2023-01-02 comeca em 279 antes de estabilizar
-- em 339 tres semanas depois.
--
-- O corte e estrutural, nao estatistico. Um limiar sobre a cobertura mediana
-- foi testado e descartado: a 85 por cento ele excluia 16 semanas contiguas
-- entre 2025-07-14 e 2025-10-27, quando a amostra da fonte caiu de ~370 para
-- ~270 municipios e depois se recuperou. Isso e cobertura real, e exclui-la
-- abria um vao de quatro meses no meio da serie.
--
-- Em vez de suprimir semanas de cobertura baixa, a view expoe cities para que
-- o dashboard mostre o tamanho da amostra junto do numero.

DROP VIEW IF EXISTS analytics.v_site_parity_weekly;
DROP VIEW IF EXISTS analytics.v_site_week_scope;

CREATE VIEW analytics.v_site_week_scope AS
WITH cobertura AS (
    SELECT p.week_start_date, count(DISTINCT p.city_key) AS cities
    FROM analytics.v_site_parity_base p
    GROUP BY 1
),
bordas AS (
    SELECT min(week_start_date) AS primeira,
           max(week_start_date) AS ultima
    FROM cobertura
)
SELECT c.week_start_date, c.cities
FROM cobertura c, bordas b
WHERE c.week_start_date > b.primeira
  AND c.week_start_date < b.ultima;

COMMENT ON VIEW analytics.v_site_week_scope IS
    'Semanas da janela exceto a primeira e a ultima, truncadas pelo recorte '
    'dos arquivos da fonte. A cobertura por semana fica exposta na coluna '
    'cities para ser mostrada no dashboard.';

CREATE VIEW analytics.v_site_parity_weekly AS
SELECT p.*, s.cities
FROM analytics.v_site_parity_base p
JOIN analytics.v_site_week_scope s USING (week_start_date);

COMMENT ON VIEW analytics.v_site_parity_weekly IS
    'Paridade por municipio e semana, sem as semanas de borda. Traz cities, '
    'a cobertura nacional daquela semana, para o dashboard exibir.';