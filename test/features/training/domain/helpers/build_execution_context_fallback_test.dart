import 'package:athlos_app/features/training/domain/entities/execution_context_fallback.dart';
import 'package:athlos_app/features/training/domain/entities/exercise.dart';
import 'package:athlos_app/features/training/domain/entities/workout_exercise.dart';
import 'package:athlos_app/features/training/domain/enums/load_mode.dart';
import 'package:athlos_app/features/training/domain/enums/muscle_group.dart';
import 'package:athlos_app/features/training/domain/helpers/build_execution_context_fallback.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildExecutionContextFallback', () {
    const bench = Exercise(
      id: 'ex-bench',
      name: 'benchPress',
      muscleGroup: MuscleGroup.chest,
      isVerified: true,
      defaultLoadMode: LoadMode.weighted,
    );

  const template = WorkoutExercise(
      id: 'we-1',
      workoutId: 'w-1',
      exerciseId: 'ex-bench',
      sortOrder: 0,
      sets: 3,
      minReps: 8,
      maxReps: 12,
      restSeconds: 90,
      isUnilateral: false,
      loadModeOverride: LoadMode.bodyweight,
    );

    test('includes session exercise ids and merges template fields', () {
      final snapshot = buildExecutionContextFallback(
        templateExercises: [template],
        exercisesById: {'ex-bench': bench},
        sessionExerciseIds: {'ex-bench'},
      );

      expect(snapshot.schemaVersion, 1);
      final entry = snapshot.exercises['ex-bench'];
      expect(entry, isNotNull);
      expect(entry!.displayName, 'benchPress');
      expect(entry.isVerified, isTrue);
      expect(entry.muscleGroup, MuscleGroup.chest);
      expect(entry.loadModeOverride, LoadMode.bodyweight);
    });

    test('round-trips through JSON', () {
      final built = buildExecutionContextFallback(
        templateExercises: [template],
        exercisesById: {'ex-bench': bench},
        sessionExerciseIds: {'ex-bench'},
      );
      final restored = ExecutionContextFallback.fromJson(built.toJson());
      expect(restored.exercises['ex-bench']?.displayName, 'benchPress');
      expect(restored.exercises['ex-bench']?.loadModeOverride, LoadMode.bodyweight);
    });
  });
}
