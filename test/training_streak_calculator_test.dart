import 'package:athlos_app/features/training/domain/entities/workout_execution.dart';
import 'package:athlos_app/features/training/domain/helpers/training_streak_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('computeCycleStreaks', () {
    test('continues streak across different programs', () {
      final t0 = DateTime(2026, 1, 5);
      final t1 = t0.add(const Duration(hours: 2));
      final chronological = [
        WorkoutExecution(
          id: 1,
          workoutId: 10,
          programId: 1,
          startedAt: t0,
          finishedAt: t0,
        ),
        WorkoutExecution(
          id: 2,
          workoutId: 99,
          programId: 2,
          startedAt: t1,
          finishedAt: t1,
        ),
      ];
      final cycles = <int, List<int>>{
        1: [10, 20],
        2: [30, 99],
      };
      final r = computeCycleStreaks(chronological, cycles);
      expect(r.current, 2);
      expect(r.best, 2);
    });

    test('resets when same program breaks cycle order', () {
      final t0 = DateTime(2026, 1, 5);
      final t1 = t0.add(const Duration(hours: 1));
      final chronological = [
        WorkoutExecution(
          id: 1,
          workoutId: 30,
          programId: 1,
          startedAt: t0,
          finishedAt: t0,
        ),
        WorkoutExecution(
          id: 2,
          workoutId: 20,
          programId: 1,
          startedAt: t1,
          finishedAt: t1,
        ),
      ];
      final cycles = <int, List<int>>{
        1: [20, 30, 10],
      };
      final r = computeCycleStreaks(chronological, cycles);
      expect(r.current, 1);
      expect(r.best, 1);
    });
  });

  group('computeFrequencyStreaks', () {
    test('counts consecutive secured weeks', () {
      const target = 3;
      final mon1 = DateTime(2026, 1, 5);
      final chronological = <WorkoutExecution>[
        for (var i = 0; i < 3; i++)
          WorkoutExecution(
            id: i + 1,
            workoutId: 1,
            programId: 1,
            startedAt: mon1.add(Duration(days: i)),
            finishedAt: mon1.add(Duration(days: i)),
          ),
        for (var i = 0; i < 3; i++)
          WorkoutExecution(
            id: i + 4,
            workoutId: 1,
            programId: 1,
            startedAt: mon1.add(Duration(days: 7 + i)),
            finishedAt: mon1.add(Duration(days: 7 + i)),
          ),
      ];
      final r = computeFrequencyStreaks(chronological, target);
      expect(r.best, greaterThanOrEqualTo(2));
    });
  });
}
