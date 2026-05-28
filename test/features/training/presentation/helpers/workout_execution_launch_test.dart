import 'package:athlos_app/features/training/domain/entities/workout_execution.dart';
import 'package:athlos_app/features/training/presentation/helpers/workout_execution_blocking.dart';
import 'package:athlos_app/features/training/presentation/providers/active_execution_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const targetWorkoutId = 'workout-b';
  final dangling = WorkoutExecution(
    id: 'exec-1',
    workoutId: 'workout-a',
    programId: 'program-1',
    startedAt: DateTime(2025, 1, 1),
  );

  group('blockingInProgressWorkout', () {
    test('returns null when no in-progress session', () {
      expect(
        blockingInProgressWorkout(
          dangling: null,
          active: null,
          targetWorkoutId: targetWorkoutId,
        ),
        isNull,
      );
    });

    test('returns null when dangling matches target workout', () {
      final sameWorkoutDangling = WorkoutExecution(
        id: dangling.id,
        workoutId: targetWorkoutId,
        programId: dangling.programId,
        startedAt: dangling.startedAt,
      );
      expect(
        blockingInProgressWorkout(
          dangling: sameWorkoutDangling,
          active: null,
          targetWorkoutId: targetWorkoutId,
        ),
        isNull,
      );
    });

    test('returns blocking when dangling is a different workout', () {
      final blocking = blockingInProgressWorkout(
        dangling: dangling,
        active: null,
        targetWorkoutId: targetWorkoutId,
      );
      expect(blocking?.executionId, 'exec-1');
      expect(blocking?.workoutId, 'workout-a');
    });

    test('prefers active execution over dangling when both exist', () {
      const active = ActiveExecutionState(
        executionId: 'exec-active',
        workoutId: 'workout-c',
        exerciseSets: {},
        exercises: [],
      );
      final blocking = blockingInProgressWorkout(
        dangling: dangling,
        active: active,
        targetWorkoutId: targetWorkoutId,
      );
      expect(blocking?.executionId, 'exec-active');
      expect(blocking?.workoutId, 'workout-c');
    });

    test('returns null when active matches target workout', () {
      const active = ActiveExecutionState(
        executionId: 'exec-active',
        workoutId: targetWorkoutId,
        exerciseSets: {},
        exercises: [],
      );
      expect(
        blockingInProgressWorkout(
          dangling: dangling,
          active: active,
          targetWorkoutId: targetWorkoutId,
        ),
        isNull,
      );
    });
  });
}
