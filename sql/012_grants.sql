-- =============================================================================
-- 012_grants.sql
-- Permissões de leitura.
--
-- bi_reader é um conjunto de permissões, não um usuário: foi criado NOLOGIN e
-- não abre conexão. O usuário que o BI usa é criado à parte, com senha, e recebe
-- o papel — assim é possível trocar, revogar ou acrescentar usuários de leitura
-- sem tocar nas permissões, que ficam no papel.
--
-- Concede acesso a core, analytics e ops. Não concede a staging nem a etl:
-- conteúdo bruto e mecânica de carga não interessam ao consumo e a ausência de
-- GRANT já os torna inacessíveis.
-- =============================================================================

GRANT USAGE ON SCHEMA core      TO bi_reader;
GRANT USAGE ON SCHEMA analytics TO bi_reader;
GRANT USAGE ON SCHEMA ops       TO bi_reader;

GRANT SELECT ON ALL TABLES IN SCHEMA core      TO bi_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA analytics TO bi_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA ops       TO bi_reader;

-- Views materializadas entram em ALL TABLES, mas a concessão explícita deixa a
-- intenção registrada caso a lista acima seja reduzida no futuro.
GRANT SELECT ON analytics.mv_weekly_price TO bi_reader;

-- -----------------------------------------------------------------------------
-- Objetos criados depois desta migração
--
-- Sem isto, toda view ou tabela criada a partir de agora nasce invisível para o
-- bi_reader, e o sintoma aparece no lugar errado: um painel que funcionava para
-- de funcionar depois de uma migração que nada tinha a ver com permissão.
--
-- FOR ROLE precisa nomear quem cria os objetos, e o nome do papel dono varia
-- conforme o provisionamento do banco — daí o current_user resolvido em tempo
-- de execução.
-- -----------------------------------------------------------------------------

DO $$
BEGIN
    EXECUTE format(
        'ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA core, analytics, ops '
        'GRANT SELECT ON TABLES TO bi_reader', current_user);
    EXECUTE format(
        'ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA analytics '
        'GRANT SELECT ON SEQUENCES TO bi_reader', current_user);
    RAISE NOTICE 'Privilégios padrão definidos para objetos criados por %.', current_user;
END $$;

-- -----------------------------------------------------------------------------
-- Verificação
-- Lista o que o papel enxerga. Um objeto de consumo ausente daqui é erro de
-- concessão, não de modelagem.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE VIEW ops.v_bi_reader_access AS
SELECT
    table_schema,
    table_name,
    table_type
FROM information_schema.table_privileges
JOIN information_schema.tables USING (table_schema, table_name)
WHERE grantee = 'bi_reader' AND privilege_type = 'SELECT'
ORDER BY table_schema, table_name;

COMMENT ON VIEW ops.v_bi_reader_access IS
    'Objetos legíveis pelo papel bi_reader. Views materializadas não aparecem em '
    'information_schema e precisam ser conferidas em pg_class.';
