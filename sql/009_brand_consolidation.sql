-- =============================================================================
-- 009_brand_consolidation.sql
-- Curadoria do catálogo de bandeiras, feita depois da carga dos sete semestres
-- com a contagem de postos de cada uma em mãos.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Registro da revisão
-- needs_review sozinho não diz se a bandeira foi analisada e aprovada ou se
-- nunca foi olhada. reviewed_at separa as duas situações.
-- -----------------------------------------------------------------------------

ALTER TABLE core.dim_brand
    ADD COLUMN IF NOT EXISTS reviewed_at timestamptz;

COMMENT ON COLUMN core.dim_brand.reviewed_at IS
    'Quando a bandeira foi analisada e confirmada como empresa distinta. Nulo '
    'com needs_review false só ocorre nas semeadas pela migração inicial.';

-- -----------------------------------------------------------------------------
-- Consolidação: ATEM' S
--
-- A semente escreveu ATEM'S; a fonte grafa ATEM' S, com espaço antes do S.
-- Resultado: a canônica ficou sem nenhum posto e a resolução automática criou
-- uma segunda entrada para a mesma empresa. Os postos são reapontados para a
-- canônica e a grafia da fonte vira alias.
--
-- Reapontar brand_key recalcula attribute_hash das versões afetadas, o que é
-- inofensivo aqui: o hash só é comparado dentro de uma carga, e a canônica não
-- tinha postos com que confundir.
-- -----------------------------------------------------------------------------

DO $$
DECLARE
    v_canonical integer;
    v_duplicate integer;
    v_moved     integer := 0;
BEGIN
    SELECT brand_key INTO v_canonical FROM core.dim_brand WHERE brand_name = 'ATEM''S';
    SELECT brand_key INTO v_duplicate FROM core.dim_brand WHERE brand_name = 'ATEM'' S';

    IF v_canonical IS NULL OR v_duplicate IS NULL THEN
        RAISE NOTICE 'Consolidação ATEM já aplicada.';
        RETURN;
    END IF;

    UPDATE core.dim_station
       SET brand_key = v_canonical
     WHERE brand_key = v_duplicate;
    GET DIAGNOSTICS v_moved = ROW_COUNT;

    UPDATE core.brand_alias
       SET brand_key = v_canonical,
           is_rename = false,
           note      = 'grafia da fonte, com espaço antes do S'
     WHERE brand_key = v_duplicate;

    DELETE FROM core.dim_brand WHERE brand_key = v_duplicate;

    RAISE NOTICE '% versão(ões) de posto reapontada(s) para ATEM''S.', v_moved;
END $$;

-- -----------------------------------------------------------------------------
-- Bandeiras analisadas e confirmadas como empresas distintas
--
-- A lista é explícita, e não um UPDATE em tudo que estivesse pendente, porque
-- esta migração é reaplicada a cada mudança de checksum: um filtro genérico
-- marcaria como revisada qualquer bandeira que a fonte trouxesse depois, sem
-- que ninguém a tivesse olhado.
-- -----------------------------------------------------------------------------

UPDATE core.dim_brand
   SET needs_review = false,
       reviewed_at  = coalesce(reviewed_at, now())
 WHERE needs_review
   AND brand_name IN (
        'AIR BP', 'AMERICANOIL', 'ATLÂNTICA', 'CIAPETRO', 'D`MAIS', 'DIBRAPE',
        'ESTRADA', 'FAN', 'FEDERAL ENERGIA', 'GP', 'IDAZA', 'LARCO',
        'MASUT DISTRIBUIDORA', 'MONTEPETRO', 'ON PETRO', 'PELIKANO',
        'PETROBAHIA', 'PETROBRASIL', 'PETROSERRA', 'PETROX DISTRIBUIDORA',
        'POTENCIAL', 'RDP ENERGIA', 'REJAILE', 'RIO BRANCO', 'ROYAL FIC',
        'RZD DISTRIBUIDORA', 'SETTA DISTRIBUIDORA', 'SIMARELLI', 'SMALL',
        'TDC DISTRIBUIDORA', 'TORRAO', 'UNI', 'WALENDOWSKY', 'WATT'
   );

-- -----------------------------------------------------------------------------
-- Bandeiras semeadas que a fonte nunca usou
--
-- Sem postos e sem alias além do próprio nome, elas poluem qualquer listagem do
-- catálogo. Só saem as que não têm nenhuma versão de posto apontando para elas.
-- -----------------------------------------------------------------------------

DELETE FROM core.brand_alias a
 USING core.dim_brand b
 WHERE a.brand_key = b.brand_key
   AND b.reviewed_at IS NULL
   AND NOT b.needs_review
   AND NOT EXISTS (SELECT 1 FROM core.dim_station s WHERE s.brand_key = b.brand_key)
   AND a.alias_text = b.brand_name;

DELETE FROM core.dim_brand b
 WHERE b.reviewed_at IS NULL
   AND NOT b.needs_review
   AND NOT EXISTS (SELECT 1 FROM core.dim_station s WHERE s.brand_key = b.brand_key)
   AND NOT EXISTS (SELECT 1 FROM core.brand_alias a WHERE a.brand_key = b.brand_key);

-- -----------------------------------------------------------------------------
-- Presença de cada bandeira ao longo do tempo
-- Serve à revisão do catálogo: bandeira que some numa data e outra que aparece
-- na mesma data, com contagens parecidas, é candidata a renomeação.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE VIEW ops.v_brand_timeline AS
SELECT
    b.brand_name,
    count(DISTINCT s.cnpj)                                   AS postos,
    min(s.valid_from)                                        AS primeira_versao,
    max(s.valid_from)                                        AS ultima_versao_aberta,
    max(CASE WHEN s.is_current THEN s.valid_from END)         AS ultima_vigente,
    count(*) FILTER (WHERE s.is_current)                      AS versoes_vigentes,
    b.needs_review,
    b.reviewed_at
FROM core.dim_brand b
LEFT JOIN core.dim_station s ON s.brand_key = b.brand_key
GROUP BY b.brand_key, b.brand_name, b.needs_review, b.reviewed_at
ORDER BY postos DESC, b.brand_name;
