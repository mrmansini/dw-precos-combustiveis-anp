-- =============================================================================
-- 002_etl_source_files.sql
-- Catálogo que governa a carga: quem decide encoding, delimitador, formato de
-- data e janela coberta é a linha desta tabela, não o código Python.
-- =============================================================================

CREATE TABLE IF NOT EXISTS etl.source_files (
    source_file_id      integer     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    -- identificação
    semester_label      text        NOT NULL UNIQUE,   -- '2023-01', '2026-01'
    original_file_name  text,                          -- nome como a ANP publica
    local_file_name     text        NOT NULL,          -- nome normalizado em data/raw/
    source_url          text,                          -- preencher ao baixar

    -- layout: como ler o arquivo
    layout_version      smallint    NOT NULL DEFAULT 1,
    file_encoding       text        NOT NULL DEFAULT 'utf-8-sig',
    field_delimiter     char(1)     NOT NULL DEFAULT ';',
    decimal_separator   char(1)     NOT NULL DEFAULT ',',
    date_format         text        NOT NULL DEFAULT 'DD/MM/YYYY',
    expected_columns    text[]      NOT NULL,

    -- janela coberta
    period_start        date        NOT NULL,
    period_end          date        NOT NULL,

    -- estado da carga
    status              text        NOT NULL DEFAULT 'pending',
    rows_in_file        integer,
    rows_staged         integer,
    rows_rejected       integer,
    facts_inserted      integer,
    checksum_sha256     char(64),
    downloaded_at       timestamptz,
    loaded_at           timestamptz,
    notes               text,

    CONSTRAINT source_files_period_valid
        CHECK (period_start < period_end),
    CONSTRAINT source_files_status_valid
        CHECK (status IN ('pending', 'downloaded', 'staged', 'loaded', 'failed'))
);

COMMENT ON COLUMN etl.source_files.layout_version IS
    'Versão do layout do CSV. 2023-01 e 2025-02 foram perfilados e têm as mesmas '
    '16 colunas na mesma ordem, logo ambos são versão 1. A única diferença é o '
    'CNPJ, mascarado em 2023 (00.003.188/0001-21) e sem máscara em 2025 '
    '(04431113000100) — resolvido na normalização, não no layout.';

COMMENT ON COLUMN etl.source_files.expected_columns IS
    'Cabeçalho esperado, normalizado (sem acento, minúsculo, underscore). A carga '
    'aborta se o arquivo divergir, em vez de carregar coluna trocada em silêncio.';

-- -----------------------------------------------------------------------------
-- Seed: a janela do projeto (2023-01 a 2026-01, 7 semestres)
-- source_url fica nulo de propósito: preencher com a URL real ao baixar cada
-- arquivo, para que a reprodução não dependa de navegar no portal da ANP.
-- -----------------------------------------------------------------------------

INSERT INTO etl.source_files (
    semester_label, local_file_name, expected_columns, period_start, period_end
)
SELECT
    label,
    'ca-' || label || '.csv',
    ARRAY[
        'regiao_sigla', 'estado_sigla', 'municipio', 'revenda', 'cnpj_da_revenda',
        'nome_da_rua', 'numero_rua', 'complemento', 'bairro', 'cep', 'produto',
        'data_da_coleta', 'valor_de_venda', 'valor_de_compra', 'unidade_de_medida',
        'bandeira'
    ],
    start_date,
    end_date
FROM (VALUES
    ('2023-01', DATE '2023-01-01', DATE '2023-07-01'),
    ('2023-02', DATE '2023-07-01', DATE '2024-01-01'),
    ('2024-01', DATE '2024-01-01', DATE '2024-07-01'),
    ('2024-02', DATE '2024-07-01', DATE '2025-01-01'),
    ('2025-01', DATE '2025-01-01', DATE '2025-07-01'),
    ('2025-02', DATE '2025-07-01', DATE '2026-01-01'),
    ('2026-01', DATE '2026-01-01', DATE '2026-07-01')
) AS s(label, start_date, end_date)
ON CONFLICT (semester_label) DO NOTHING;

-- Registra o que já foi perfilado, para não repetir o trabalho.
UPDATE etl.source_files
   SET original_file_name = 'Preços semestrais - AUTOMOTIVOS_2023.01.csv',
       rows_in_file       = 431576,
       notes              = 'Perfilado em docs/perfil-fonte.md. CNPJ com máscara. '
                            'valor_de_compra 100% vazio. Período real 02/01 a 30/06.'
 WHERE semester_label = '2023-01' AND original_file_name IS NULL;

UPDATE etl.source_files
   SET original_file_name = 'Preços semestrais - AUTOMOTIVOS_2025.02.csv',
       rows_in_file       = 384208,
       notes              = 'Perfilado em docs/perfil-fonte.md. CNPJ sem máscara. '
                            'valor_de_compra 100% vazio. Unidade grafada "R$ / m3" '
                            '(sem o expoente que aparece em 2023).'
 WHERE semester_label = '2025-02' AND original_file_name IS NULL;

CREATE INDEX IF NOT EXISTS source_files_status_idx
    ON etl.source_files (status, period_start);
