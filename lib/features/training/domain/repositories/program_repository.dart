import '../../../../core/errors/result.dart';
import '../entities/training_program.dart';

/// Contract for training program (mesocycle) persistence.
abstract interface class ProgramRepository {
  Future<Result<List<TrainingProgram>>> getAll();
  Future<Result<TrainingProgram?>> getById(String id);
  Future<Result<TrainingProgram?>> getActive();
  Future<Result<String>> create(TrainingProgram program);
  Future<Result<void>> update(TrainingProgram program);

  /// Activates [programId] and archives any currently active program.
  Future<Result<void>> activate(String programId);
  Future<Result<void>> archive(String programId);

  /// Permanently deletes the program. Execution history is preserved.
  Future<Result<void>> delete(String programId);

  /// Number of finished sessions for this program.
  Future<Result<int>> getSessionCount(String programId);

  /// Enter or exit deload mode for [programId].
  Future<Result<void>> setDeloadActive(String programId, {required bool active});
}
