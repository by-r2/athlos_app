import 'package:athlos_app/features/training/domain/entities/execution_set.dart';
import 'package:athlos_app/features/training/domain/entities/execution_set_segment.dart';
import 'package:athlos_app/features/training/presentation/helpers/workout_share_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

ExecutionSet _set({
  required int id,
  int? reps = 10,
  double? weight = 50,
  bool isCompleted = true,
  bool isWarmup = false,
  List<ExecutionSetSegment> segments = const [],
}) =>
    ExecutionSet(
      id: id,
      executionId: 1,
      exerciseId: 1,
      setNumber: id,
      reps: reps,
      weight: weight,
      isCompleted: isCompleted,
      isWarmup: isWarmup,
      segments: segments,
    );

void main() {
  group('computeWorkoutShareMetrics', () {
    test('soma volume e conta sets completos para sets normais', () {
      final metrics = computeWorkoutShareMetrics([
        _set(id: 1, reps: 10, weight: 50), // 500
        _set(id: 2, reps: 10, weight: 60), // 600
        _set(id: 3, reps: 5, weight: 70, isCompleted: false),
      ]);
      expect(metrics.totalVolume, 1100);
      expect(metrics.totalCompletedSets, 2);
      expect(metrics.totalPlannedSets, 3);
    });

    test('exclui warmups do volume mas mantem na contagem de sets', () {
      final metrics = computeWorkoutShareMetrics([
        _set(id: 1, reps: 10, weight: 30, isWarmup: true), // volume 0
        _set(id: 2, reps: 10, weight: 60), // 600
      ]);
      expect(metrics.totalVolume, 600);
      // Counter mantem semantica historica (conta todos sets completos).
      expect(metrics.totalCompletedSets, 2);
      expect(metrics.totalPlannedSets, 2);
    });

    test('soma drop-set segments quando presentes', () {
      final metrics = computeWorkoutShareMetrics([
        _set(
          id: 1,
          segments: const [
            ExecutionSetSegment(
              id: 1,
              executionSetId: 1,
              segmentOrder: 1,
              reps: 10,
              weight: 50,
            ),
            ExecutionSetSegment(
              id: 2,
              executionSetId: 1,
              segmentOrder: 2,
              reps: 8,
              weight: 40,
            ),
          ],
        ), // 500 + 320 = 820
      ]);
      expect(metrics.totalVolume, 820);
      expect(metrics.totalCompletedSets, 1);
    });
  });
}
