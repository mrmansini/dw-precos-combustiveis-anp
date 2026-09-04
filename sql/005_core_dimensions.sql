-- =============================================================================
-- 005_core_dimensions.sql
-- Dimensões conformadas SCD Tipo 1 (dim_station, o Tipo 2, fica na 006).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- dim_date
-- survey_week_key existe porque o grão analítico da fonte é a SEMANA de pesquisa,
-- não o dia: o perfil mostrou zero duplicatas de posto+produto por semana ISO, e
-- a distribuição por dia da semana mudou entre 2023 e 2025 (sábados aparecem em
-- 2025). Agregar por data crua criaria movimento que é da rota do pesquisador.
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS core.dim_date (
    date_key          integer     PRIMARY KEY,          -- YYYYMMDD
    full_date         date        NOT NULL UNIQUE,
    year              smallint    NOT NULL,
    quarter           smallint    NOT NULL,
    month             smallint    NOT NULL,
    month_name_pt     text        NOT NULL,
    day               smallint    NOT NULL,
    day_of_week       smallint    NOT NULL,             -- 1 = segunda (ISO)
    day_name_pt       text        NOT NULL,
    is_weekend        boolean     NOT NULL,
    iso_year          smallint    NOT NULL,
    iso_week          smallint    NOT NULL,
    survey_week_key   integer     NOT NULL,             -- iso_year * 100 + iso_week
    week_start_date   date        NOT NULL,             -- segunda-feira da semana ISO
    month_start_date  date        NOT NULL
);

COMMENT ON COLUMN core.dim_date.survey_week_key IS
    'Chave da semana de pesquisa (iso_year*100 + iso_week). É o grão real da fonte: '
    'cada posto/produto aparece no máximo uma vez por semana.';

INSERT INTO core.dim_date
SELECT
    to_char(d, 'YYYYMMDD')::integer,
    d::date,
    EXTRACT(year    FROM d)::smallint,
    EXTRACT(quarter FROM d)::smallint,
    EXTRACT(month   FROM d)::smallint,
    (ARRAY['janeiro','fevereiro','março','abril','maio','junho',
           'julho','agosto','setembro','outubro','novembro','dezembro'
    ])[EXTRACT(month FROM d)::int],
    EXTRACT(day FROM d)::smallint,
    EXTRACT(isodow FROM d)::smallint,
    (ARRAY['segunda','terça','quarta','quinta','sexta','sábado','domingo'
    ])[EXTRACT(isodow FROM d)::int],
    EXTRACT(isodow FROM d) >= 6,
    EXTRACT(isoyear FROM d)::smallint,
    EXTRACT(week    FROM d)::smallint,
    (EXTRACT(isoyear FROM d) * 100 + EXTRACT(week FROM d))::integer,
    date_trunc('week',  d)::date,
    date_trunc('month', d)::date
FROM generate_series(DATE '2023-01-01', DATE '2027-12-31', interval '1 day') AS d
ON CONFLICT (date_key) DO NOTHING;

-- -----------------------------------------------------------------------------
-- dim_product
-- source_product_name é o texto exato do CSV: é por ele que a carga resolve.
-- GNV fica separado por unidade — R$/m³ nunca entra em média com R$/litro.
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS core.dim_product (
    product_key          smallint PRIMARY KEY,
    source_product_name  text     NOT NULL UNIQUE,
    product_name         text     NOT NULL,
    fuel_family          text     NOT NULL,
    unit_of_measure      text     NOT NULL,
    is_liquid_fuel       boolean  NOT NULL,
    in_default_scope     boolean  NOT NULL DEFAULT true
);

INSERT INTO core.dim_product (
    product_key, source_product_name, product_name, fuel_family,
    unit_of_measure, is_liquid_fuel, in_default_scope
) VALUES
    (1, 'GASOLINA',            'Gasolina comum',     'Gasolina', 'R$/litro', true,  true),
    (2, 'GASOLINA ADITIVADA',  'Gasolina aditivada', 'Gasolina', 'R$/litro', true,  true),
    (3, 'ETANOL',              'Etanol hidratado',   'Etanol',   'R$/litro', true,  true),
    (4, 'DIESEL',              'Óleo diesel',        'Diesel',   'R$/litro', true,  true),
    (5, 'DIESEL S10',          'Óleo diesel S-10',   'Diesel',   'R$/litro', true,  true),
    (6, 'GNV',                 'Gás natural veicular','GNV',     'R$/m³',    false, true)
ON CONFLICT (product_key) DO NOTHING;

COMMENT ON COLUMN core.dim_product.unit_of_measure IS
    'Unidade canônica. A fonte grafa o GNV como "R$ / m³" em 2023 e "R$ / m3" em '
    '2025 — a normalização acontece aqui, não em cada consulta.';

-- -----------------------------------------------------------------------------
-- dim_brand + brand_alias
-- O perfil provou que 64% das "mudanças de bandeira" entre 2023-01 e 2025-02 são
-- renomeação de rótulo (VIBRA ENERGIA -> VIBRA, 1.012 postos; ALESAT -> ALE, 139).
-- Sem essa camada, o SCD2 abriria ~1.150 versões falsas e a análise de evento
-- viraria ruído. A alias table separa mudança de identidade de mudança de nome.
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS core.dim_brand (
    brand_key      integer     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    brand_name     text        NOT NULL UNIQUE,   -- nome canônico
    is_unbranded   boolean     NOT NULL DEFAULT false,
    needs_review   boolean     NOT NULL DEFAULT false,
    first_seen_at  timestamptz NOT NULL DEFAULT now()
);

COMMENT ON COLUMN core.dim_brand.is_unbranded IS
    'BRANCA = posto sem bandeira. Não é uma marca: é a ausência dela, e o '
    'desbandeiramento é justamente um dos eventos que o SCD2 existe para capturar.';

COMMENT ON COLUMN core.dim_brand.needs_review IS
    'true = bandeira criada automaticamente pela carga, ainda não classificada. '
    'Consultar ops.v_brands_to_review após cada arquivo novo.';

CREATE TABLE IF NOT EXISTS core.brand_alias (
    alias_text  text    PRIMARY KEY,   -- texto cru da fonte, normalizado
    brand_key   integer NOT NULL REFERENCES core.dim_brand (brand_key),
    is_rename   boolean NOT NULL DEFAULT false,
    note        text
);

COMMENT ON COLUMN core.brand_alias.is_rename IS
    'true = mesma empresa com rótulo novo na fonte. Essas transições NÃO contam '
    'como troca de bandeira nas análises de evento.';

-- Bandeiras canônicas observadas no perfil (top 15 de cada arquivo + transições).
INSERT INTO core.dim_brand (brand_name, is_unbranded) VALUES
    ('BRANCA', true),
    ('VIBRA', false), ('IPIRANGA', false), ('RAIZEN', false), ('ALE', false),
    ('SABBÁ', false), ('ATEM''S', false), ('RAIZEN MIME', false), ('RODOIL', false),
    ('STANG', false), ('TAURUS', false), ('CHARRUA', false), ('DISLUB', false),
    ('SP', false), ('EQUADOR', false), ('MAXSUL', false), ('NEXTA', false),
    ('TOTALENERGIES', false), ('SIM DISTRIBUIDOR', false), ('SANTA LUCIA', false),
    ('SUL COMBUSTÍVEIS', false), ('TEMAPE', false)
ON CONFLICT (brand_name) DO NOTHING;

-- Cada canônica é alias de si mesma.
INSERT INTO core.brand_alias (alias_text, brand_key, is_rename, note)
SELECT brand_name, brand_key, false, 'canônica'
FROM core.dim_brand
ON CONFLICT (alias_text) DO NOTHING;

-- As duas renomeações confirmadas em docs/perfil-grao.md.
INSERT INTO core.brand_alias (alias_text, brand_key, is_rename, note)
SELECT 'VIBRA ENERGIA', brand_key, true,
       'Rótulo usado até 2023; 1.012 postos aparecem como VIBRA em 2025-02.'
FROM core.dim_brand WHERE brand_name = 'VIBRA'
ON CONFLICT (alias_text) DO NOTHING;

INSERT INTO core.brand_alias (alias_text, brand_key, is_rename, note)
SELECT 'ALESAT', brand_key, true,
       'Rótulo usado até 2023; 139 postos aparecem como ALE em 2025-02.'
FROM core.dim_brand WHERE brand_name = 'ALE'
ON CONFLICT (alias_text) DO NOTHING;

-- Resolve o texto cru da fonte para a bandeira canônica. Bandeira desconhecida
-- não derruba a carga: entra como nova, marcada para revisão manual.
CREATE OR REPLACE FUNCTION core.fn_resolve_brand(p_raw text)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_alias text;
    v_key   integer;
BEGIN
    v_alias := upper(btrim(regexp_replace(coalesce(p_raw, ''), '\s+', ' ', 'g')));
    IF v_alias = '' THEN
        v_alias := 'NÃO INFORMADA';
    END IF;

    SELECT brand_key INTO v_key FROM core.brand_alias WHERE alias_text = v_alias;
    IF v_key IS NOT NULL THEN
        RETURN v_key;
    END IF;

    INSERT INTO core.dim_brand (brand_name, needs_review)
    VALUES (v_alias, true)
    ON CONFLICT (brand_name) DO UPDATE SET brand_name = EXCLUDED.brand_name
    RETURNING brand_key INTO v_key;

    INSERT INTO core.brand_alias (alias_text, brand_key, note)
    VALUES (v_alias, v_key, 'criada automaticamente pela carga')
    ON CONFLICT (alias_text) DO NOTHING;

    RETURN v_key;
END $$;

CREATE OR REPLACE VIEW ops.v_brands_to_review AS
SELECT brand_key, brand_name, first_seen_at
FROM core.dim_brand
WHERE needs_review
ORDER BY first_seen_at DESC;

-- -----------------------------------------------------------------------------
-- dim_city
-- SCD Tipo 1: município não muda de nome nem de UF na janela do projeto. O perfil
-- confirmou zero CNPJs em mais de um município dentro do mesmo arquivo.
-- ibge_code fica nulo agora e é enriquecido depois pela API de localidades do IBGE.
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS core.dim_city (
    city_key   integer  GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    city_name  text     NOT NULL,
    uf         char(2)  NOT NULL,
    region     char(2)  NOT NULL,
    ibge_code  integer,
    UNIQUE (city_name, uf)
);

CREATE OR REPLACE FUNCTION core.fn_resolve_city(
    p_city text, p_uf text, p_region text
) RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_city   text := upper(btrim(regexp_replace(coalesce(p_city, ''), '\s+', ' ', 'g')));
    v_uf     char(2) := upper(btrim(coalesce(p_uf, '')));
    v_region char(2) := upper(btrim(coalesce(p_region, '')));
    v_key    integer;
BEGIN
    SELECT city_key INTO v_key
    FROM core.dim_city WHERE city_name = v_city AND uf = v_uf;
    IF v_key IS NOT NULL THEN
        RETURN v_key;
    END IF;

    INSERT INTO core.dim_city (city_name, uf, region)
    VALUES (v_city, v_uf, v_region)
    ON CONFLICT (city_name, uf) DO UPDATE SET city_name = EXCLUDED.city_name
    RETURNING city_key INTO v_key;

    RETURN v_key;
END $$;
