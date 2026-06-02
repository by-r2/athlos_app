import 'package:athlos_app/core/errors/result.dart';
import 'package:athlos_app/features/training/domain/entities/exercise.dart';
import 'package:athlos_app/features/training/domain/entities/workout_exercise.dart';
import 'package:athlos_app/features/training/domain/enums/exercise_type.dart';
import 'package:athlos_app/features/training/domain/enums/muscle_group.dart';
import 'package:athlos_app/features/training/domain/usecases/substitute_workout_exercise.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const useCase = SubstituteWorkoutExercise();

  final inclinePress = Exercise(
    id: 'incline',
    name: 'Incline Press',
    muscleGroup: MuscleGroup.chest,
    type: ExerciseType.strength,
    isVerified: true,
  );

  final row = WorkoutExercise(
    id: 'row-1',
    workoutId: 'w1',
    exerciseId: 'bench',
    sortOrder: 0,
    sets: 3,
    minReps: 8,
    maxReps: 12,
    restSeconds: 90,
  );

  test('returns updated row with new catalog exercise id', () {
    final result = useCase(
      SubstituteWorkoutExerciseParams(
        row: row,
        replacement: inclinePress,
        workoutExercises: [row],
      ),
    );

    expect(result, isA<Success<WorkoutExercise>>());
    final updated = (result as Success<WorkoutExercise>).value;
    expect(updated.id, row.id);
    expect(updated.exerciseId, inclinePress.id);
    expect(updated.sets, row.sets);
    expect(updated.minReps, row.minReps);
  });

  test('fails when replacement is already in the workout', () {
    final otherRow = WorkoutExercise(
      id: 'row-2',
      workoutId: 'w1',
      exerciseId: inclinePress.id,
      sortOrder: 1,
      sets: 3,
      minReps: 10,
      maxReps: 10,
      restSeconds: 60,
    );

    final result = useCase(
      SubstituteWorkoutExerciseParams(
        row: row,
        replacement: inclinePress,
        workoutExercises: [row, otherRow],
      ),
    );

    expect(result, isA<Failure<WorkoutExercise>>());
  });

  test('adapts prescription when replacing strength with cardio', () {
    final treadmill = Exercise(
      id: 'run',
      name: 'Treadmill',
      muscleGroup: MuscleGroup.cardio,
      type: ExerciseType.cardio,
      isVerified: true,
    );

    final result = useCase(
      SubstituteWorkoutExerciseParams(
        row: row,
        replacement: treadmill,
        workoutExercises: [row],
      ),
    );

    final updated = (result as Success<WorkoutExercise>).value;
    expect(updated.exerciseId, treadmill.id);
    expect(updated.minReps, isNull);
    expect(updated.durationSeconds, isNotNull);
  });
}
