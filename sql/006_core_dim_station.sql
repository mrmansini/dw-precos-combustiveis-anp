-- =============================================================================
-- 006_core_dim_station.sql
-- dim_station: SCD Tipo 2. O coração do projeto.
--
-- Justificativa medida (docs/perfil-grao.md): dos 5.071 CNPJs presentes em
-- 2023-01 e 2025-02, 1.784 aparecem com bandeira diferente. Removendo as duas
-- renomeações de rótulo (VIBRA ENERGIA -> VIBRA e ALESAT -> ALE, 1.151 postos),
-- sobram ~633 trocas comerciais reais — 298 desbandeiramentos, 195 bandeiramentos
-- e o restante entre distribuidoras. Além disso, 9,2% mudaram de endereço e 7,1%
-- de razão social. Há material de sobra para versionar.
-- =============================================================================

CREATE TABLE IF NOT EXISTS core.dim_station (
    station_key      bigint  GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    -- chave natural: estável, 14 dígitos em 100% das linhas perfiladas
    cnpj             char(14) NOT NULL,

    -- atributos versionados
    legal_name       text     NOT NULL,
    brand_key        integer  NOT NULL REFERENCES core.dim_brand (brand_key),
    city_key         integer  NOT NULL REFERENCES core.dim_city  (city_key),
    street           text,
    street_number    text,
    district         text,
    zip_code         char(8),

    -- atributo NÃO versionado, guardado só na versão corrente
    complement       text,

    -- vigência
    valid_from       date     NOT NULL,
    valid_to         date     NOT NULL DEFAULT 'infinity',
    is_current       boolean  NOT NULL DEFAULT true,

    -- proveniência
    first_seen_file  integer  REFERENCES etl.source_files (source_file_id),
    last_seen_file   integer  REFERENCES etl.source_files (source_file_id),

    -- Hash dos atributos versionados. GENERATED ALWAYS: é impossível a versão
    -- existir com hash que não corresponde aos seus próprios atributos, então a
    -- comparação da carga nunca compara contra um valor desatualizado.
    attribute_hash   uuid GENERATED ALWAYS AS (
        md5(
            legal_name                     || '|' ||
            brand_key::text                || '|' ||
            city_key::text                 || '|' ||
            coalesce(street, '')           || '|' ||
            coalesce(street_number, '')    || '|' ||
            coalesce(district, '')         || '|' ||
            coalesce(zip_code, '')
        )::uuid
    ) STORED,

    CONSTRAINT dim_station_cnpj_digits
        CHECK (cnpj ~ '^[0-9]{14}$'),
    CONSTRAINT dim_station_range_valid
        CHECK (valid_from < valid_to),
    CONSTRAINT dim_station_current_flag_agrees
        CHECK (is_current = (valid_to = 'infinity'::date)),

    -- A regra que o banco garante: nunca existem duas versões do mesmo CNPJ com
    -- vigências que se sobrepõem. Regra de negócio no banco, não na aplicação.
    CONSTRAINT dim_station_no_overlap EXCLUDE USING gist (
        cnpj                              WITH =,
        daterange(valid_from, valid_to)   WITH &&
    )
);

COMMENT ON TABLE core.dim_station IS
    'Posto revendedor versionado por SCD Tipo 2. Uma linha por combinação de '
    'atributos vigente num intervalo [valid_from, valid_to).';

COMMENT ON COLUMN core.dim_station.complement IS
    'Complemento de endereço fica FORA do hash de propósito: é texto livre e '
    'instável na fonte ("ESQUINA C/RUA..."), e versionar por causa dele geraria '
    'versão nova sem mudança de fato.';

COMMENT ON COLUMN core.dim_station.valid_to IS
    'Exclusivo. A versão corrente usa infinity, o que deixa daterange aberto à '
    'direita e faz a constraint de exclusão funcionar sem data sentinela mágica.';

-- Só uma versão corrente por CNPJ. O índice parcial é também o caminho de acesso
-- da carga, que sempre procura a versão aberta.
CREATE UNIQUE INDEX IF NOT EXISTS dim_station_current_uidx
    ON core.dim_station (cnpj) WHERE is_current;

-- Busca de versão por data (a que o fato usa no join temporal).
CREATE INDEX IF NOT EXISTS dim_station_cnpj_validity_idx
    ON core.dim_station (cnpj, valid_from, valid_to);

-- Análise de evento: "quais postos trocaram de bandeira e quando".
CREATE INDEX IF NOT EXISTS dim_station_brand_idx
    ON core.dim_station (brand_key, valid_from);

-- -----------------------------------------------------------------------------
-- Resolução temporal: dado um CNPJ e uma data de coleta, qual station_key vale?
-- É a função que a carga do fato chama.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION core.fn_station_key_at(p_cnpj char(14), p_on date)
RETURNS bigint
LANGUAGE sql
STABLE
AS $$
    SELECT station_key
    FROM core.dim_station
    WHERE cnpj = p_cnpj
      AND daterange(valid_from, valid_to) @> p_on
$$;

-- -----------------------------------------------------------------------------
-- Views de apoio
-- -----------------------------------------------------------------------------

CREATE OR REPLACE VIEW core.v_station_current AS
SELECT
    s.station_key, s.cnpj, s.legal_name,
    b.brand_name, b.is_unbranded,
    c.city_name, c.uf, c.region,
    s.street, s.street_number, s.district, s.zip_code,
    s.valid_from
FROM core.dim_station s
JOIN core.dim_brand b USING (brand_key)
JOIN core.dim_city  c USING (city_key)
WHERE s.is_current;

-- Trocas de bandeira já limpas de renomeação: é daqui que sai a análise de evento.
CREATE OR REPLACE VIEW core.v_brand_changes AS
SELECT
    curr.cnpj,
    curr.station_key            AS station_key_after,
    prev.station_key            AS station_key_before,
    prev.brand_key              AS brand_key_before,
    b_prev.brand_name           AS brand_before,
    curr.brand_key              AS brand_key_after,
    b_curr.brand_name           AS brand_after,
    curr.valid_from             AS changed_on,
    b_prev.is_unbranded         AS was_unbranded,
    b_curr.is_unbranded         AS is_unbranded_now,
    CASE
        WHEN b_prev.is_unbranded AND NOT b_curr.is_unbranded THEN 'bandeiramento'
        WHEN NOT b_prev.is_unbranded AND b_curr.is_unbranded THEN 'desbandeiramento'
        ELSE 'troca de distribuidora'
    END                         AS change_type
FROM core.dim_station curr
JOIN core.dim_station prev
     ON prev.cnpj     = curr.cnpj
    AND prev.valid_to = curr.valid_from
JOIN core.dim_brand b_prev ON b_prev.brand_key = prev.brand_key
JOIN core.dim_brand b_curr ON b_curr.brand_key = curr.brand_key
WHERE prev.brand_key <> curr.brand_key;

COMMENT ON VIEW core.v_brand_changes IS
    'Trocas reais de bandeira. Renomeações de rótulo não aparecem aqui porque a '
    'brand_alias já resolveu VIBRA ENERGIA e VIBRA para o mesmo brand_key, então '
    'o SCD2 nunca chegou a abrir versão por causa delas.';
