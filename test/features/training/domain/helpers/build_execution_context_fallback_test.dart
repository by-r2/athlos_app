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

    const incline = Exercise(
      id: 'ex-incline',
      name: 'inclinePress',
      muscleGroup: MuscleGroup.chest,
      isVerified: true,
    );

    const template = WorkoutExercise(
      id: 'we-1',
      workoutId: 'w-1',
      exerciseId: 'ex-incline',
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
        exercisesById: {'ex-incline': incline},
        sessionExerciseIds: {'ex-incline', 'ex-bench'},
      );

      expect(snapshot.schemaVersion, ExecutionContextFallback.currentSchemaVersion);
      final entry = snapshot.exercises['ex-incline'];
      expect(entry, isNotNull);
      expect(entry!.displayName, 'inclinePress');
      expect(entry.loadModeOverride, LoadMode.bodyweight);
    });

    test('records substitution on template line in snapshot', () {
      final snapshot = buildExecutionContextFallback(
        templateExercises: [template],
        exercisesById: {
          'ex-incline': incline,
          'ex-bench': bench,
        },
        sessionExerciseIds: {'ex-incline', 'ex-bench'},
        substitutionsByRowId: {'we-1': 'ex-bench'},
      );

      final line = snapshot.lines['we-1'];
      expect(line, isNotNull);
      expect(line!.exerciseId, 'ex-incline');
      expect(line.substitutedFromExerciseId, 'ex-bench');
      expect(line.substitutedFromDisplayName, 'benchPress');
      expect(line.wasSubstituted, isTrue);
    });

    test('round-trips through JSON', () {
      final built = buildExecutionContextFallback(
        templateExercises: [template],
        exercisesById: {'ex-incline': incline, 'ex-bench': bench},
        sessionExerciseIds: {'ex-incline', 'ex-bench'},
        substitutionsByRowId: {'we-1': 'ex-bench'},
      );
      final restored = ExecutionContextFallback.fromJson(built.toJson());
      expect(restored.lines['we-1']?.substitutedFromExerciseId, 'ex-bench');
      expect(restored.exercises['ex-incline']?.displayName, 'inclinePress');
    });
  });
}
