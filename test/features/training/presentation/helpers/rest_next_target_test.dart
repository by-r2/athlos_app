import 'package:athlos_app/features/training/domain/entities/workout_exercise.dart';
import 'package:athlos_app/features/training/presentation/helpers/rest_next_target.dart';
import 'package:athlos_app/features/training/presentation/providers/active_execution_state.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutExercise _exercise({
  required int exerciseId,
  required int order,
  int? groupId,
}) => WorkoutExercise(
  workoutId: 1,
  exerciseId: exerciseId,
  order: order,
  sets: 3,
  minReps: 10,
  maxReps: 10,
  rest: 60,
  groupId: groupId,
);

SetEntry _set(int setNumber, {required bool isCompleted}) =>
    SetEntry(setNumber: setNumber, isCompleted: isCompleted);

ActiveExecutionState _execution({
  required List<WorkoutExercise> exercises,
  required Map<int, List<SetEntry>> exerciseSets,
}) => ActiveExecutionState(
  executionId: 1,
  workoutId: 1,
  exercises: exercises,
  exerciseSets: exerciseSets,
);

void main() {
  group('findNextRestTarget', () {
    test('returns the first exercise of the next superset round', () {
      final exec = _execution(
        exercises: [
          _exercise(exerciseId: 10, order: 0, groupId: 1),
          _exercise(exerciseId: 20, order: 1, groupId: 1),
        ],
        exerciseSets: {
          10: [_set(1, isCompleted: true), _set(2, isCompleted: false)],
          20: [_set(1, isCompleted: true), _set(2, isCompleted: false)],
        },
      );

      final next = findNextRestTarget(
        exec,
        focusedExerciseIndex: 1,
        focusedSetNumber: 1,
      );

      expect(next, (exerciseIndex: 0, setNumber: 2));
    });

    test('keeps regular exercises on their next pending set', () {
      final exec = _execution(
        exercises: [_exercise(exerciseId: 10, order: 0)],
        exerciseSets: {
          10: [_set(1, isCompleted: true), _set(2, isCompleted: false)],
        },
      );

      final next = findNextRestTarget(
        exec,
        focusedExerciseIndex: 0,
        focusedSetNumber: 1,
      );

      expect(next, (exerciseIndex: 0, setNumber: 2));
    });

    test(
      'falls back to the next workout exercise after a completed superset',
      () {
        final exec = _execution(
          exercises: [
            _exercise(exerciseId: 10, order: 0, groupId: 1),
            _exercise(exerciseId: 20, order: 1, groupId: 1),
            _exercise(exerciseId: 30, order: 2),
          ],
          exerciseSets: {
            10: [_set(1, isCompleted: true)],
            20: [_set(1, isCompleted: true)],
            30: [_set(1, isCompleted: false)],
          },
        );

        final next = findNextRestTarget(
          exec,
          focusedExerciseIndex: 1,
          focusedSetNumber: 1,
        );

        expect(next, (exerciseIndex: 2, setNumber: 1));
      },
    );
  });
}
