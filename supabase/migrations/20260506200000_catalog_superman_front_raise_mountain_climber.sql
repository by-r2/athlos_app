-- superman, frontRaise, mountainClimber (align with app Drift schema v32).

INSERT INTO exercises (name, muscle_group, type, movement_pattern)
VALUES
  ('superman', 'back', 'strength', 'isolation'),
  ('frontRaise', 'shoulders', 'strength', 'isolation'),
  ('mountainClimber', 'cardio', 'cardio', NULL)
ON CONFLICT (name) DO NOTHING;

DO $$
DECLARE
  eid INTEGER;
BEGIN
  SELECT id INTO eid FROM exercises WHERE name = 'superman' LIMIT 1;
  IF eid IS NOT NULL THEN
    INSERT INTO exercise_target_muscles (exercise_id, target_muscle, muscle_region, role)
    SELECT eid, x.tm, NULL::TEXT, x.r
    FROM (VALUES
      ('erectorSpinae', 'primary'),
      ('gluteusMaximus', 'secondary'),
      ('bicepsFemoris', 'secondary')
    ) AS x(tm, r)
    ON CONFLICT (exercise_id, target_muscle) DO NOTHING;
  END IF;

  SELECT id INTO eid FROM exercises WHERE name = 'frontRaise' LIMIT 1;
  IF eid IS NOT NULL THEN
    INSERT INTO exercise_target_muscles (exercise_id, target_muscle, muscle_region, role)
    SELECT eid, x.tm, NULL::TEXT, x.r
    FROM (VALUES
      ('anteriorDeltoid', 'primary')
    ) AS x(tm, r)
    ON CONFLICT (exercise_id, target_muscle) DO NOTHING;
  END IF;

  SELECT id INTO eid FROM exercises WHERE name = 'mountainClimber' LIMIT 1;
  IF eid IS NOT NULL THEN
    INSERT INTO exercise_target_muscles (exercise_id, target_muscle, muscle_region, role)
    SELECT eid, x.tm, NULL::TEXT, x.r
    FROM (VALUES
      ('hipFlexors', 'primary'),
      ('rectusAbdominis', 'secondary'),
      ('anteriorDeltoid', 'secondary')
    ) AS x(tm, r)
    ON CONFLICT (exercise_id, target_muscle) DO NOTHING;
  END IF;
END $$;

INSERT INTO catalog_version (version)
SELECT COALESCE((SELECT MAX(version) FROM catalog_version), 0) + 1;
