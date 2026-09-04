-- =============================================================================
-- 008_load_functions.sql
-- Transformação e carga. Três etapas encadeadas, todas partindo da mesma view
-- de normalização — a lógica de parsing existe em um lugar só.
--
--   staging.v_price_survey_clean  normaliza e classifica cada linha
--   staging.fn_validate_batch     registra as linhas rejeitadas
--   core.fn_apply_station_scd2    abre e encerra versões de posto
--   core.fn_load_facts            insere as observações de preço
-- =============================================================================

-- -----------------------------------------------------------------------------
-- View de normalização
--
-- Converte o texto bruto e diz, por linha, qual regra ela viola — ou NULL se
-- está boa. Validação e carga leem daqui, então nunca divergem sobre o que é
-- uma linha válida.
--
-- A data é montada em ISO (YYYY-MM-DD) antes do cast em vez de depender de
-- to_date com máscara: assim o resultado não muda conforme o DateStyle da
-- sessão, e pg_input_is_valid rejeita 31/02 sem lançar exceção.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE VIEW staging.v_price_survey_clean AS
SELECT
    s.source_file_id,
    s.line_number,
    n.cnpj,
    n.collection_date,
    n.sale_price,
    n.legal_name,
    n.brand_raw,
    n.city_name,
    n.uf,
    n.region,
    n.street,
    n.street_number,
    n.district,
    n.zip_code,
    n.complement,
    n.product_name_src,
    p.product_key,
    -- A ordem das regras importa: cada linha recebe o primeiro motivo que se
    -- aplica, e o mais genérico tem de vir antes. Linha inteiramente em branco é
    -- artefato de exportação da planilha de origem, não erro de conteúdo, e
    -- misturá-la com CNPJ ausente esconderia as duas.
    CASE
        WHEN raw.is_blank_row                           THEN 'empty_row'
        WHEN raw.cnpj_digits = ''                       THEN 'cnpj_missing'
        WHEN length(raw.cnpj_digits) <> 14              THEN 'cnpj_length'
        WHEN n.collection_date IS NULL                  THEN 'date_unparseable'
        WHEN d.full_date IS NULL                        THEN 'date_out_of_calendar'
        WHEN n.sale_price IS NULL                       THEN 'price_unparseable'
        WHEN n.sale_price <= 0 OR n.sale_price > 50     THEN 'price_out_of_range'
        WHEN p.product_key IS NULL                      THEN 'product_unknown'
        WHEN n.uf !~ '^[A-Z]{2}$'                       THEN 'uf_invalid'
        WHEN n.legal_name = ''                          THEN 'legal_name_empty'
    END AS reject_rule
FROM staging.stg_price_survey s

CROSS JOIN LATERAL (
    SELECT
        btrim(coalesce(s.data_da_coleta, ''))                        AS date_raw,
        replace(btrim(coalesce(s.valor_de_venda, '')), ',', '.')     AS price_raw,
        regexp_replace(coalesce(s.cnpj_da_revenda, ''), '\D', '', 'g') AS cnpj_digits,
        btrim(concat_ws('',
            s.regiao_sigla, s.estado_sigla, s.municipio, s.revenda,
            s.cnpj_da_revenda, s.nome_da_rua, s.numero_rua, s.complemento,
            s.bairro, s.cep, s.produto, s.data_da_coleta, s.valor_de_venda,
            s.valor_de_compra, s.unidade_de_medida, s.bandeira)) = ''
                                                                     AS is_blank_row
) raw

CROSS JOIN LATERAL (
    SELECT
        CASE
            WHEN raw.date_raw ~ '^\d{2}/\d{2}/\d{4}$'
             AND pg_input_is_valid(
                     substr(raw.date_raw, 7, 4) || '-' ||
                     substr(raw.date_raw, 4, 2) || '-' ||
                     substr(raw.date_raw, 1, 2), 'date')
            THEN (substr(raw.date_raw, 7, 4) || '-' ||
                  substr(raw.date_raw, 4, 2) || '-' ||
                  substr(raw.date_raw, 1, 2))::date
        END AS collection_date
) parsed_date

CROSS JOIN LATERAL (
    SELECT
        CASE WHEN length(raw.cnpj_digits) = 14 THEN raw.cnpj_digits END      AS cnpj,
        parsed_date.collection_date,
        CASE WHEN raw.price_raw <> '' AND pg_input_is_valid(raw.price_raw, 'numeric')
             THEN raw.price_raw::numeric
        END                                                                  AS sale_price,
        upper(btrim(regexp_replace(coalesce(s.revenda, ''),   '\s+', ' ', 'g'))) AS legal_name,
        coalesce(s.bandeira, '')                                             AS brand_raw,
        upper(btrim(regexp_replace(coalesce(s.municipio, ''), '\s+', ' ', 'g'))) AS city_name,
        upper(btrim(coalesce(s.estado_sigla, '')))                           AS uf,
        upper(btrim(coalesce(s.regiao_sigla, '')))                           AS region,
        nullif(upper(btrim(regexp_replace(coalesce(s.nome_da_rua, ''), '\s+', ' ', 'g'))), '') AS street,
        nullif(upper(btrim(coalesce(s.numero_rua, ''))), '')                 AS street_number,
        nullif(upper(btrim(regexp_replace(coalesce(s.bairro, ''), '\s+', ' ', 'g'))), '')      AS district,
        nullif(regexp_replace(coalesce(s.cep, ''), '\D', '', 'g'), '')       AS zip_code_raw,
        CASE WHEN length(regexp_replace(coalesce(s.cep, ''), '\D', '', 'g')) = 8
             THEN regexp_replace(s.cep, '\D', '', 'g')::char(8)
        END                                                                  AS zip_code,
        nullif(upper(btrim(regexp_replace(coalesce(s.complemento, ''), '\s+', ' ', 'g'))), '') AS complement,
        upper(btrim(regexp_replace(coalesce(s.produto, ''), '\s+', ' ', 'g'))) AS product_name_src
) n

LEFT JOIN core.dim_product p ON p.source_product_name = n.product_name_src
LEFT JOIN core.dim_date    d ON d.full_date          = n.collection_date;

COMMENT ON VIEW staging.v_price_survey_clean IS
    'Camada única de normalização. reject_rule NULL significa linha apta a carregar.';

-- -----------------------------------------------------------------------------
-- Validação
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION staging.fn_validate_batch(p_source_file_id integer)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_rejected integer;
BEGIN
    DELETE FROM staging.stg_rejects WHERE source_file_id = p_source_file_id;

    -- raw_row só para as 100 primeiras linhas de cada regra. Guardar a linha
    -- inteira de toda rejeição não escala: uma regra que dispare para o arquivo
    -- todo geraria centenas de milhares de documentos jsonb, consumindo mais
    -- espaço que o próprio fato para diagnosticar um problema que 100 exemplos
    -- já mostram.
    INSERT INTO staging.stg_rejects (source_file_id, line_number, rule_name, detail, raw_row)
    SELECT
        c.source_file_id,
        c.line_number,
        c.reject_rule,
        format('cnpj=%s data=%s produto=%s valor=%s',
               coalesce(c.cnpj, '?'),
               coalesce(c.collection_date::text, '?'),
               coalesce(c.product_name_src, '?'),
               coalesce(c.sale_price::text, '?')),
        CASE WHEN c.sample_rank <= 100
             THEN to_jsonb(s) - 'source_file_id' - 'line_number'
        END
    FROM (
        SELECT
            v.*,
            row_number() OVER (PARTITION BY v.reject_rule ORDER BY v.line_number)
                AS sample_rank
        FROM staging.v_price_survey_clean v
        WHERE v.source_file_id = p_source_file_id
          AND v.reject_rule IS NOT NULL
    ) c
    JOIN staging.stg_price_survey s
      ON s.source_file_id = c.source_file_id AND s.line_number = c.line_number;

    GET DIAGNOSTICS v_rejected = ROW_COUNT;
    RETURN v_rejected;
END $$;

-- -----------------------------------------------------------------------------
-- SCD Tipo 2
--
-- Um arquivo cobre seis meses, então um posto pode mudar de atributo DENTRO do
-- próprio arquivo. Por isso a função não trata o arquivo como um snapshot: ela
-- reconstrói os intervalos de vigência a partir das datas de coleta, detectando
-- o ponto exato em que os atributos mudaram.
--
-- MERGE não resolve isto em um comando: encerrar a versão anterior e inserir a
-- sucessora são duas operações sobre linhas diferentes da mesma tabela, e um
-- MERGE aplica uma ação por linha de origem. O laço explícito é mais lento e
-- mais legível, e o volume (uma iteração por posto por versão) não justifica
-- otimizar.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION core.fn_apply_station_scd2(p_source_file_id integer)
RETURNS TABLE (versions_opened integer, versions_closed integer, brands_new integer)
LANGUAGE plpgsql
AS $$
DECLARE
    v_opened         integer := 0;
    v_closed         integer := 0;
    v_brands_before  integer;
    v_brands_after   integer;
    v_current        core.dim_station%ROWTYPE;
    r                RECORD;
BEGIN
    SELECT count(*) INTO v_brands_before FROM core.dim_brand;

    DROP TABLE IF EXISTS tmp_station_snapshot;
    DROP TABLE IF EXISTS tmp_station_interval;

    -- Um registro por posto e dia de coleta. DISTINCT ON porque o mesmo posto
    -- aparece uma vez por produto no mesmo dia, com os mesmos atributos.
    CREATE TEMP TABLE tmp_station_snapshot ON COMMIT DROP AS
    SELECT DISTINCT ON (c.cnpj, c.collection_date)
        c.cnpj::char(14)                                     AS cnpj,
        c.collection_date,
        c.legal_name,
        core.fn_resolve_brand(c.brand_raw)                    AS brand_key,
        core.fn_resolve_city(c.city_name, c.uf, c.region)     AS city_key,
        c.street,
        c.street_number,
        c.district,
        c.zip_code,
        c.complement
    FROM staging.v_price_survey_clean c
    WHERE c.source_file_id = p_source_file_id
      AND c.reject_rule IS NULL
    ORDER BY c.cnpj, c.collection_date, c.line_number;

    -- Agrupa dias consecutivos com os mesmos atributos em um intervalo. version_seq
    -- é a soma acumulada das mudanças, técnica de ilhas e lacunas.
    CREATE TEMP TABLE tmp_station_interval ON COMMIT DROP AS
    WITH marked AS (
        SELECT
            t.*,
            (ROW(legal_name, brand_key, city_key, street, street_number, district, zip_code)
             IS DISTINCT FROM
             lag(ROW(legal_name, brand_key, city_key, street, street_number, district, zip_code))
                 OVER (PARTITION BY cnpj ORDER BY collection_date)
            )::int AS is_change
        FROM tmp_station_snapshot t
    ),
    grouped AS (
        SELECT
            m.*,
            sum(is_change) OVER (PARTITION BY cnpj ORDER BY collection_date) AS version_seq
        FROM marked m
    )
    -- min() sobre atributos constantes dentro do grupo: por construção todas as
    -- linhas do mesmo version_seq têm os mesmos valores.
    SELECT
        cnpj,
        version_seq,
        min(collection_date) AS first_seen_on,
        max(collection_date) AS last_seen_on,
        min(legal_name)      AS legal_name,
        min(brand_key)       AS brand_key,
        min(city_key)        AS city_key,
        min(street)          AS street,
        min(street_number)   AS street_number,
        min(district)        AS district,
        min(zip_code)        AS zip_code,
        min(complement)      AS complement
    FROM grouped
    GROUP BY cnpj, version_seq;

    -- Reprocessamento: um intervalo já foi aplicado quando existe versão cuja
    -- vigência COBRE a data observada e cujos atributos batem. Comparar por
    -- igualdade de valid_from não basta: quando o posto muda no meio do semestre,
    -- o arquivo gera dois intervalos, e o primeiro repete os atributos de uma
    -- versão aberta num arquivo anterior, com valid_from mais antiga. Esse
    -- intervalo escaparia do filtro, chegaria ao laço com atributos diferentes da
    -- versão vigente e cairia na checagem de ordem cronológica.
    UPDATE core.dim_station s
       SET last_seen_file = p_source_file_id
      FROM tmp_station_interval i
     WHERE s.cnpj       =  i.cnpj
       AND s.valid_from <= i.first_seen_on
       AND s.valid_to   >  i.first_seen_on
       AND ROW(s.legal_name, s.brand_key, s.city_key, s.street,
               s.street_number, s.district, s.zip_code)
           IS NOT DISTINCT FROM
           ROW(i.legal_name, i.brand_key, i.city_key, i.street,
               i.street_number, i.district, i.zip_code);

    DELETE FROM tmp_station_interval i
     USING core.dim_station s
     WHERE s.cnpj       =  i.cnpj
       AND s.valid_from <= i.first_seen_on
       AND s.valid_to   >  i.first_seen_on
       AND ROW(s.legal_name, s.brand_key, s.city_key, s.street,
               s.street_number, s.district, s.zip_code)
           IS NOT DISTINCT FROM
           ROW(i.legal_name, i.brand_key, i.city_key, i.street,
               i.street_number, i.district, i.zip_code);

    FOR r IN
        SELECT * FROM tmp_station_interval ORDER BY cnpj, first_seen_on
    LOOP
        SELECT * INTO v_current
        FROM core.dim_station
        WHERE cnpj = r.cnpj AND is_current;

        -- Posto novo: abre a primeira versão na data em que foi visto pela
        -- primeira vez, não no início do período do arquivo. Só sabemos que ele
        -- existia a partir da observação.
        IF NOT FOUND THEN
            INSERT INTO core.dim_station (
                cnpj, legal_name, brand_key, city_key, street, street_number,
                district, zip_code, complement, valid_from, valid_to, is_current,
                first_seen_file, last_seen_file
            ) VALUES (
                r.cnpj, r.legal_name, r.brand_key, r.city_key, r.street, r.street_number,
                r.district, r.zip_code, r.complement, r.first_seen_on, 'infinity', true,
                p_source_file_id, p_source_file_id
            );
            v_opened := v_opened + 1;
            CONTINUE;
        END IF;

        -- Atributos idênticos: nada muda, só a proveniência.
        IF ROW(v_current.legal_name, v_current.brand_key, v_current.city_key,
               v_current.street, v_current.street_number, v_current.district,
               v_current.zip_code)
           IS NOT DISTINCT FROM
           ROW(r.legal_name, r.brand_key, r.city_key,
               r.street, r.street_number, r.district, r.zip_code)
        THEN
            UPDATE core.dim_station
               SET last_seen_file = p_source_file_id,
                   complement     = coalesce(r.complement, complement)
             WHERE station_key = v_current.station_key;
            CONTINUE;
        END IF;

        IF r.first_seen_on <= v_current.valid_from THEN
            RAISE EXCEPTION
                'CNPJ % observado em % com atributos novos, mas a versão vigente '
                'começa em %. Os arquivos precisam ser carregados em ordem cronológica.',
                r.cnpj, r.first_seen_on, v_current.valid_from;
        END IF;

        UPDATE core.dim_station
           SET valid_to       = r.first_seen_on,
               is_current     = false,
               last_seen_file = p_source_file_id
         WHERE station_key = v_current.station_key;
        v_closed := v_closed + 1;

        INSERT INTO core.dim_station (
            cnpj, legal_name, brand_key, city_key, street, street_number,
            district, zip_code, complement, valid_from, valid_to, is_current,
            first_seen_file, last_seen_file
        ) VALUES (
            r.cnpj, r.legal_name, r.brand_key, r.city_key, r.street, r.street_number,
            r.district, r.zip_code, r.complement, r.first_seen_on, 'infinity', true,
            p_source_file_id, p_source_file_id
        );
        v_opened := v_opened + 1;
    END LOOP;

    SELECT count(*) INTO v_brands_after FROM core.dim_brand;

    RETURN QUERY SELECT v_opened, v_closed, v_brands_after - v_brands_before;
END $$;

-- -----------------------------------------------------------------------------
-- Carga do fato
--
-- Três decisões, todas sobre a resolução da observação para o grão do fato.
--
-- 1. Desempate declarado. A fonte traz, raramente, o mesmo posto e produto duas
--    vezes na mesma data — o registro inteiro replicado, às vezes com preços
--    diferentes. Entre duas medições válidas fica a MENOR: o levantamento mede o
--    preço praticado ao consumidor, e essa é a que ele conseguiu pagar. Sem esta
--    regra o desempate caberia ao ON CONFLICT, ou seja, à ordem de leitura do
--    arquivo — arbitrária e não reproduzível.
--
-- 2. A normalização é materializada numa tabela temporária antes do join. Lida
--    diretamente da view, a cadeia de regex seria reavaliada a cada sondagem do
--    join, e não uma vez por linha.
--
-- 3. O predicado temporal é comparação de datas (valid_from <= d < valid_to), não
--    daterange @> d, e o CNPJ é convertido para char(14) para casar com o tipo da
--    dimensão. Assim o planejador enxerga dim_station como o lado pequeno de um
--    hash join, em vez de sondar o índice GiST milhões de vezes.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION core.fn_load_facts(p_source_file_id integer)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_inserted integer;
BEGIN
    DROP TABLE IF EXISTS tmp_fact_input;

    CREATE TEMP TABLE tmp_fact_input ON COMMIT DROP AS
    SELECT DISTINCT ON (c.collection_date, c.cnpj, c.product_key)
        c.cnpj::char(14) AS cnpj,
        c.collection_date,
        c.product_key,
        c.sale_price
    FROM staging.v_price_survey_clean c
    WHERE c.source_file_id = p_source_file_id
      AND c.reject_rule IS NULL
    ORDER BY c.collection_date, c.cnpj, c.product_key, c.sale_price;

    ANALYZE tmp_fact_input;

    INSERT INTO core.fct_price_observation
        (collection_date, station_key, product_key, sale_price, source_file_id)
    SELECT
        t.collection_date,
        st.station_key,
        t.product_key,
        t.sale_price,
        p_source_file_id
    FROM tmp_fact_input t
    JOIN core.dim_station st
      ON st.cnpj       =  t.cnpj
     AND st.valid_from <= t.collection_date
     AND st.valid_to   >  t.collection_date
    ON CONFLICT (collection_date, station_key, product_key) DO NOTHING;

    GET DIAGNOSTICS v_inserted = ROW_COUNT;
    RETURN v_inserted;
END $$;

COMMENT ON FUNCTION core.fn_load_facts IS
    'Idempotente por ON CONFLICT DO NOTHING: reprocessar o mesmo arquivo não '
    'duplica observação nem altera o que já está carregado.';
