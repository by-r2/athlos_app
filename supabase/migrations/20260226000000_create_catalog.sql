-- Catalog tables for verified exercises and equipment.
-- Read-only public access (no auth required).

CREATE TABLE equipments (
  id          SERIAL PRIMARY KEY,
  name        TEXT NOT NULL UNIQUE,
  category    TEXT NOT NULL,
  is_verified BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE exercises (
  id               SERIAL PRIMARY KEY,
  name             TEXT NOT NULL UNIQUE,
  muscle_group     TEXT NOT NULL,
  type             TEXT NOT NULL DEFAULT 'strength',
  movement_pattern TEXT,
  description      TEXT,
  is_verified      BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE exercise_target_muscles (
  exercise_id   INTEGER NOT NULL REFERENCES exercises(id) ON DELETE CASCADE,
  target_muscle TEXT NOT NULL,
  muscle_region TEXT,
  role          TEXT NOT NULL DEFAULT 'primary',
  PRIMARY KEY (exercise_id, target_muscle)
);

CREATE TABLE exercise_equipments (
  exercise_id  INTEGER NOT NULL REFERENCES exercises(id) ON DELETE CASCADE,
  equipment_id INTEGER NOT NULL REFERENCES equipments(id) ON DELETE CASCADE,
  PRIMARY KEY (exercise_id, equipment_id)
);

CREATE TABLE exercise_variations (
  exercise_id  INTEGER NOT NULL REFERENCES exercises(id) ON DELETE CASCADE,
  variation_id INTEGER NOT NULL REFERENCES exercises(id) ON DELETE CASCADE,
  PRIMARY KEY (exercise_id, variation_id)
);

CREATE TABLE catalog_version (
  version    INTEGER NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO catalog_version (version) VALUES (1);

-- ── Equipment seed ──

INSERT INTO equipments (name, category) VALUES
  ('barbell', 'freeWeights'),
  ('dumbbell', 'freeWeights'),
  ('kettlebell', 'freeWeights'),
  ('ezBar', 'freeWeights'),
  ('weightPlates', 'freeWeights'),
  ('cableMachine', 'machines'),
  ('smithMachine', 'machines'),
  ('legPressMachine', 'machines'),
  ('latPulldownMachine', 'machines'),
  ('chestPressMachine', 'machines'),
  ('pecDeckMachine', 'machines'),
  ('legExtensionMachine', 'machines'),
  ('legCurlMachine', 'machines'),
  ('hackSquatMachine', 'machines'),
  ('adductorMachine', 'machines'),
  ('abductorMachine', 'machines'),
  ('pullUpBar', 'structures'),
  ('dipStation', 'structures'),
  ('gymnasticRings', 'structures'),
  ('suspensionTrainer', 'structures'),
  ('flatBench', 'accessories'),
  ('adjustableBench', 'accessories'),
  ('squatRack', 'accessories'),
  ('resistanceBands', 'accessories'),
  ('abWheel', 'accessories'),
  ('medicineBall', 'accessories'),
  ('battleRope', 'accessories'),
  ('foamRoller', 'accessories'),
  ('treadmill', 'cardio'),
  ('stationaryBike', 'cardio'),
  ('rowingMachine', 'cardio'),
  ('elliptical', 'cardio'),
  ('jumpRope', 'cardio');

-- ── Exercise seed ──

INSERT INTO exercises (name, muscle_group, type, movement_pattern) VALUES
  ('flatBarbellBenchPress', 'chest', 'strength', 'push'),
  ('inclineBarbellBenchPress', 'chest', 'strength', 'push'),
  ('dumbbellFly', 'chest', 'strength', 'isolation'),
  ('pushUp', 'chest', 'strength', 'push'),
  ('cableCrossover', 'chest', 'strength', 'isolation'),
  ('machineChestPress', 'chest', 'strength', 'push'),
  ('inclineDumbbellPress', 'chest', 'strength', 'push'),
  ('declinePushUp', 'chest', 'strength', 'push'),
  ('inclinePushUp', 'chest', 'strength', 'push'),
  ('kneePushUp', 'chest', 'strength', 'push'),
  ('pullUp', 'back', 'strength', 'pull'),
  ('barbellRow', 'back', 'strength', 'pull'),
  ('latPulldown', 'back', 'strength', 'pull'),
  ('seatedCableRow', 'back', 'strength', 'pull'),
  ('dumbbellRow', 'back', 'strength', 'pull'),
  ('chinUp', 'back', 'strength', 'pull'),
  ('invertedRow', 'back', 'strength', 'pull'),
  ('dumbbellShrug', 'back', 'strength', 'isolation'),
  ('overheadPress', 'shoulders', 'strength', 'push'),
  ('lateralRaise', 'shoulders', 'strength', 'isolation'),
  ('facePull', 'shoulders', 'strength', 'pull'),
  ('arnoldPress', 'shoulders', 'strength', 'push'),
  ('rearDeltFly', 'shoulders', 'strength', 'isolation'),
  ('pikePushUp', 'shoulders', 'strength', 'push'),
  ('barbellCurl', 'biceps', 'strength', 'isolation'),
  ('dumbbellCurl', 'biceps', 'strength', 'isolation'),
  ('hammerCurl', 'biceps', 'strength', 'isolation'),
  ('preacherCurl', 'biceps', 'strength', 'isolation'),
  ('tricepsPushdown', 'triceps', 'strength', 'isolation'),
  ('skullCrusher', 'triceps', 'strength', 'isolation'),
  ('overheadTricepsExtension', 'triceps', 'strength', 'isolation'),
  ('diamondPushUp', 'triceps', 'strength', 'push'),
  ('dip', 'triceps', 'strength', 'push'),
  ('barbellSquat', 'quadriceps', 'strength', 'squat'),
  ('legPress', 'quadriceps', 'strength', 'squat'),
  ('lunge', 'quadriceps', 'strength', 'lunge'),
  ('bulgarianSplitSquat', 'quadriceps', 'strength', 'lunge'),
  ('legExtension', 'quadriceps', 'strength', 'isolation'),
  ('hackSquat', 'quadriceps', 'strength', 'squat'),
  ('romanianDeadlift', 'hamstrings', 'strength', 'hinge'),
  ('nordicCurl', 'hamstrings', 'strength', 'isolation'),
  ('legCurl', 'hamstrings', 'strength', 'isolation'),
  ('hipThrust', 'glutes', 'strength', 'hinge'),
  ('gluteBridge', 'glutes', 'strength', 'hinge'),
  ('cableKickback', 'glutes', 'strength', 'isolation'),
  ('adductorMachine', 'adductors', 'strength', 'isolation'),
  ('abductorMachine', 'glutes', 'strength', 'isolation'),
  ('standingCalfRaise', 'calves', 'strength', 'isolation'),
  ('seatedCalfRaise', 'calves', 'strength', 'isolation'),
  ('crunch', 'abs', 'strength', 'isolation'),
  ('plank', 'abs', 'strength', NULL),
  ('hangingLegRaise', 'abs', 'strength', 'isolation'),
  ('abWheelRollout', 'abs', 'strength', NULL),
  ('wristCurl', 'forearms', 'strength', 'isolation'),
  ('reverseWristCurl', 'forearms', 'strength', 'isolation'),
  ('deadlift', 'fullBody', 'strength', 'hinge'),
  ('burpee', 'fullBody', 'strength', NULL),
  ('treadmillRun', 'cardio', 'cardio', NULL),
  ('stationaryBike', 'cardio', 'cardio', NULL),
  ('rowingMachine', 'cardio', 'cardio', NULL),
  ('elliptical', 'cardio', 'cardio', NULL),
  ('jumpRope', 'cardio', 'cardio', NULL),
  ('jumpingJacks', 'cardio', 'cardio', NULL);

-- ── Target muscles seed ──

-- Helper: use exercise name to resolve IDs
DO $$
DECLARE
  eid INTEGER;
BEGIN
  -- flatBarbellBenchPress
  SELECT id INTO eid FROM exercises WHERE name = 'flatBarbellBenchPress';
  INSERT INTO exercise_target_muscles VALUES (eid, 'pectoralisMajor', 'mid', 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'anteriorDeltoid', NULL, 'secondary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'tricepsBrachii', NULL, 'secondary');

  -- inclineBarbellBenchPress
  SELECT id INTO eid FROM exercises WHERE name = 'inclineBarbellBenchPress';
  INSERT INTO exercise_target_muscles VALUES (eid, 'pectoralisMajor', 'upper', 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'anteriorDeltoid', NULL, 'secondary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'tricepsBrachii', NULL, 'secondary');

  -- dumbbellFly
  SELECT id INTO eid FROM exercises WHERE name = 'dumbbellFly';
  INSERT INTO exercise_target_muscles VALUES (eid, 'pectoralisMajor', 'mid', 'primary');

  -- pushUp
  SELECT id INTO eid FROM exercises WHERE name = 'pushUp';
  INSERT INTO exercise_target_muscles VALUES (eid, 'pectoralisMajor', 'mid', 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'anteriorDeltoid', NULL, 'secondary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'tricepsBrachii', NULL, 'secondary');

  -- cableCrossover
  SELECT id INTO eid FROM exercises WHERE name = 'cableCrossover';
  INSERT INTO exercise_target_muscles VALUES (eid, 'pectoralisMajor', 'mid', 'primary');

  -- machineChestPress
  SELECT id INTO eid FROM exercises WHERE name = 'machineChestPress';
  INSERT INTO exercise_target_muscles VALUES (eid, 'pectoralisMajor', 'mid', 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'tricepsBrachii', NULL, 'secondary');

  -- inclineDumbbellPress
  SELECT id INTO eid FROM exercises WHERE name = 'inclineDumbbellPress';
  INSERT INTO exercise_target_muscles VALUES (eid, 'pectoralisMajor', 'upper', 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'anteriorDeltoid', NULL, 'secondary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'tricepsBrachii', NULL, 'secondary');

  -- declinePushUp
  SELECT id INTO eid FROM exercises WHERE name = 'declinePushUp';
  INSERT INTO exercise_target_muscles VALUES (eid, 'pectoralisMajor', 'upper', 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'anteriorDeltoid', NULL, 'secondary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'tricepsBrachii', NULL, 'secondary');

  -- inclinePushUp
  SELECT id INTO eid FROM exercises WHERE name = 'inclinePushUp';
  INSERT INTO exercise_target_muscles VALUES (eid, 'pectoralisMajor', 'lower', 'primary');

  -- kneePushUp
  SELECT id INTO eid FROM exercises WHERE name = 'kneePushUp';
  INSERT INTO exercise_target_muscles VALUES (eid, 'pectoralisMajor', 'mid', 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'anteriorDeltoid', NULL, 'secondary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'tricepsBrachii', NULL, 'secondary');

  -- pullUp
  SELECT id INTO eid FROM exercises WHERE name = 'pullUp';
  INSERT INTO exercise_target_muscles VALUES (eid, 'latissimusDorsi', NULL, 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'bicepsBrachii', NULL, 'secondary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'rhomboids', NULL, 'secondary');

  -- barbellRow
  SELECT id INTO eid FROM exercises WHERE name = 'barbellRow';
  INSERT INTO exercise_target_muscles VALUES (eid, 'latissimusDorsi', NULL, 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'rhomboids', NULL, 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'rearDeltoid', NULL, 'secondary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'bicepsBrachii', NULL, 'secondary');

  -- latPulldown
  SELECT id INTO eid FROM exercises WHERE name = 'latPulldown';
  INSERT INTO exercise_target_muscles VALUES (eid, 'latissimusDorsi', NULL, 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'bicepsBrachii', NULL, 'secondary');

  -- seatedCableRow
  SELECT id INTO eid FROM exercises WHERE name = 'seatedCableRow';
  INSERT INTO exercise_target_muscles VALUES (eid, 'rhomboids', NULL, 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'latissimusDorsi', NULL, 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'rearDeltoid', NULL, 'secondary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'bicepsBrachii', NULL, 'secondary');

  -- dumbbellRow
  SELECT id INTO eid FROM exercises WHERE name = 'dumbbellRow';
  INSERT INTO exercise_target_muscles VALUES (eid, 'latissimusDorsi', NULL, 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'rhomboids', NULL, 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'bicepsBrachii', NULL, 'secondary');

  -- chinUp
  SELECT id INTO eid FROM exercises WHERE name = 'chinUp';
  INSERT INTO exercise_target_muscles VALUES (eid, 'latissimusDorsi', NULL, 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'bicepsBrachii', NULL, 'secondary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'rhomboids', NULL, 'secondary');

  -- invertedRow
  SELECT id INTO eid FROM exercises WHERE name = 'invertedRow';
  INSERT INTO exercise_target_muscles VALUES (eid, 'rhomboids', NULL, 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'latissimusDorsi', NULL, 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'rearDeltoid', NULL, 'secondary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'bicepsBrachii', NULL, 'secondary');

  -- dumbbellShrug
  SELECT id INTO eid FROM exercises WHERE name = 'dumbbellShrug';
  INSERT INTO exercise_target_muscles VALUES (eid, 'trapezius', NULL, 'primary');

  -- overheadPress
  SELECT id INTO eid FROM exercises WHERE name = 'overheadPress';
  INSERT INTO exercise_target_muscles VALUES (eid, 'anteriorDeltoid', NULL, 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'lateralDeltoid', NULL, 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'tricepsBrachii', NULL, 'secondary');

  -- lateralRaise
  SELECT id INTO eid FROM exercises WHERE name = 'lateralRaise';
  INSERT INTO exercise_target_muscles VALUES (eid, 'lateralDeltoid', NULL, 'primary');

  -- facePull
  SELECT id INTO eid FROM exercises WHERE name = 'facePull';
  INSERT INTO exercise_target_muscles VALUES (eid, 'rearDeltoid', NULL, 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'rhomboids', NULL, 'secondary');

  -- arnoldPress
  SELECT id INTO eid FROM exercises WHERE name = 'arnoldPress';
  INSERT INTO exercise_target_muscles VALUES (eid, 'anteriorDeltoid', NULL, 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'lateralDeltoid', NULL, 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'tricepsBrachii', NULL, 'secondary');

  -- rearDeltFly
  SELECT id INTO eid FROM exercises WHERE name = 'rearDeltFly';
  INSERT INTO exercise_target_muscles VALUES (eid, 'rearDeltoid', NULL, 'primary');

  -- pikePushUp
  SELECT id INTO eid FROM exercises WHERE name = 'pikePushUp';
  INSERT INTO exercise_target_muscles VALUES (eid, 'anteriorDeltoid', NULL, 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'lateralDeltoid', NULL, 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'tricepsBrachii', NULL, 'secondary');

  -- barbellCurl
  SELECT id INTO eid FROM exercises WHERE name = 'barbellCurl';
  INSERT INTO exercise_target_muscles VALUES (eid, 'bicepsBrachii', 'longHead', 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'brachialis', NULL, 'secondary');

  -- dumbbellCurl
  SELECT id INTO eid FROM exercises WHERE name = 'dumbbellCurl';
  INSERT INTO exercise_target_muscles VALUES (eid, 'bicepsBrachii', NULL, 'primary');

  -- hammerCurl
  SELECT id INTO eid FROM exercises WHERE name = 'hammerCurl';
  INSERT INTO exercise_target_muscles VALUES (eid, 'brachialis', NULL, 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'brachioradialis', NULL, 'primary');

  -- preacherCurl
  SELECT id INTO eid FROM exercises WHERE name = 'preacherCurl';
  INSERT INTO exercise_target_muscles VALUES (eid, 'bicepsBrachii', 'shortHead', 'primary');

  -- tricepsPushdown
  SELECT id INTO eid FROM exercises WHERE name = 'tricepsPushdown';
  INSERT INTO exercise_target_muscles VALUES (eid, 'tricepsBrachii', 'lateralHead', 'primary');

  -- skullCrusher
  SELECT id INTO eid FROM exercises WHERE name = 'skullCrusher';
  INSERT INTO exercise_target_muscles VALUES (eid, 'tricepsBrachii', 'longHead', 'primary');

  -- overheadTricepsExtension
  SELECT id INTO eid FROM exercises WHERE name = 'overheadTricepsExtension';
  INSERT INTO exercise_target_muscles VALUES (eid, 'tricepsBrachii', 'longHead', 'primary');

  -- diamondPushUp
  SELECT id INTO eid FROM exercises WHERE name = 'diamondPushUp';
  INSERT INTO exercise_target_muscles VALUES (eid, 'tricepsBrachii', NULL, 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'pectoralisMajor', NULL, 'secondary');

  -- dip
  SELECT id INTO eid FROM exercises WHERE name = 'dip';
  INSERT INTO exercise_target_muscles VALUES (eid, 'tricepsBrachii', NULL, 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'pectoralisMajor', NULL, 'secondary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'anteriorDeltoid', NULL, 'secondary');

  -- barbellSquat
  SELECT id INTO eid FROM exercises WHERE name = 'barbellSquat';
  INSERT INTO exercise_target_muscles VALUES (eid, 'rectusFemoris', NULL, 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'vastusLateralis', NULL, 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'vastusMedialis', NULL, 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'gluteusMaximus', NULL, 'secondary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'bicepsFemoris', NULL, 'secondary');

  -- legPress
  SELECT id INTO eid FROM exercises WHERE name = 'legPress';
  INSERT INTO exercise_target_muscles VALUES (eid, 'rectusFemoris', NULL, 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'vastusLateralis', NULL, 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'gluteusMaximus', NULL, 'secondary');

  -- lunge
  SELECT id INTO eid FROM exercises WHERE name = 'lunge';
  INSERT INTO exercise_target_muscles VALUES (eid, 'rectusFemoris', NULL, 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'vastusLateralis', NULL, 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'gluteusMaximus', NULL, 'secondary');

  -- bulgarianSplitSquat
  SELECT id INTO eid FROM exercises WHERE name = 'bulgarianSplitSquat';
  INSERT INTO exercise_target_muscles VALUES (eid, 'rectusFemoris', NULL, 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'vastusLateralis', NULL, 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'gluteusMaximus', NULL, 'secondary');

  -- legExtension
  SELECT id INTO eid FROM exercises WHERE name = 'legExtension';
  INSERT INTO exercise_target_muscles VALUES (eid, 'rectusFemoris', NULL, 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'vastusLateralis', NULL, 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'vastusMedialis', NULL, 'primary');

  -- hackSquat
  SELECT id INTO eid FROM exercises WHERE name = 'hackSquat';
  INSERT INTO exercise_target_muscles VALUES (eid, 'rectusFemoris', NULL, 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'vastusLateralis', NULL, 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'gluteusMaximus', NULL, 'secondary');

  -- romanianDeadlift
  SELECT id INTO eid FROM exercises WHERE name = 'romanianDeadlift';
  INSERT INTO exercise_target_muscles VALUES (eid, 'bicepsFemoris', NULL, 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'semitendinosus', NULL, 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'gluteusMaximus', NULL, 'secondary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'erectorSpinae', NULL, 'secondary');

  -- nordicCurl
  SELECT id INTO eid FROM exercises WHERE name = 'nordicCurl';
  INSERT INTO exercise_target_muscles VALUES (eid, 'bicepsFemoris', NULL, 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'semitendinosus', NULL, 'primary');

  -- legCurl
  SELECT id INTO eid FROM exercises WHERE name = 'legCurl';
  INSERT INTO exercise_target_muscles VALUES (eid, 'bicepsFemoris', NULL, 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'semitendinosus', NULL, 'primary');

  -- hipThrust
  SELECT id INTO eid FROM exercises WHERE name = 'hipThrust';
  INSERT INTO exercise_target_muscles VALUES (eid, 'gluteusMaximus', NULL, 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'bicepsFemoris', NULL, 'secondary');

  -- gluteBridge
  SELECT id INTO eid FROM exercises WHERE name = 'gluteBridge';
  INSERT INTO exercise_target_muscles VALUES (eid, 'gluteusMaximus', NULL, 'primary');

  -- cableKickback
  SELECT id INTO eid FROM exercises WHERE name = 'cableKickback';
  INSERT INTO exercise_target_muscles VALUES (eid, 'gluteusMaximus', NULL, 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'gluteusMedius', NULL, 'secondary');

  -- adductorMachine
  SELECT id INTO eid FROM exercises WHERE name = 'adductorMachine';
  INSERT INTO exercise_target_muscles VALUES (eid, 'adductorMagnus', NULL, 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'adductorLongus', NULL, 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'adductorBrevis', NULL, 'primary');

  -- abductorMachine
  SELECT id INTO eid FROM exercises WHERE name = 'abductorMachine';
  INSERT INTO exercise_target_muscles VALUES (eid, 'gluteusMedius', NULL, 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'gluteusMinimus', NULL, 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'tensorFasciaeLatae', NULL, 'primary');

  -- standingCalfRaise
  SELECT id INTO eid FROM exercises WHERE name = 'standingCalfRaise';
  INSERT INTO exercise_target_muscles VALUES (eid, 'gastrocnemius', NULL, 'primary');

  -- seatedCalfRaise
  SELECT id INTO eid FROM exercises WHERE name = 'seatedCalfRaise';
  INSERT INTO exercise_target_muscles VALUES (eid, 'soleus', NULL, 'primary');

  -- crunch
  SELECT id INTO eid FROM exercises WHERE name = 'crunch';
  INSERT INTO exercise_target_muscles VALUES (eid, 'rectusAbdominis', 'upper', 'primary');

  -- plank
  SELECT id INTO eid FROM exercises WHERE name = 'plank';
  INSERT INTO exercise_target_muscles VALUES (eid, 'rectusAbdominis', NULL, 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'transverseAbdominis', NULL, 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'obliques', NULL, 'secondary');

  -- hangingLegRaise
  SELECT id INTO eid FROM exercises WHERE name = 'hangingLegRaise';
  INSERT INTO exercise_target_muscles VALUES (eid, 'rectusAbdominis', 'lower', 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'hipFlexors', NULL, 'secondary');

  -- abWheelRollout
  SELECT id INTO eid FROM exercises WHERE name = 'abWheelRollout';
  INSERT INTO exercise_target_muscles VALUES (eid, 'rectusAbdominis', NULL, 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'obliques', NULL, 'secondary');

  -- wristCurl
  SELECT id INTO eid FROM exercises WHERE name = 'wristCurl';
  INSERT INTO exercise_target_muscles VALUES (eid, 'wristFlexors', NULL, 'primary');

  -- reverseWristCurl
  SELECT id INTO eid FROM exercises WHERE name = 'reverseWristCurl';
  INSERT INTO exercise_target_muscles VALUES (eid, 'wristExtensors', NULL, 'primary');

  -- deadlift
  SELECT id INTO eid FROM exercises WHERE name = 'deadlift';
  INSERT INTO exercise_target_muscles VALUES (eid, 'bicepsFemoris', NULL, 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'gluteusMaximus', NULL, 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'erectorSpinae', NULL, 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'trapezius', NULL, 'secondary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'rectusFemoris', NULL, 'secondary');

  -- burpee
  SELECT id INTO eid FROM exercises WHERE name = 'burpee';
  INSERT INTO exercise_target_muscles VALUES (eid, 'rectusFemoris', NULL, 'primary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'pectoralisMajor', NULL, 'secondary');
  INSERT INTO exercise_target_muscles VALUES (eid, 'anteriorDeltoid', NULL, 'secondary');
END $$;

-- ── Equipment relations seed ──

DO $$
DECLARE
  exid INTEGER;
  eqid INTEGER;
BEGIN
  -- Helper function-like pattern: look up both IDs and insert
  SELECT id INTO exid FROM exercises WHERE name = 'flatBarbellBenchPress';
  SELECT id INTO eqid FROM equipments WHERE name = 'barbell'; INSERT INTO exercise_equipments VALUES (exid, eqid);
  SELECT id INTO eqid FROM equipments WHERE name = 'flatBench'; INSERT INTO exercise_equipments VALUES (exid, eqid);

  SELECT id INTO exid FROM exercises WHERE name = 'inclineBarbellBenchPress';
  SELECT id INTO eqid FROM equipments WHERE name = 'barbell'; INSERT INTO exercise_equipments VALUES (exid, eqid);
  SELECT id INTO eqid FROM equipments WHERE name = 'adjustableBench'; INSERT INTO exercise_equipments VALUES (exid, eqid);

  SELECT id INTO exid FROM exercises WHERE name = 'dumbbellFly';
  SELECT id INTO eqid FROM equipments WHERE name = 'dumbbell'; INSERT INTO exercise_equipments VALUES (exid, eqid);
  SELECT id INTO eqid FROM equipments WHERE name = 'flatBench'; INSERT INTO exercise_equipments VALUES (exid, eqid);

  SELECT id INTO exid FROM exercises WHERE name = 'cableCrossover';
  SELECT id INTO eqid FROM equipments WHERE name = 'cableMachine'; INSERT INTO exercise_equipments VALUES (exid, eqid);

  SELECT id INTO exid FROM exercises WHERE name = 'machineChestPress';
  SELECT id INTO eqid FROM equipments WHERE name = 'chestPressMachine'; INSERT INTO exercise_equipments VALUES (exid, eqid);

  SELECT id INTO exid FROM exercises WHERE name = 'inclineDumbbellPress';
  SELECT id INTO eqid FROM equipments WHERE name = 'dumbbell'; INSERT INTO exercise_equipments VALUES (exid, eqid);
  SELECT id INTO eqid FROM equipments WHERE name = 'adjustableBench'; INSERT INTO exercise_equipments VALUES (exid, eqid);

  SELECT id INTO exid FROM exercises WHERE name = 'pullUp';
  SELECT id INTO eqid FROM equipments WHERE name = 'pullUpBar'; INSERT INTO exercise_equipments VALUES (exid, eqid);

  SELECT id INTO exid FROM exercises WHERE name = 'barbellRow';
  SELECT id INTO eqid FROM equipments WHERE name = 'barbell'; INSERT INTO exercise_equipments VALUES (exid, eqid);

  SELECT id INTO exid FROM exercises WHERE name = 'latPulldown';
  SELECT id INTO eqid FROM equipments WHERE name = 'latPulldownMachine'; INSERT INTO exercise_equipments VALUES (exid, eqid);

  SELECT id INTO exid FROM exercises WHERE name = 'seatedCableRow';
  SELECT id INTO eqid FROM equipments WHERE name = 'cableMachine'; INSERT INTO exercise_equipments VALUES (exid, eqid);

  SELECT id INTO exid FROM exercises WHERE name = 'dumbbellRow';
  SELECT id INTO eqid FROM equipments WHERE name = 'dumbbell'; INSERT INTO exercise_equipments VALUES (exid, eqid);
  SELECT id INTO eqid FROM equipments WHERE name = 'flatBench'; INSERT INTO exercise_equipments VALUES (exid, eqid);

  SELECT id INTO exid FROM exercises WHERE name = 'chinUp';
  SELECT id INTO eqid FROM equipments WHERE name = 'pullUpBar'; INSERT INTO exercise_equipments VALUES (exid, eqid);

  SELECT id INTO exid FROM exercises WHERE name = 'dumbbellShrug';
  SELECT id INTO eqid FROM equipments WHERE name = 'dumbbell'; INSERT INTO exercise_equipments VALUES (exid, eqid);

  SELECT id INTO exid FROM exercises WHERE name = 'overheadPress';
  SELECT id INTO eqid FROM equipments WHERE name = 'barbell'; INSERT INTO exercise_equipments VALUES (exid, eqid);

  SELECT id INTO exid FROM exercises WHERE name = 'lateralRaise';
  SELECT id INTO eqid FROM equipments WHERE name = 'dumbbell'; INSERT INTO exercise_equipments VALUES (exid, eqid);

  SELECT id INTO exid FROM exercises WHERE name = 'facePull';
  SELECT id INTO eqid FROM equipments WHERE name = 'cableMachine'; INSERT INTO exercise_equipments VALUES (exid, eqid);

  SELECT id INTO exid FROM exercises WHERE name = 'arnoldPress';
  SELECT id INTO eqid FROM equipments WHERE name = 'dumbbell'; INSERT INTO exercise_equipments VALUES (exid, eqid);

  SELECT id INTO exid FROM exercises WHERE name = 'rearDeltFly';
  SELECT id INTO eqid FROM equipments WHERE name = 'dumbbell'; INSERT INTO exercise_equipments VALUES (exid, eqid);

  SELECT id INTO exid FROM exercises WHERE name = 'barbellCurl';
  SELECT id INTO eqid FROM equipments WHERE name = 'barbell'; INSERT INTO exercise_equipments VALUES (exid, eqid);

  SELECT id INTO exid FROM exercises WHERE name = 'dumbbellCurl';
  SELECT id INTO eqid FROM equipments WHERE name = 'dumbbell'; INSERT INTO exercise_equipments VALUES (exid, eqid);

  SELECT id INTO exid FROM exercises WHERE name = 'hammerCurl';
  SELECT id INTO eqid FROM equipments WHERE name = 'dumbbell'; INSERT INTO exercise_equipments VALUES (exid, eqid);

  SELECT id INTO exid FROM exercises WHERE name = 'preacherCurl';
  SELECT id INTO eqid FROM equipments WHERE name = 'ezBar'; INSERT INTO exercise_equipments VALUES (exid, eqid);

  SELECT id INTO exid FROM exercises WHERE name = 'tricepsPushdown';
  SELECT id INTO eqid FROM equipments WHERE name = 'cableMachine'; INSERT INTO exercise_equipments VALUES (exid, eqid);

  SELECT id INTO exid FROM exercises WHERE name = 'skullCrusher';
  SELECT id INTO eqid FROM equipments WHERE name = 'ezBar'; INSERT INTO exercise_equipments VALUES (exid, eqid);
  SELECT id INTO eqid FROM equipments WHERE name = 'flatBench'; INSERT INTO exercise_equipments VALUES (exid, eqid);

  SELECT id INTO exid FROM exercises WHERE name = 'overheadTricepsExtension';
  SELECT id INTO eqid FROM equipments WHERE name = 'dumbbell'; INSERT INTO exercise_equipments VALUES (exid, eqid);

  SELECT id INTO exid FROM exercises WHERE name = 'dip';
  SELECT id INTO eqid FROM equipments WHERE name = 'dipStation'; INSERT INTO exercise_equipments VALUES (exid, eqid);

  SELECT id INTO exid FROM exercises WHERE name = 'barbellSquat';
  SELECT id INTO eqid FROM equipments WHERE name = 'barbell'; INSERT INTO exercise_equipments VALUES (exid, eqid);
  SELECT id INTO eqid FROM equipments WHERE name = 'squatRack'; INSERT INTO exercise_equipments VALUES (exid, eqid);

  SELECT id INTO exid FROM exercises WHERE name = 'legPress';
  SELECT id INTO eqid FROM equipments WHERE name = 'legPressMachine'; INSERT INTO exercise_equipments VALUES (exid, eqid);

  SELECT id INTO exid FROM exercises WHERE name = 'lunge';
  SELECT id INTO eqid FROM equipments WHERE name = 'dumbbell'; INSERT INTO exercise_equipments VALUES (exid, eqid);

  SELECT id INTO exid FROM exercises WHERE name = 'bulgarianSplitSquat';
  SELECT id INTO eqid FROM equipments WHERE name = 'dumbbell'; INSERT INTO exercise_equipments VALUES (exid, eqid);
  SELECT id INTO eqid FROM equipments WHERE name = 'flatBench'; INSERT INTO exercise_equipments VALUES (exid, eqid);

  SELECT id INTO exid FROM exercises WHERE name = 'legExtension';
  SELECT id INTO eqid FROM equipments WHERE name = 'legExtensionMachine'; INSERT INTO exercise_equipments VALUES (exid, eqid);

  SELECT id INTO exid FROM exercises WHERE name = 'hackSquat';
  SELECT id INTO eqid FROM equipments WHERE name = 'hackSquatMachine'; INSERT INTO exercise_equipments VALUES (exid, eqid);

  SELECT id INTO exid FROM exercises WHERE name = 'romanianDeadlift';
  SELECT id INTO eqid FROM equipments WHERE name = 'barbell'; INSERT INTO exercise_equipments VALUES (exid, eqid);

  SELECT id INTO exid FROM exercises WHERE name = 'legCurl';
  SELECT id INTO eqid FROM equipments WHERE name = 'legCurlMachine'; INSERT INTO exercise_equipments VALUES (exid, eqid);

  SELECT id INTO exid FROM exercises WHERE name = 'hipThrust';
  SELECT id INTO eqid FROM equipments WHERE name = 'barbell'; INSERT INTO exercise_equipments VALUES (exid, eqid);
  SELECT id INTO eqid FROM equipments WHERE name = 'flatBench'; INSERT INTO exercise_equipments VALUES (exid, eqid);

  SELECT id INTO exid FROM exercises WHERE name = 'cableKickback';
  SELECT id INTO eqid FROM equipments WHERE name = 'cableMachine'; INSERT INTO exercise_equipments VALUES (exid, eqid);

  SELECT id INTO exid FROM exercises WHERE name = 'adductorMachine';
  SELECT id INTO eqid FROM equipments WHERE name = 'adductorMachine'; INSERT INTO exercise_equipments VALUES (exid, eqid);

  SELECT id INTO exid FROM exercises WHERE name = 'abductorMachine';
  SELECT id INTO eqid FROM equipments WHERE name = 'abductorMachine'; INSERT INTO exercise_equipments VALUES (exid, eqid);

  SELECT id INTO exid FROM exercises WHERE name = 'standingCalfRaise';
  SELECT id INTO eqid FROM equipments WHERE name = 'smithMachine'; INSERT INTO exercise_equipments VALUES (exid, eqid);

  SELECT id INTO exid FROM exercises WHERE name = 'hangingLegRaise';
  SELECT id INTO eqid FROM equipments WHERE name = 'pullUpBar'; INSERT INTO exercise_equipments VALUES (exid, eqid);

  SELECT id INTO exid FROM exercises WHERE name = 'abWheelRollout';
  SELECT id INTO eqid FROM equipments WHERE name = 'abWheel'; INSERT INTO exercise_equipments VALUES (exid, eqid);

  SELECT id INTO exid FROM exercises WHERE name = 'wristCurl';
  SELECT id INTO eqid FROM equipments WHERE name = 'barbell'; INSERT INTO exercise_equipments VALUES (exid, eqid);

  SELECT id INTO exid FROM exercises WHERE name = 'reverseWristCurl';
  SELECT id INTO eqid FROM equipments WHERE name = 'barbell'; INSERT INTO exercise_equipments VALUES (exid, eqid);

  SELECT id INTO exid FROM exercises WHERE name = 'deadlift';
  SELECT id INTO eqid FROM equipments WHERE name = 'barbell'; INSERT INTO exercise_equipments VALUES (exid, eqid);

  SELECT id INTO exid FROM exercises WHERE name = 'treadmillRun';
  SELECT id INTO eqid FROM equipments WHERE name = 'treadmill'; INSERT INTO exercise_equipments VALUES (exid, eqid);

  SELECT id INTO exid FROM exercises WHERE name = 'stationaryBike';
  SELECT id INTO eqid FROM equipments WHERE name = 'stationaryBike'; INSERT INTO exercise_equipments VALUES (exid, eqid);

  SELECT id INTO exid FROM exercises WHERE name = 'rowingMachine';
  SELECT id INTO eqid FROM equipments WHERE name = 'rowingMachine'; INSERT INTO exercise_equipments VALUES (exid, eqid);

  SELECT id INTO exid FROM exercises WHERE name = 'elliptical';
  SELECT id INTO eqid FROM equipments WHERE name = 'elliptical'; INSERT INTO exercise_equipments VALUES (exid, eqid);

  SELECT id INTO exid FROM exercises WHERE name = 'jumpRope';
  SELECT id INTO eqid FROM equipments WHERE name = 'jumpRope'; INSERT INTO exercise_equipments VALUES (exid, eqid);
END $$;

-- ── RLS Policies (read-only public) ──

ALTER TABLE equipments ENABLE ROW LEVEL SECURITY;
ALTER TABLE exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE exercise_target_muscles ENABLE ROW LEVEL SECURITY;
ALTER TABLE exercise_equipments ENABLE ROW LEVEL SECURITY;
ALTER TABLE exercise_variations ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog_version ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read access" ON equipments FOR SELECT USING (true);
CREATE POLICY "Public read access" ON exercises FOR SELECT USING (true);
CREATE POLICY "Public read access" ON exercise_target_muscles FOR SELECT USING (true);
CREATE POLICY "Public read access" ON exercise_equipments FOR SELECT USING (true);
CREATE POLICY "Public read access" ON exercise_variations FOR SELECT USING (true);
CREATE POLICY "Public read access" ON catalog_version FOR SELECT USING (true);
