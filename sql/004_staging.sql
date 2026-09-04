-- =============================================================================
-- 004_staging.sql
-- Landing bruto: todas as colunas como text, exatamente como o CSV entrega.
-- Nenhuma conversão aqui — data com barra, preço com vírgula, CNPJ com ou sem
-- máscara. Converter na entrada esconde o dado sujo; a ideia é o oposto.
--
-- Decisão registrada: tabela LOGGED, não UNLOGGED. UNLOGGED economizaria WAL e
-- espaço, mas no Neon o compute suspende após 5 min de inatividade e o conteúdo
-- de tabela unlogged se perde — o que numa carga de vários minutos é uma armadilha
-- silenciosa. O espaço é recuperado com TRUNCATE ao fim de cada arquivo.
-- =============================================================================

CREATE TABLE IF NOT EXISTS staging.stg_price_survey (
    source_file_id     integer NOT NULL REFERENCES etl.source_files (source_file_id),
    line_number        integer NOT NULL,

    regiao_sigla       text,
    estado_sigla       text,
    municipio          text,
    revenda            text,
    cnpj_da_revenda    text,
    nome_da_rua        text,
    numero_rua         text,
    complemento        text,
    bairro             text,
    cep                text,
    produto            text,
    data_da_coleta     text,
    valor_de_venda     text,
    valor_de_compra    text,   -- 100% vazio nos arquivos perfilados; mantida por fidelidade ao layout
    unidade_de_medida  text,
    bandeira           text,

    PRIMARY KEY (source_file_id, line_number)
);

COMMENT ON TABLE staging.stg_price_survey IS
    'Espelho textual do CSV da ANP. Truncada a cada arquivo processado.';

COMMENT ON COLUMN staging.stg_price_survey.line_number IS
    'Número da linha no arquivo de origem. É o que permite apontar a rejeição para '
    'a linha exata do CSV em vez de "alguma linha falhou".';

-- -----------------------------------------------------------------------------
-- Rejeições: linha que não passou na validação não é descartada, é registrada.
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS staging.stg_rejects (
    reject_id       bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_file_id  integer     NOT NULL REFERENCES etl.source_files (source_file_id),
    line_number     integer     NOT NULL,
    rule_name       text        NOT NULL,
    detail          text,
    raw_row         jsonb,
    rejected_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS stg_rejects_rule_idx
    ON staging.stg_rejects (source_file_id, rule_name);

COMMENT ON COLUMN staging.stg_rejects.rule_name IS
    'Regra violada: cnpj_length, date_unparseable, price_unparseable, '
    'product_unknown, unit_mismatch, price_out_of_range.';

CREATE OR REPLACE VIEW ops.v_reject_summary AS
SELECT
    f.semester_label,
    r.rule_name,
    count(*)                       AS rejected_rows,
    min(r.line_number)             AS first_line,
    max(r.rejected_at)             AS last_seen
FROM staging.stg_rejects r
JOIN etl.source_files f USING (source_file_id)
GROUP BY f.semester_label, r.rule_name
ORDER BY f.semester_label, rejected_rows DESC;
