import 'package:athlos_app/features/training/presentation/helpers/rep_performance.dart';
import 'package:athlos_app/features/training/presentation/providers/active_execution_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('workSetsQualifyForSuggestedWeightIncrease', () {
    test('returns false while some work sets are still incomplete', () {
      final sets = [
        const SetEntry(setNumber: 1, isCompleted: true, reps: 10, weight: 50),
        const SetEntry(setNumber: 2, isCompleted: false, reps: 10, weight: 50),
        const SetEntry(setNumber: 3, isCompleted: false, reps: 10, weight: 50),
      ];
      expect(
        workSetsQualifyForSuggestedWeightIncrease(
          latestSetsForExercise: sets,
          maxReps: 10,
        ),
        isFalse,
      );
    });

    test(
      'returns true when every planned work set completed at or above maxReps',
      () {
        final sets = [
          const SetEntry(setNumber: 1, isCompleted: true, reps: 10, weight: 50),
          const SetEntry(setNumber: 2, isCompleted: true, reps: 12, weight: 50),
        ];
        expect(
          workSetsQualifyForSuggestedWeightIncrease(
            latestSetsForExercise: sets,
            maxReps: 10,
          ),
          isTrue,
        );
      },
    );

    test('ignores warm-up rows for completion gate', () {
      final sets = [
        const SetEntry(
          setNumber: 1,
          isWarmup: true,
          isCompleted: true,
          reps: 12,
          weight: 40,
        ),
        const SetEntry(setNumber: 2, isCompleted: true, reps: 10, weight: 50),
      ];
      expect(
        workSetsQualifyForSuggestedWeightIncrease(
          latestSetsForExercise: sets,
          maxReps: 10,
        ),
        isTrue,
      );
    });

    test('warm-up misses maxReps without blocking qualification', () {
      final sets = [
        const SetEntry(
          setNumber: 1,
          isWarmup: true,
          isCompleted: true,
          reps: 6,
          weight: 20,
        ),
        const SetEntry(setNumber: 2, isCompleted: true, reps: 10, weight: 50),
      ];
      expect(
        workSetsQualifyForSuggestedWeightIncrease(
          latestSetsForExercise: sets,
          maxReps: 10,
        ),
        isTrue,
      );
    });
  });

  group('repsForAggregateLoadFeedback', () {
    test('averages both sides when unilateral limbs recorded', () {
      expect(
        repsForAggregateLoadFeedback(reps: 12, leftReps: 8, rightReps: 12),
        10,
      );
    });

    test('falls back to single side or primary reps', () {
      expect(
        repsForAggregateLoadFeedback(reps: 11, leftReps: 9, rightReps: null),
        9,
      );
      expect(
        repsForAggregateLoadFeedback(reps: 11, leftReps: null, rightReps: null),
        11,
      );
    });
  });

  group('nextRoundedSuggestedWorkingWeightKg', () {
    test('returns 2.5% bump quantized to quarter kg', () {
      final sets = [
        const SetEntry(setNumber: 1, isCompleted: true, reps: 10, weight: 50),
      ];
      expect(
        nextRoundedSuggestedWorkingWeightKg(latestSetsForExercise: sets),
        51.25,
      );
    });

    test('uses custom fraction when provided', () {
      final sets = [
        const SetEntry(setNumber: 1, isCompleted: true, reps: 10, weight: 50),
      ];
      expect(
        nextRoundedSuggestedWorkingWeightKg(
          latestSetsForExercise: sets,
          loadIncreaseFraction: 0.05,
        ),
        52.5,
      );
    });

    test('forces at least +0.25 kg when rounded bump stalls', () {
      final sets = [
        const SetEntry(setNumber: 1, isCompleted: true, reps: 10, weight: 1.0),
      ];
      expect(
        nextRoundedSuggestedWorkingWeightKg(latestSetsForExercise: sets),
        1.25,
      );
    });
  });

  group('computeLoadAdviceBand', () {
    test('fixed target mild heavy when averaging one rep under', () {
      expect(
        computeLoadAdviceBand(
          averageReps: 9.0,
          minReps: 10,
          maxReps: 10,
          isAmrap: false,
        ),
        LoadAdviceBand.weightTooHeavyMild,
      );
    });

    test('fixed target severely light beyond +2 reps above target', () {
      expect(
        computeLoadAdviceBand(
          averageReps: 15,
          minReps: 10,
          maxReps: 10,
          isAmrap: false,
        ),
        LoadAdviceBand.weightTooLightSevere,
      );
    });

    test('narrow band mildly light slightly above ceiling', () {
      expect(
        computeLoadAdviceBand(
          averageReps: 13,
          minReps: 8,
          maxReps: 12,
          isAmrap: false,
        ),
        LoadAdviceBand.weightTooLightMild,
      );
    });
  });
}
