-- stairClimbing, verticalClimber, jacobsLadder, russianTwist (align with app Drift schema v33).

INSERT INTO exercises (name, muscle_group, type, movement_pattern)
VALUES
  ('stairClimbing', 'cardio', 'cardio', NULL),
  ('verticalClimber', 'cardio', 'cardio', NULL),
  ('jacobsLadder', 'cardio', 'cardio', NULL),
  ('russianTwist', 'abs', 'strength', 'isolation')
ON CONFLICT (name) DO NOTHING;

DO $$
DECLARE
  eid INTEGER;
BEGIN
  SELECT id INTO eid FROM exercises WHERE name = 'stairClimbing' LIMIT 1;
  IF eid IS NOT NULL THEN
    INSERT INTO exercise_target_muscles (exercise_id, target_muscle, muscle_region, role)
    SELECT eid, x.tm, NULL::TEXT, x.r
    FROM (VALUES
      ('rectusFemoris', 'primary'),
      ('gastrocnemius', 'primary'),
      ('gluteusMaximus', 'secondary')
    ) AS x(tm, r)
    ON CONFLICT (exercise_id, target_muscle) DO NOTHING;
  END IF;

  SELECT id INTO eid FROM exercises WHERE name = 'verticalClimber' LIMIT 1;
  IF eid IS NOT NULL THEN
    INSERT INTO exercise_target_muscles (exercise_id, target_muscle, muscle_region, role)
    SELECT eid, x.tm, NULL::TEXT, x.r
    FROM (VALUES
      ('hipFlexors', 'primary'),
      ('latissimusDorsi', 'secondary'),
      ('rectusAbdominis', 'secondary')
    ) AS x(tm, r)
    ON CONFLICT (exercise_id, target_muscle) DO NOTHING;
  END IF;

  SELECT id INTO eid FROM exercises WHERE name = 'jacobsLadder' LIMIT 1;
  IF eid IS NOT NULL THEN
    INSERT INTO exercise_target_muscles (exercise_id, target_muscle, muscle_region, role)
    SELECT eid, x.tm, NULL::TEXT, x.r
    FROM (VALUES
      ('hipFlexors', 'primary'),
      ('rectusFemoris', 'secondary'),
      ('gastrocnemius', 'secondary')
    ) AS x(tm, r)
    ON CONFLICT (exercise_id, target_muscle) DO NOTHING;
  END IF;

  SELECT id INTO eid FROM exercises WHERE name = 'russianTwist' LIMIT 1;
  IF eid IS NOT NULL THEN
    INSERT INTO exercise_target_muscles (exercise_id, target_muscle, muscle_region, role)
    SELECT eid, x.tm, NULL::TEXT, x.r
    FROM (VALUES
      ('obliques', 'primary'),
      ('rectusAbdominis', 'secondary'),
      ('transverseAbdominis', 'secondary')
    ) AS x(tm, r)
    ON CONFLICT (exercise_id, target_muscle) DO NOTHING;
  END IF;
END $$;

INSERT INTO catalog_version (version)
SELECT COALESCE((SELECT MAX(version) FROM catalog_version), 0) + 1;
