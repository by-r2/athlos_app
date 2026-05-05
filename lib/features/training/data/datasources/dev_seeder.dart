import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';

/// Seeds the database with realistic test data for development.
///
/// Sets [UserProfile.ownedEquipmentNames], builds workouts with
/// exercises (including supersets), and generates execution history
/// (including drop sets). Only called in debug mode.
Future<void> seedDevData(AppDatabase db) async {
  final exerciseIds = await _resolveExerciseIds(db);

  await _seedDevProfileEquipment(db);
  await _seedWorkoutsWithExercises(db, exerciseIds);
  final programId = await _seedProgram(db, exerciseIds);
  await _seedExecutionHistory(db, exerciseIds, programId);
  await _seedBodyMetrics(db);
}

Future<Map<String, int>> _resolveExerciseIds(AppDatabase db) async {
  final rows = await db.select(db.exercises).get();
  return {for (final r in rows) r.name: r.id};
}

// ---------------------------------------------------------------------------
// Profile — owned equipment (free-text names, same keys as legacy catalog)
// ---------------------------------------------------------------------------

Future<void> _seedDevProfileEquipment(AppDatabase db) async {
  const owned = <String>[
    'barbell',
    'dumbbell',
    'ezBar',
    'weightPlates',
    'cableMachine',
    'smithMachine',
    'legPressMachine',
    'latPulldownMachine',
    'chestPressMachine',
    'pullUpBar',
    'dipStation',
    'flatBench',
    'adjustableBench',
    'squatRack',
    'resistanceBands',
    'treadmill',
    'stationaryBike',
    'jumpRope',
  ];

  final existing = await db.select(db.userProfiles).getSingleOrNull();
  if (existing != null) {
    await (db.update(db.userProfiles)..where((p) => p.id.equals(existing.id)))
        .write(
      UserProfilesCompanion(
        ownedEquipmentNames: Value(owned),
      ),
    );
  } else {
    await db.into(db.userProfiles).insert(
          UserProfilesCompanion.insert(
            ownedEquipmentNames: Value(owned),
          ),
        );
  }
}

// ---------------------------------------------------------------------------
// Workouts with exercises
// ---------------------------------------------------------------------------

Future<void> _seedWorkoutsWithExercises(
    AppDatabase db, Map<String, int> exerciseIds) async {
  // --- Push Day ---
  final pushId = await db.into(db.workouts).insert(
        WorkoutsCompanion.insert(
          name: 'Push Day',
          description: const Value('Chest, shoulders & triceps'),
          sortOrder: const Value(0),
        ),
      );
  await _insertWorkoutExercises(db, pushId, exerciseIds, [
    _WE('benchPress', order: 0, sets: 4, minReps: 6, maxReps: 8, rest: 90),
    _WE('inclineBenchPress', order: 1, sets: 3, minReps: 8, maxReps: 12, rest: 75),
    _WE('chestFly', order: 2, sets: 3, minReps: 10, maxReps: 15, rest: 60),
    _WE('overheadPress', order: 3, sets: 4, minReps: 6, maxReps: 8, rest: 90),
    _WE('lateralRaise', order: 4, sets: 3, minReps: 12, maxReps: 15, rest: 45, groupId: 1),
    _WE('facePull', order: 5, sets: 3, minReps: 12, maxReps: 15, rest: 60, groupId: 1),
    _WE('tricepsPushdown', order: 6, sets: 3, minReps: 10, maxReps: 12, rest: 60),
  ]);

  // --- Pull Day ---
  final pullId = await db.into(db.workouts).insert(
        WorkoutsCompanion.insert(
          name: 'Pull Day',
          description: const Value('Back & biceps'),
          sortOrder: const Value(1),
        ),
      );
  await _insertWorkoutExercises(db, pullId, exerciseIds, [
    _WE('pullUp', order: 0, sets: 4, minReps: 6, maxReps: 10, rest: 90),
    _WE('bentOverRow', order: 1, sets: 4, minReps: 6, maxReps: 8, rest: 90),
    _WE('latPulldown', order: 2, sets: 3, minReps: 8, maxReps: 12, rest: 75),
    _WE('seatedRow', order: 3, sets: 3, minReps: 10, maxReps: 12, rest: 60),
    _WE('bicepsCurl', order: 4, sets: 3, minReps: 8, maxReps: 12, rest: 45, groupId: 1),
    _WE('hammerCurl', order: 5, sets: 3, minReps: 10, maxReps: 12, rest: 60, groupId: 1),
  ]);

  // --- Leg Day ---
  final legId = await db.into(db.workouts).insert(
        WorkoutsCompanion.insert(
          name: 'Leg Day',
          description: const Value('Quads, hamstrings, glutes & calves'),
          sortOrder: const Value(2),
        ),
      );
  await _insertWorkoutExercises(db, legId, exerciseIds, [
    _WE('backSquat', order: 0, sets: 4, minReps: 5, maxReps: 5, rest: 120, isAmrap: true),
    _WE('legPress', order: 1, sets: 3, minReps: 8, maxReps: 12, rest: 90),
    _WE('romanianDeadlift', order: 2, sets: 3, minReps: 8, maxReps: 10, rest: 90),
    _WE('bulgarianSplitSquat', order: 3, sets: 3, minReps: 8, maxReps: 12, rest: 75),
    _WE('hipThrust', order: 4, sets: 3, minReps: 10, maxReps: 12, rest: 75),
    _WE('standingCalfRaise', order: 5, sets: 4, minReps: 12, maxReps: 20, rest: 45),
  ]);

  // --- Cardio Day ---
  final cardioId = await db.into(db.workouts).insert(
        WorkoutsCompanion.insert(
          name: 'Cardio Day',
          description: const Value('Endurance & conditioning'),
          sortOrder: const Value(3),
        ),
      );
  await _insertWorkoutExercises(db, cardioId, exerciseIds, [
    _WE('treadmillRun', order: 0, sets: 1, duration: 1200, rest: 120),
    _WE('stationaryBike', order: 1, sets: 1, duration: 900, rest: 90),
    _WE('jumpRope', order: 2, sets: 3, duration: 180, rest: 60),
    _WE('jumpingJacks', order: 3, sets: 3, duration: 60, rest: 30),
  ]);

  // --- Full Body (archived) ---
  await db.into(db.workouts).insert(
        WorkoutsCompanion.insert(
          name: 'Full Body',
          description: const Value('Quick full body session'),
          sortOrder: const Value(4),
          isArchived: const Value(true),
        ),
      );
}

Future<void> _insertWorkoutExercises(
  AppDatabase db,
  int workoutId,
  Map<String, int> exerciseIds,
  List<_WE> entries,
) async {
  await db.batch((batch) {
    for (final e in entries) {
      final exId = exerciseIds[e.exerciseName];
      if (exId == null) continue;
      batch.insert(
        db.workoutExercises,
        WorkoutExercisesCompanion(
          workoutId: Value(workoutId),
          exerciseId: Value(exId),
          order: Value(e.order),
          sets: Value(e.sets),
          minReps: Value(e.minReps),
          maxReps: Value(e.maxReps),
          isAmrap: Value(e.isAmrap),
          rest: Value(e.rest),
          duration: Value(e.duration),
          groupId: Value(e.groupId),
        ),
      );
    }
  });
}

// ---------------------------------------------------------------------------
// Execution History
// ---------------------------------------------------------------------------

Future<void> _seedExecutionHistory(
    AppDatabase db, Map<String, int> exerciseIds, int programId) async {
  final now = DateTime.now();

  // --- Execution 1: Push Day — 3 days ago (completed) ---
  final exec1 = await db.into(db.workoutExecutions).insert(
        WorkoutExecutionsCompanion.insert(
          workoutId: 1,
          programId: programId,
          startedAt: Value(now.subtract(const Duration(days: 3, hours: 1))),
          finishedAt:
              Value(now.subtract(const Duration(days: 3, minutes: 10))),
          notes: const Value('Good session, PR on bench press'),
        ),
      );
  await _insertCompletedSets(db, exec1, exerciseIds['benchPress']!,
      planned: 8,
      weights: [80, 80, 82.5, 82.5],
      reps: [8, 8, 7, 6],
      rpes: [7, 8, 9, 10]);
  await _insertCompletedSets(
      db, exec1, exerciseIds['inclineBenchPress']!,
      planned: 10, weights: [50, 50, 50], reps: [10, 10, 9], rpes: [7, 8, 9]);
  await _insertCompletedSets(db, exec1, exerciseIds['chestFly']!,
      planned: 12, weights: [14, 14, 14], reps: [12, 12, 11]);
  await _insertCompletedSets(db, exec1, exerciseIds['overheadPress']!,
      planned: 8, weights: [40, 40, 42.5, 42.5], reps: [8, 8, 7, 6]);
  await _insertCompletedSets(db, exec1, exerciseIds['lateralRaise']!,
      planned: 15, weights: [8, 8, 8], reps: [15, 14, 13]);
  await _insertCompletedSets(db, exec1, exerciseIds['facePull']!,
      planned: 15, weights: [15, 15, 15], reps: [15, 15, 14]);
  // Triceps pushdown with a drop set on the last set
  await _insertSetsWithDropSet(
    db,
    exec1,
    exerciseIds['tricepsPushdown']!,
    planned: 12,
    normalSets: [
      (weight: 25.0, reps: 12),
      (weight: 25.0, reps: 11),
    ],
    dropSetPrimary: (weight: 25.0, reps: 10),
    dropSegments: [
      (weight: 17.5, reps: 8),
      (weight: 10.0, reps: 10),
    ],
  );

  // --- Execution 2: Pull Day — yesterday (completed) ---
  final exec2 = await db.into(db.workoutExecutions).insert(
        WorkoutExecutionsCompanion.insert(
          workoutId: 2,
          programId: programId,
          startedAt: Value(now.subtract(const Duration(days: 1, hours: 1))),
          finishedAt:
              Value(now.subtract(const Duration(days: 1, minutes: 5))),
        ),
      );
  await _insertCompletedSets(db, exec2, exerciseIds['pullUp']!,
      planned: 8, weights: [null, null, null, null], reps: [10, 9, 8, 7]);
  await _insertCompletedSets(db, exec2, exerciseIds['bentOverRow']!,
      planned: 8, weights: [60, 60, 62.5, 62.5], reps: [8, 8, 7, 7]);
  await _insertCompletedSets(db, exec2, exerciseIds['latPulldown']!,
      planned: 10, weights: [50, 50, 50], reps: [10, 10, 9]);
  await _insertCompletedSets(db, exec2, exerciseIds['seatedRow']!,
      planned: 12, weights: [40, 40, 40], reps: [12, 12, 11]);
  await _insertCompletedSets(db, exec2, exerciseIds['bicepsCurl']!,
      planned: 10, weights: [25, 25, 25], reps: [10, 10, 8]);
  await _insertCompletedSets(db, exec2, exerciseIds['hammerCurl']!,
      planned: 12, weights: [12, 12, 12], reps: [12, 11, 10]);

  // --- Execution 3: Leg Day — today (completed) ---
  final exec3 = await db.into(db.workoutExecutions).insert(
        WorkoutExecutionsCompanion.insert(
          workoutId: 3,
          programId: programId,
          startedAt: Value(now.subtract(const Duration(hours: 2))),
          finishedAt: Value(now.subtract(const Duration(minutes: 30))),
          notes: const Value('Legs were shaky after squats'),
        ),
      );
  await _insertCompletedSets(db, exec3, exerciseIds['backSquat']!,
      planned: 8, weights: [100, 100, 105, 105], reps: [8, 8, 6, 5]);
  await _insertCompletedSets(db, exec3, exerciseIds['legPress']!,
      planned: 12, weights: [180, 180, 180], reps: [12, 12, 10]);
  await _insertCompletedSets(db, exec3, exerciseIds['romanianDeadlift']!,
      planned: 10, weights: [70, 70, 70], reps: [10, 10, 9]);
  await _insertCompletedSets(
      db, exec3, exerciseIds['bulgarianSplitSquat']!,
      planned: 10, weights: [16, 16, 16], reps: [10, 10, 8]);
  await _insertCompletedSets(db, exec3, exerciseIds['hipThrust']!,
      planned: 12, weights: [80, 80, 80], reps: [12, 12, 11]);
  await _insertCompletedSets(db, exec3, exerciseIds['standingCalfRaise']!,
      planned: 15, weights: [60, 60, 60, 60], reps: [15, 15, 14, 13]);

  // --- Execution 4: Cardio Day — 2 days ago (completed) ---
  final exec4 = await db.into(db.workoutExecutions).insert(
        WorkoutExecutionsCompanion.insert(
          workoutId: 4,
          programId: programId,
          startedAt: Value(now.subtract(const Duration(days: 2, hours: 1))),
          finishedAt:
              Value(now.subtract(const Duration(days: 2, minutes: 15))),
          notes: const Value('Good cardio session'),
        ),
      );
  await _insertCompletedCardioSets(
      db, exec4, exerciseIds['treadmillRun']!,
      durations: [1200], distances: [3500]);
  await _insertCompletedCardioSets(
      db, exec4, exerciseIds['stationaryBike']!,
      durations: [900], distances: [5200]);
  await _insertCompletedCardioSets(
      db, exec4, exerciseIds['jumpRope']!,
      durations: [180, 165, 150], distances: [null, null, null]);
  await _insertCompletedCardioSets(
      db, exec4, exerciseIds['jumpingJacks']!,
      durations: [60, 55, 50], distances: [null, null, null]);
}

/// Inserts completed normal sets (no drop segments).
Future<void> _insertCompletedSets(
  AppDatabase db,
  int executionId,
  int exerciseId, {
  required int planned,
  required List<double?> weights,
  required List<int> reps,
  List<int?>? rpes,
}) async {
  assert(weights.length == reps.length);
  for (var i = 0; i < weights.length; i++) {
    await db.into(db.executionSets).insert(
          ExecutionSetsCompanion.insert(
            executionId: executionId,
            exerciseId: exerciseId,
            setNumber: i + 1,
            plannedReps: Value(planned),
            reps: Value(reps[i]),
            plannedWeight: Value(weights[i]),
            weight: Value(weights[i]),
            isCompleted: const Value(true),
            rpe: Value(rpes != null && i < rpes.length ? rpes[i] : null),
          ),
        );
  }
}

/// Inserts completed cardio sets (duration + optional distance).
Future<void> _insertCompletedCardioSets(
  AppDatabase db,
  int executionId,
  int exerciseId, {
  required List<int> durations,
  required List<double?> distances,
}) async {
  assert(durations.length == distances.length);
  for (var i = 0; i < durations.length; i++) {
    await db.into(db.executionSets).insert(
          ExecutionSetsCompanion.insert(
            executionId: executionId,
            exerciseId: exerciseId,
            setNumber: i + 1,
            duration: Value(durations[i]),
            distance: Value(distances[i]),
            isCompleted: const Value(true),
          ),
        );
  }
}

/// Inserts sets where the last set is a drop set with multiple segments.
Future<void> _insertSetsWithDropSet(
  AppDatabase db,
  int executionId,
  int exerciseId, {
  required int planned,
  required List<({double weight, int reps})> normalSets,
  required ({double weight, int reps}) dropSetPrimary,
  required List<({double weight, int reps})> dropSegments,
}) async {
  var setNumber = 1;

  for (final s in normalSets) {
    await db.into(db.executionSets).insert(
          ExecutionSetsCompanion.insert(
            executionId: executionId,
            exerciseId: exerciseId,
            setNumber: setNumber++,
            plannedReps: Value(planned),
            reps: Value(s.reps),
            plannedWeight: Value(s.weight),
            weight: Value(s.weight),
            isCompleted: const Value(true),
          ),
        );
  }

  final dropSetId = await db.into(db.executionSets).insert(
        ExecutionSetsCompanion.insert(
          executionId: executionId,
          exerciseId: exerciseId,
          setNumber: setNumber,
          plannedReps: Value(planned),
          reps: Value(dropSetPrimary.reps),
          plannedWeight: Value(dropSetPrimary.weight),
          weight: Value(dropSetPrimary.weight),
          isCompleted: const Value(true),
        ),
      );

  await db.into(db.executionSetSegments).insert(
        ExecutionSetSegmentsCompanion.insert(
          executionSetId: dropSetId,
          segmentOrder: 1,
          reps: dropSetPrimary.reps,
          weight: Value(dropSetPrimary.weight),
        ),
      );

  for (var i = 0; i < dropSegments.length; i++) {
    await db.into(db.executionSetSegments).insert(
          ExecutionSetSegmentsCompanion.insert(
            executionSetId: dropSetId,
            segmentOrder: i + 2,
            reps: dropSegments[i].reps,
            weight: Value(dropSegments[i].weight),
          ),
        );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _WE {
  final String exerciseName;
  final int order;
  final int sets;
  final int? minReps;
  final int? maxReps;
  final bool isAmrap;
  final int rest;
  final int? duration;
  final int? groupId;

  const _WE(
    this.exerciseName, {
    required this.order,
    required this.sets,
    this.minReps,
    this.maxReps,
    this.isAmrap = false,
    required this.rest,
    this.duration,
    this.groupId,
  });
}

// ---------------------------------------------------------------------------
// Training Program (mesocycle)
// ---------------------------------------------------------------------------

Future<int> _seedProgram(
    AppDatabase db, Map<String, int> exerciseIds) async {
  final activeWorkouts = await db.customSelect(
    'SELECT id FROM workouts WHERE is_archived = 0 ORDER BY sort_order ASC',
  ).get();

  // PPL program with first 3 workouts
  final pplIds = activeWorkouts.take(3).map((r) => r.read<int>('id')).toList();

  final programId = await db.into(db.programs).insert(
        ProgramsCompanion.insert(
          name: 'PPL Hipertrofia',
          focus: 'hypertrophy',
          durationMode: 'sessions',
          durationValue: 24,
          defaultRestSeconds: const Value(90),
          isActive: const Value(true),
          deloadFrequency: const Value(4),
          deloadStrategy: const Value('reduceVolume'),
          deloadVolumeMultiplier: const Value(0.6),
          deloadIntensityMultiplier: const Value(0.5),
        ),
      );

  for (var i = 0; i < pplIds.length; i++) {
    await db.into(db.cycleSteps).insert(
          CycleStepsCompanion.insert(
            programId: programId,
            orderIndex: i,
            workoutId: pplIds[i],
          ),
        );
  }

  // Progression rules for key compound lifts.
  final progressionExercises = {
    'benchPress': 2.5,
    'bentOverRow': 2.5,
    'deadlift': 5.0,
    'backSquat': 5.0,
    'overheadPress': 1.25,
  };
  for (final entry in progressionExercises.entries) {
    final exId = exerciseIds[entry.key];
    if (exId == null) continue;
    await db.into(db.progressionRules).insert(
          ProgressionRulesCompanion.insert(
            programId: programId,
            exerciseId: exId,
            type: 'incrementWeight',
            value: entry.value,
            frequency: 'everySession',
            condition: const Value('completesAllSets'),
          ),
        );
  }

  return programId;
}

// ---------------------------------------------------------------------------
// Body Metrics (weight timeline)
// ---------------------------------------------------------------------------

Future<void> _seedBodyMetrics(AppDatabase db) async {
  final now = DateTime.now();
  final entries = <(double weight, double? bf, int daysAgo)>[
    (80.0, 18.0, 56),
    (79.5, null, 49),
    (79.2, 17.5, 42),
    (78.8, null, 35),
    (78.5, 17.0, 28),
    (78.2, null, 21),
    (77.8, 16.5, 14),
    (77.5, null, 7),
    (77.2, 16.0, 0),
  ];
  for (final (weight, bf, daysAgo) in entries) {
    await db.into(db.bodyMetrics).insert(
          BodyMetricsCompanion.insert(
            weight: weight,
            bodyFatPercent: Value(bf),
            recordedAt: Value(now.subtract(Duration(days: daysAgo))),
          ),
        );
  }
}
