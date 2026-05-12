import '../../../../core/errors/result.dart';
import '../entities/execution_set.dart';
import '../entities/execution_set_segment.dart';
import '../repositories/workout_execution_repository.dart';

/// Parameters for [CompleteSetUseCase].
class CompleteSetParams {
  final ExecutionSet set;
  final List<ExecutionSetSegment> segments;

  const CompleteSetParams({required this.set, this.segments = const []});
}

/// Persists a completed set and its drop-set segments (if any).
///
/// Handles insert vs update based on [ExecutionSet.id]:
/// - `id == 0` → new set (insert)
/// - `id > 0` → existing set (update)
///
/// Returns the persisted set ID.
class CompleteSetUseCase {
  final WorkoutExecutionRepository _repository;

  const CompleteSetUseCase(this._repository);

  Future<Result<int>> call(CompleteSetParams params) async {
    final int setId;

    if (params.set.id == 0) {
      final result = await _repository.logSet(params.set);
      switch (result) {
        case Success(:final value):
          setId = value;
        case Failure(:final exception):
          return Failure(exception);
      }
    } else {
      final result = await _repository.updateSet(params.set);
      switch (result) {
        case Success():
          setId = params.set.id;
        case Failure(:final exception):
          return Failure(exception);
      }
    }

    if (params.segments.length > 1) {
      final mapped = params.segments
          .asMap()
          .entries
          .map(
            (e) => ExecutionSetSegment(
              id: 0,
              executionSetId: setId,
              segmentOrder: e.key + 1,
              reps: e.value.reps,
              weight: e.value.weight,
            ),
          )
          .toList();

      final result = await _repository.saveSegments(setId, mapped);
      switch (result) {
        case Success():
          break;
        case Failure(:final exception):
          return Failure(exception);
      }
    }

    return Success(setId);
  }
}
