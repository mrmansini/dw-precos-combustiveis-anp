-- =============================================================================
-- 001_schemas_and_roles.sql
-- Schemas, extensões e papéis do DW de preços de combustíveis (ANP).
-- Idempotente: pode rodar quantas vezes for necessário.
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS etl;
CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS ops;
CREATE SCHEMA IF NOT EXISTS analytics;

COMMENT ON SCHEMA staging   IS 'Landing bruto do CSV: tudo texto, truncado a cada carga.';
COMMENT ON SCHEMA etl       IS 'Catálogo que governa a carga: arquivos, layout, período, status.';
COMMENT ON SCHEMA core      IS 'Modelo integrado: dimensões conformadas e fato particionado.';
COMMENT ON SCHEMA ops       IS 'Saúde da própria execução: runs, migrações, views de health.';
COMMENT ON SCHEMA analytics IS 'Camada de consumo: views e rollups para BI e SQL analítico.';

-- -----------------------------------------------------------------------------
-- Extensões
-- -----------------------------------------------------------------------------

-- btree_gist é obrigatória: a constraint de exclusão do SCD2 em core.dim_station
-- combina igualdade de CNPJ (bpchar) com sobreposição de daterange, e o GiST
-- nativo não indexa bpchar sem ela.
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- pg_stat_statements alimenta docs/performance.md. É opcional: se o papel não
-- puder instalá-la, a migração segue sem ela em vez de falhar.
DO $$
BEGIN
    CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'pg_stat_statements indisponível (%). Seguindo sem ela.', SQLERRM;
END $$;

-- -----------------------------------------------------------------------------
-- Papéis
-- Separação de escrita e leitura: o owner escreve, bi_reader apenas lê.
-- Os GRANTs ficam na 011, depois que todos os objetos existirem.
-- -----------------------------------------------------------------------------

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'bi_reader') THEN
        CREATE ROLE bi_reader NOLOGIN;
        RAISE NOTICE 'Papel bi_reader criado.';
    ELSE
        RAISE NOTICE 'Papel bi_reader já existe.';
    END IF;
END $$;

-- -----------------------------------------------------------------------------
-- Ledger de migrações
-- O runner (src/migrate.py) registra aqui o que já aplicou. As migrações são
-- idempotentes, então o ledger é auditoria, não trava: serve para responder
-- "qual versão do schema está neste banco?" sem inspecionar o catálogo.
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS ops.schema_migrations (
    filename    text        PRIMARY KEY,
    checksum    char(64)    NOT NULL,
    applied_at  timestamptz NOT NULL DEFAULT now(),
    duration_ms integer
);

COMMENT ON TABLE ops.schema_migrations IS
    'Migrações aplicadas. O checksum detecta arquivo editado depois de aplicado.';
