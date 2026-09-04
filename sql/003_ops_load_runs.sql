-- =============================================================================
-- 003_ops_load_runs.sql
-- Saúde da própria execução: uma linha por etapa de carga, a view de health com
-- duração e taxa de rejeição, e a view que expõe execução presa em 'running'.
-- =============================================================================

CREATE TABLE IF NOT EXISTS ops.load_runs (
    run_id           bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_file_id   integer     REFERENCES etl.source_files (source_file_id),
    step             text        NOT NULL,
    started_at       timestamptz NOT NULL DEFAULT now(),
    finished_at      timestamptz,
    status           text        NOT NULL DEFAULT 'running',

    rows_in          integer,
    rows_out         integer,
    rows_rejected    integer,
    stations_opened  integer,   -- versões abertas no SCD2
    stations_closed  integer,   -- versões encerradas no SCD2
    brands_new       integer,   -- bandeiras desconhecidas criadas na carga
    error_detail     text,
    client_host      text        DEFAULT current_setting('application_name', true),

    CONSTRAINT load_runs_step_valid
        CHECK (step IN ('stage', 'transform', 'load_stations', 'load_facts', 'refresh')),
    CONSTRAINT load_runs_status_valid
        CHECK (status IN ('running', 'success', 'failed')),
    CONSTRAINT load_runs_finished_when_done
        CHECK (status = 'running' OR finished_at IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS load_runs_recent_idx
    ON ops.load_runs (started_at DESC);

CREATE INDEX IF NOT EXISTS load_runs_open_idx
    ON ops.load_runs (started_at) WHERE status = 'running';

-- -----------------------------------------------------------------------------
-- Saúde da carga. O fuso é resolvido aqui, na camada de consumo: o armazenamento
-- permanece em timestamptz (UTC) e só a apresentação converte para BRT.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE VIEW ops.v_load_health AS
SELECT
    r.run_id,
    f.semester_label,
    r.step,
    r.status,
    (r.started_at  AT TIME ZONE 'America/Sao_Paulo') AS started_at_brt,
    (r.finished_at AT TIME ZONE 'America/Sao_Paulo') AS finished_at_brt,
    round(EXTRACT(epoch FROM (COALESCE(r.finished_at, now()) - r.started_at))::numeric, 1)
        AS duration_seconds,
    r.rows_in,
    r.rows_out,
    r.rows_rejected,
    CASE WHEN COALESCE(r.rows_in, 0) = 0 THEN NULL
         ELSE round(100.0 * COALESCE(r.rows_rejected, 0) / r.rows_in, 3)
    END AS rejected_pct,
    r.stations_opened,
    r.stations_closed,
    r.brands_new,
    r.error_detail
FROM ops.load_runs r
LEFT JOIN etl.source_files f USING (source_file_id)
ORDER BY r.started_at DESC;

COMMENT ON VIEW ops.v_load_health IS
    'Última milha da observabilidade da carga: duração, volume, rejeição e '
    'movimentação do SCD2 por execução.';

-- Execuções órfãs: processo interrompido deixa a linha presa em 'running'
-- indefinidamente. A anomalia tem consulta própria em vez de passar despercebida.
CREATE OR REPLACE VIEW ops.v_stuck_runs AS
SELECT
    run_id,
    source_file_id,
    step,
    (started_at AT TIME ZONE 'America/Sao_Paulo') AS started_at_brt,
    round(EXTRACT(epoch FROM (now() - started_at)) / 60.0, 1) AS running_for_minutes
FROM ops.load_runs
WHERE status = 'running'
  AND started_at < now() - interval '30 minutes'
ORDER BY started_at;

COMMENT ON VIEW ops.v_stuck_runs IS
    'Execuções em running há mais de 30 min — quase sempre processo interrompido, '
    'não carga lenta.';
