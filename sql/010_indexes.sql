-- =============================================================================
-- 010_indexes.sql
-- Índice secundário e memória de trabalho, ambos escolhidos por medição.
--
-- Quatro consultas representativas foram medidas em quatro cenários, com cada
-- índice candidato criado sozinho e derrubado em seguida. Os planos completos
-- estão em docs/performance.md e docs/performance-memoria.md.
--
-- RESULTADO
--
--   BRIN em collection_date                 efeito nulo, 0,4 MB     rejeitado
--   B-tree (product_key, collection_date)   4-5% em duas consultas,
--                                           -18% numa terceira,
--                                           91,5 MB                 rejeitado
--   B-tree (station_key, collection_date)   2,15x na análise de
--                                           evento, 46,2 MB         aceito
--   work_mem de 4MB para 16MB               7-9%, sem custo
--                                           de armazenamento        aceito
--
-- POR QUE TÃO POUCO ÍNDICE
--
-- O plano do cenário sem índice mostra que a leitura do fato consome 70 ms dos
-- 450 ms da consulta; o restante é ordenação, junção e cálculo de percentil. As
-- consultas de agregação ampla leem entre 200 mil e 1 milhão de linhas, e o
-- descarte de partições já as encontra rápido. Índice acelera localizar linha,
-- não agregar linha — por isso 91,5 MB de B-tree compraram 5%.
--
-- O BRIN foi rejeitado por motivo estrutural, não por desempenho ruim: ele e o
-- particionamento por intervalo de data resolvem o mesmo problema, e o
-- particionamento age primeiro, no planejamento.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Acesso por posto
--
-- A chave primária é (collection_date, station_key, product_key) e serve bem o
-- acesso por data. A análise de evento entra pelo caminho oposto: um conjunto de
-- postos, cada um com sua própria janela de datas em torno da troca de bandeira.
-- Sem este índice o planejador percorre as treze partições fazendo um laço de
-- Index Scan na chave primária por evento.
--
-- Criado na tabela particionada, o que propaga o índice para todas as partições
-- atuais e futuras.
-- -----------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS fct_price_observation_station_date_idx
    ON core.fct_price_observation (station_key, collection_date);

COMMENT ON INDEX core.fct_price_observation_station_date_idx IS
    'Acesso por conjunto de postos com janela de datas própria. Único índice '
    'secundário aprovado na medição: 2,15x na análise de evento por 46 MB.';

-- -----------------------------------------------------------------------------
-- Memória de trabalho
--
-- Com 4MB, a ordenação de 212 mil linhas da série semanal cai para disco
-- (external merge, 8,7 MB) e a agregação da paridade roda em nove lotes. Com
-- 16MB, as duas ficam em memória. O ganho é modesto — 7 a 9% — mas não custa
-- armazenamento e elimina escrita temporária em disco a cada consulta.
--
-- Aplicado no banco e não na sessão para valer também para as conexões de BI,
-- que não passam pelos scripts deste repositório. Vale a partir da próxima
-- conexão; sessões abertas mantêm o valor anterior.
--
-- 16MB e não mais: work_mem é por operação de ordenação ou hash, não por
-- consulta, então uma consulta com várias dessas operações multiplica o
-- consumo. A medição mostrou que 64MB e 256MB não trazem ganho adicional.
-- -----------------------------------------------------------------------------

DO $$
BEGIN
    EXECUTE format('ALTER DATABASE %I SET work_mem = %L',
                   current_database(), '16MB');
    RAISE NOTICE 'work_mem do banco definido em 16MB (vale a partir da próxima conexão).';
END $$;

-- -----------------------------------------------------------------------------
-- Estatísticas
-- Índice recém-criado só é considerado pelo planejador com estatísticas
-- atualizadas na tabela.
-- -----------------------------------------------------------------------------

ANALYZE core.fct_price_observation;
ANALYZE core.dim_station;
