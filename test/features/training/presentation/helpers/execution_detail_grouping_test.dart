import 'package:athlos_app/features/training/domain/entities/execution_context_fallback.dart';
import 'package:athlos_app/features/training/domain/entities/execution_set.dart';
import 'package:athlos_app/features/training/domain/enums/muscle_group.dart';
import 'package:athlos_app/features/training/presentation/helpers/execution_detail_grouping.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('groupExecutionSetsForDetail', () {
    test('groups legacy sets by catalog exercise id', () {
      final groups = groupExecutionSetsForDetail(
        sets: const [
          ExecutionSet(
            id: '1',
            executionId: 'e',
            exerciseId: 'a',
            setNumber: 1,
            isCompleted: true,
          ),
          ExecutionSet(
            id: '2',
            executionId: 'e',
            exerciseId: 'b',
            setNumber: 1,
            isCompleted: true,
          ),
        ],
      );

      expect(groups.length, 2);
    });

    test('groups by workout line and splits performed catalog ids', () {
      final fallback = ExecutionContextFallback(
        exercises: const {},
        lines: {
          'row-1': ExecutionContextFallbackLine(
            workoutExerciseId: 'row-1',
            exerciseId: 'incline',
            substitutedFromExerciseId: 'bench',
            displayName: 'Incline',
            substitutedFromDisplayName: 'Bench',
            muscleGroup: MuscleGroup.chest,
            sortOrder: 0,
          ),
        },
      );

      final groups = groupExecutionSetsForDetail(
        sets: const [
          ExecutionSet(
            id: '1',
            executionId: 'e',
            exerciseId: 'bench',
            workoutExerciseId: 'row-1',
            setNumber: 1,
            isCompleted: true,
          ),
          ExecutionSet(
            id: '2',
            executionId: 'e',
            exerciseId: 'incline',
            workoutExerciseId: 'row-1',
            setNumber: 2,
            isCompleted: true,
          ),
        ],
        fallback: fallback,
      );

      expect(groups.length, 1);
      expect(groups.first.performedExerciseIds, ['bench', 'incline']);
    });
  });
}
