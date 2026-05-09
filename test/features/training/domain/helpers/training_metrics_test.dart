import 'package:athlos_app/features/training/domain/entities/exercise.dart';
import 'package:athlos_app/features/training/domain/entities/execution_set.dart';
import 'package:athlos_app/features/training/domain/entities/execution_set_segment.dart';
import 'package:athlos_app/features/training/domain/entities/workout_exercise.dart';
import 'package:athlos_app/features/training/domain/enums/load_mode.dart';
import 'package:athlos_app/features/training/domain/enums/muscle_group.dart';
import 'package:athlos_app/features/training/domain/helpers/training_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

ExecutionSet _set({
  int id = 1,
  int? reps = 10,
  double? weight = 50,
  bool isCompleted = true,
  bool isWarmup = false,
  List<ExecutionSetSegment> segments = const [],
}) =>
    ExecutionSet(
      id: id,
      executionId: 1,
      exerciseId: 1,
      setNumber: id,
      reps: reps,
      weight: weight,
      isCompleted: isCompleted,
      isWarmup: isWarmup,
      segments: segments,
    );

void main() {
  group('computeSetVolume', () {
    test('returns reps × weight for a completed work set', () {
      expect(computeSetVolume(_set(reps: 10, weight: 50)), 500);
    });

    test('returns 0 for incomplete sets', () {
      expect(
        computeSetVolume(_set(reps: 10, weight: 50, isCompleted: false)),
        0,
      );
    });

    test('returns 0 for warmup sets', () {
      expect(
        computeSetVolume(_set(reps: 10, weight: 50, isWarmup: true)),
        0,
      );
    });

    test('treats null weight as 0', () {
      expect(computeSetVolume(_set(reps: 10, weight: null)), 0);
    });

    test('treats null reps as 0', () {
      expect(computeSetVolume(_set(reps: null, weight: 50)), 0);
    });

    test('sums every drop-set segment when present', () {
      final set = _set(
        segments: const [
          ExecutionSetSegment(
            id: 1,
            executionSetId: 1,
            segmentOrder: 1,
            reps: 10,
            weight: 50,
          ),
          ExecutionSetSegment(
            id: 2,
            executionSetId: 1,
            segmentOrder: 2,
            reps: 8,
            weight: 40,
          ),
          ExecutionSetSegment(
            id: 3,
            executionSetId: 1,
            segmentOrder: 3,
            reps: 6,
            weight: 30,
          ),
        ],
      );
      // 10×50 + 8×40 + 6×30 = 500 + 320 + 180 = 1000.
      expect(computeSetVolume(set), 1000);
    });

    test('drop-set with null segment weight contributes 0 for that block', () {
      final set = _set(
        segments: const [
          ExecutionSetSegment(
            id: 1,
            executionSetId: 1,
            segmentOrder: 1,
            reps: 10,
            weight: 50,
          ),
          ExecutionSetSegment(
            id: 2,
            executionSetId: 1,
            segmentOrder: 2,
            reps: 8,
            weight: null,
          ),
        ],
      );
      expect(computeSetVolume(set), 500);
    });

    test('warmup drop-sets are excluded entirely', () {
      final set = _set(
        isWarmup: true,
        segments: const [
          ExecutionSetSegment(
            id: 1,
            executionSetId: 1,
            segmentOrder: 1,
            reps: 10,
            weight: 50,
          ),
        ],
      );
      expect(computeSetVolume(set), 0);
    });
  });

  group('computeTotalVolume', () {
    test('sums every set ignoring incomplete and warmup', () {
      final sets = [
        _set(id: 1, reps: 10, weight: 50), // 500 (work set)
        _set(id: 2, reps: 8, weight: 60), // 480 (work set)
        _set(id: 3, reps: 5, weight: 30, isWarmup: true), // 0 (warmup)
        _set(id: 4, reps: 5, weight: 70, isCompleted: false), // 0 (incomplete)
      ];
      expect(computeTotalVolume(sets), 980);
    });

    test('returns 0 for empty input', () {
      expect(computeTotalVolume(const []), 0);
    });

    test('mixes drop sets and normal sets correctly', () {
      final sets = [
        _set(id: 1, reps: 10, weight: 100), // 1000
        _set(
          id: 2,
          segments: const [
            ExecutionSetSegment(
              id: 1,
              executionSetId: 2,
              segmentOrder: 1,
              reps: 10,
              weight: 80,
            ),
            ExecutionSetSegment(
              id: 2,
              executionSetId: 2,
              segmentOrder: 2,
              reps: 6,
              weight: 60,
            ),
          ],
        ), // 800 + 360 = 1160
      ];
      expect(computeTotalVolume(sets), 2160);
    });
  });

  group('effectiveLoad', () {
    test('weighted mode returns setWeight as-is', () {
      expect(
        effectiveLoad(
          mode: LoadMode.weighted,
          setWeight: 80,
          bodyWeight: 75,
          loadFactor: 0.64,
        ),
        80,
      );
    });

    test('weighted mode returns null when setWeight is null', () {
      expect(
        effectiveLoad(
          mode: LoadMode.weighted,
          setWeight: null,
          bodyWeight: 75,
        ),
        null,
      );
    });

    test('bodyweight mode applies load factor to body weight', () {
      // 75 × 0.64 = 48 (push-up factor).
      expect(
        effectiveLoad(
          mode: LoadMode.bodyweight,
          setWeight: null,
          bodyWeight: 75,
          loadFactor: 0.64,
        ),
        48,
      );
    });

    test('bodyweight mode adds setWeight as ballast', () {
      // 75 × 1.0 + 10 = 85 (pull-up with weighted vest).
      expect(
        effectiveLoad(
          mode: LoadMode.bodyweight,
          setWeight: 10,
          bodyWeight: 75,
          loadFactor: 1.0,
        ),
        85,
      );
    });

    test('bodyweight mode defaults loadFactor to 1.0 when null', () {
      expect(
        effectiveLoad(
          mode: LoadMode.bodyweight,
          setWeight: 10,
          bodyWeight: 75,
          loadFactor: null,
        ),
        85,
      );
    });

    test('bodyweight mode treats null bodyWeight as 0', () {
      expect(
        effectiveLoad(
          mode: LoadMode.bodyweight,
          setWeight: 10,
          bodyWeight: null,
          loadFactor: 1.0,
        ),
        10,
      );
    });

    test('assisted mode subtracts assistance from body load', () {
      // 75 × 1.0 − 20 = 55 (assisted dip).
      expect(
        effectiveLoad(
          mode: LoadMode.assisted,
          setWeight: 20,
          bodyWeight: 75,
          loadFactor: 1.0,
        ),
        55,
      );
    });

    test('assisted mode clamps to 0 when assistance exceeds body load', () {
      // 75 × 0.64 = 48; assistance = 60 → clamps to 0.
      expect(
        effectiveLoad(
          mode: LoadMode.assisted,
          setWeight: 60,
          bodyWeight: 75,
          loadFactor: 0.64,
        ),
        0,
      );
    });
  });

  group('resolveLoadMode', () {
    final exercise = Exercise(
      id: 1,
      name: 'dip',
      muscleGroup: MuscleGroup.triceps,
      defaultLoadMode: LoadMode.bodyweight,
      bodyweightLoadFactor: 1.0,
    );

    test('uses exercise default when no overrides', () {
      expect(
        resolveLoadMode(exercise: exercise),
        LoadMode.bodyweight,
      );
    });

    test('workout exercise override beats catalog default', () {
      final wx = WorkoutExercise(
        workoutId: 1,
        exerciseId: 1,
        order: 0,
        sets: 3,
        rest: 60,
        loadModeOverride: LoadMode.weighted,
      );
      expect(
        resolveLoadMode(workoutExercise: wx, exercise: exercise),
        LoadMode.weighted,
      );
    });

    test('execution set override beats workout exercise override', () {
      final wx = WorkoutExercise(
        workoutId: 1,
        exerciseId: 1,
        order: 0,
        sets: 3,
        rest: 60,
        loadModeOverride: LoadMode.weighted,
      );
      final persistedSet = ExecutionSet(
        id: 1,
        executionId: 1,
        exerciseId: 1,
        setNumber: 1,
        reps: 10,
        weight: null,
        isCompleted: true,
        loadModeOverride: LoadMode.bodyweight,
      );
      expect(
        resolveLoadMode(set: persistedSet, workoutExercise: wx, exercise: exercise),
        LoadMode.bodyweight,
      );
      expect(
        resolveLoadMode(
          activeSetLoadModeOverride: LoadMode.assisted,
          workoutExercise: wx,
          exercise: exercise,
        ),
        LoadMode.assisted,
      );
    });
  });

  group('computeSetVolume with bodyweight exercise', () {
    final pushUp = Exercise(
      id: 1,
      name: 'pushUp',
      muscleGroup: MuscleGroup.chest,
      defaultLoadMode: LoadMode.bodyweight,
      bodyweightLoadFactor: 0.64,
    );

    final benchPress = Exercise(
      id: 2,
      name: 'benchPress',
      muscleGroup: MuscleGroup.chest,
      defaultLoadMode: LoadMode.weighted,
    );

    test('pure bodyweight push-up uses body weight × factor for volume', () {
      // 10 reps × (75 × 0.64) = 10 × 48 = 480.
      final set = _set(reps: 10, weight: null);
      expect(
        computeSetVolume(set, exercise: pushUp, latestBodyWeight: 75),
        480,
      );
    });

    test('weighted bench press uses set weight only', () {
      // 8 reps × 80 kg = 640.
      final set = _set(reps: 8, weight: 80);
      expect(
        computeSetVolume(set, exercise: benchPress, latestBodyWeight: 75),
        640,
      );
    });

    test('bodyweight with ballast adds added weight', () {
      // 8 reps × (75 × 0.64 + 10) = 8 × 58 = 464.
      final set = _set(reps: 8, weight: 10);
      expect(
        computeSetVolume(set, exercise: pushUp, latestBodyWeight: 75),
        464,
      );
    });

    test('workout-level override switches a BW exercise to weighted', () {
      final wx = WorkoutExercise(
        workoutId: 1,
        exerciseId: 1,
        order: 0,
        sets: 3,
        rest: 60,
        loadModeOverride: LoadMode.weighted,
      );
      // Same set on a dip machine: weight is read as the machine load,
      // body weight is ignored. 8 × 50 = 400.
      final set = _set(reps: 8, weight: 50);
      expect(
        computeSetVolume(
          set,
          exercise: pushUp,
          workoutExercise: wx,
          latestBodyWeight: 75,
        ),
        400,
      );
    });

    test('falls back to legacy "weight as-is" when exercise is null', () {
      final set = _set(reps: 8, weight: 50);
      expect(computeSetVolume(set), 400);
    });

    test('prefers bodyWeightSnapshot over latestBodyWeight fallback', () {
      final set = ExecutionSet(
        id: 1,
        executionId: 1,
        exerciseId: 1,
        setNumber: 1,
        reps: 10,
        weight: null,
        isCompleted: true,
        bodyWeightSnapshot: 80, // snapshot at execution date
      );
      // 10 × (80 × 0.64) = 512. Latest weight (70) is ignored.
      expect(
        computeSetVolume(set, exercise: pushUp, latestBodyWeight: 70),
        512,
      );
    });

    test('uses profileBodyWeightOnExecutionDate before latestBodyWeight', () {
      final set = _set(reps: 10, weight: null);
      // 10 × (78 × 0.64) = 499.2; latest=70 should be ignored.
      expect(
        computeSetVolume(
          set,
          exercise: pushUp,
          profileBodyWeightOnExecutionDate: 78,
          latestBodyWeight: 70,
        ),
        closeTo(499.2, 0.001),
      );
    });
  });

  group('estimated1RM (Epley)', () {
    test('returns null when weight is null or non-positive', () {
      expect(estimated1RM(weight: null, reps: 5), null);
      expect(estimated1RM(weight: 0, reps: 5), null);
    });

    test('returns null when reps is null or non-positive', () {
      expect(estimated1RM(weight: 100, reps: null), null);
      expect(estimated1RM(weight: 100, reps: 0), null);
    });

    test('returns weight when reps == 1', () {
      expect(estimated1RM(weight: 200, reps: 1), 200);
    });

    test('applies Epley formula for reps > 1', () {
      // 100 × (1 + 5/30) = 100 × 1.1667 ≈ 116.67
      final result = estimated1RM(weight: 100, reps: 5);
      expect(result, isNotNull);
      expect(result!, closeTo(116.67, 0.01));
    });
  });
}
