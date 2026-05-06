-- frontSquat + gobletSquat (align with app Drift schema v31).
-- Clients sync exercises + exercise_target_muscles only.

INSERT INTO exercises (name, muscle_group, type, movement_pattern)
VALUES
  ('frontSquat', 'quadriceps', 'strength', 'squat'),
  ('gobletSquat', 'quadriceps', 'strength', 'squat')
ON CONFLICT (name) DO NOTHING;

DO $$
DECLARE
  eid INTEGER;
BEGIN
  SELECT id INTO eid FROM exercises WHERE name = 'frontSquat' LIMIT 1;
  IF eid IS NOT NULL THEN
    INSERT INTO exercise_target_muscles (exercise_id, target_muscle, muscle_region, role)
    SELECT eid, x.tm, NULL::TEXT, x.r
    FROM (VALUES
      ('rectusFemoris', 'primary'),
      ('vastusLateralis', 'primary'),
      ('vastusMedialis', 'primary'),
      ('gluteusMaximus', 'secondary'),
      ('bicepsFemoris', 'secondary')
    ) AS x(tm, r)
    ON CONFLICT (exercise_id, target_muscle) DO NOTHING;
  END IF;

  SELECT id INTO eid FROM exercises WHERE name = 'gobletSquat' LIMIT 1;
  IF eid IS NOT NULL THEN
    INSERT INTO exercise_target_muscles (exercise_id, target_muscle, muscle_region, role)
    SELECT eid, x.tm, NULL::TEXT, x.r
    FROM (VALUES
      ('rectusFemoris', 'primary'),
      ('vastusLateralis', 'primary'),
      ('vastusMedialis', 'primary'),
      ('gluteusMaximus', 'secondary'),
      ('bicepsFemoris', 'secondary')
    ) AS x(tm, r)
    ON CONFLICT (exercise_id, target_muscle) DO NOTHING;
  END IF;
END $$;

INSERT INTO catalog_version (version)
SELECT COALESCE((SELECT MAX(version) FROM catalog_version), 0) + 1;
