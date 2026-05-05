-- Align remote catalog `exercises.name` with app schema v30 (Drift migration + backup import).
-- Source of truth in Dart: `lib/core/database/exercise_migration_maps.dart`
-- Safe to run on DBs seeded from `20260226000000_create_catalog.sql`. Re-run sections are OK on no-op pairs.

-- ── Phase 1: renames (old key → canonical) ─────────────────────────────────

UPDATE exercises SET name = 'benchPress' WHERE name = 'flatBarbellBenchPress';
UPDATE exercises SET name = 'inclineBenchPress' WHERE name = 'inclineBarbellBenchPress';
UPDATE exercises SET name = 'declineBenchPress' WHERE name = 'declineBarbellBenchPress';
UPDATE exercises SET name = 'chestFly' WHERE name = 'dumbbellFly';
UPDATE exercises SET name = 'chestPress' WHERE name = 'machineChestPress';
UPDATE exercises SET name = 'bentOverRow' WHERE name = 'barbellRow';
UPDATE exercises SET name = 'singleArmRow' WHERE name = 'dumbbellRow';
UPDATE exercises SET name = 'seatedRow' WHERE name = 'seatedCableRow';
UPDATE exercises SET name = 'underhandRow' WHERE name = 'underhandBarbellRow';
UPDATE exercises SET name = 'shrug' WHERE name = 'dumbbellShrug';
UPDATE exercises SET name = 'bicepsCurl' WHERE name = 'barbellCurl';
UPDATE exercises SET name = 'alternatingCurl' WHERE name = 'dumbbellCurl';
UPDATE exercises SET name = 'inclineCurl' WHERE name = 'inclineDumbbellCurl';
UPDATE exercises SET name = 'backSquat' WHERE name = 'barbellSquat';
UPDATE exercises SET name = 'gluteKickback' WHERE name = 'cableKickback';
UPDATE exercises SET name = 'hipAdduction' WHERE name = 'adductorMachine';
UPDATE exercises SET name = 'hipAbduction' WHERE name = 'abductorMachine';

-- ── Phase 2: equipment-only merges (loser rows removed when both exist) ───

CREATE OR REPLACE FUNCTION _athlos_merge_catalog_exercises(winner INTEGER, loser INTEGER)
RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
  IF winner IS NULL OR loser IS NULL OR winner = loser THEN RETURN; END IF;

  DELETE FROM exercise_target_muscles etm
  WHERE etm.exercise_id = loser AND EXISTS (
    SELECT 1 FROM exercise_target_muscles k
    WHERE k.exercise_id = winner AND k.target_muscle = etm.target_muscle);
  UPDATE exercise_target_muscles SET exercise_id = winner WHERE exercise_id = loser;

  DELETE FROM exercise_variations ev
  WHERE ev.exercise_id = loser AND EXISTS (
    SELECT 1 FROM exercise_variations ev2
    WHERE ev2.exercise_id = winner AND ev2.variation_id = ev.variation_id);
  UPDATE exercise_variations SET exercise_id = winner WHERE exercise_id = loser;

  DELETE FROM exercise_variations ev
  WHERE ev.variation_id = loser AND EXISTS (
    SELECT 1 FROM exercise_variations ev2
    WHERE ev2.exercise_id = ev.exercise_id AND ev2.variation_id = winner);
  UPDATE exercise_variations SET variation_id = winner WHERE variation_id = loser;

  DELETE FROM exercise_equipments ee
  WHERE ee.exercise_id = loser AND EXISTS (
    SELECT 1 FROM exercise_equipments ee2
    WHERE ee2.exercise_id = winner AND ee2.equipment_id = ee.equipment_id);
  UPDATE exercise_equipments SET exercise_id = winner WHERE exercise_id = loser;

  DELETE FROM exercises WHERE id = loser;
END;
$$;

DO $$
DECLARE
  w INTEGER;
  l INTEGER;
BEGIN
  SELECT id INTO w FROM exercises WHERE name = 'bicepsCurl' LIMIT 1;
  SELECT id INTO l FROM exercises WHERE name = 'ezBarCurl' LIMIT 1;
  PERFORM _athlos_merge_catalog_exercises(w, l);

  SELECT id INTO w FROM exercises WHERE name = 'preacherCurl' LIMIT 1;
  SELECT id INTO l FROM exercises WHERE name = 'dumbbellPreacherCurl' LIMIT 1;
  PERFORM _athlos_merge_catalog_exercises(w, l);

  SELECT id INTO w FROM exercises WHERE name = 'preacherCurl' LIMIT 1;
  SELECT id INTO l FROM exercises WHERE name = 'machinePreacherCurl' LIMIT 1;
  PERFORM _athlos_merge_catalog_exercises(w, l);

  SELECT id INTO w FROM exercises WHERE name = 'tricepsPushdown' LIMIT 1;
  SELECT id INTO l FROM exercises WHERE name = 'ropeTricepsPushdown' LIMIT 1;
  PERFORM _athlos_merge_catalog_exercises(w, l);
END;
$$;

DROP FUNCTION IF EXISTS _athlos_merge_catalog_exercises(INTEGER, INTEGER);

-- ── Phase 3: bump catalog version → clients pull sync again ───────────────

INSERT INTO catalog_version (version)
SELECT COALESCE((SELECT MAX(version) FROM catalog_version), 0) + 1;
