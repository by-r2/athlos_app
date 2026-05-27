import 'package:athlos_app/features/training/domain/entities/workout_execution.dart';
import 'package:athlos_app/features/training/domain/helpers/training_frequency_streak_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('computeFrequencyStreaks', () {
    test('counts consecutive secured weeks', () {
      const target = 3;
      final mon1 = DateTime(2026, 1, 5);
      final chronological = <WorkoutExecution>[
        for (var i = 0; i < 3; i++)
          WorkoutExecution(
            id: 'exec-${i + 1}',
            workoutId: 'w-1',
            programId: 'p-1',
            startedAt: mon1.add(Duration(days: i)),
            finishedAt: mon1.add(Duration(days: i)),
          ),
        for (var i = 0; i < 3; i++)
          WorkoutExecution(
            id: 'exec-${i + 4}',
            workoutId: 'w-1',
            programId: 'p-1',
            startedAt: mon1.add(Duration(days: 7 + i)),
            finishedAt: mon1.add(Duration(days: 7 + i)),
          ),
      ];
      final r = computeFrequencyStreaks(chronological, target);
      expect(r.best, greaterThanOrEqualTo(2));
    });
  });
}
