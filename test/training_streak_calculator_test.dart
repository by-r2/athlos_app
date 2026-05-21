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
          id: 'exec-1',
          workoutId: 'w-10',
          programId: 'p-1',
          startedAt: t0,
          finishedAt: t0,
        ),
        WorkoutExecution(
          id: 'exec-2',
          workoutId: 'w-99',
          programId: 'p-2',
          startedAt: t1,
          finishedAt: t1,
        ),
      ];
      final cycles = <String, List<String>>{
        'p-1': ['w-10', 'w-20'],
        'p-2': ['w-30', 'w-99'],
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
          id: 'exec-1',
          workoutId: 'w-30',
          programId: 'p-1',
          startedAt: t0,
          finishedAt: t0,
        ),
        WorkoutExecution(
          id: 'exec-2',
          workoutId: 'w-20',
          programId: 'p-1',
          startedAt: t1,
          finishedAt: t1,
        ),
      ];
      final cycles = <String, List<String>>{
        'p-1': ['w-20', 'w-30', 'w-10'],
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
