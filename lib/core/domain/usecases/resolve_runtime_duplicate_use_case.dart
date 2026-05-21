import '../../errors/result.dart';
import '../entities/local_backup_models.dart';
import '../repositories/local_backup_repository.dart';

class ResolveRuntimeDuplicateUseCase {
  final LocalBackupRepository _repository;

  const ResolveRuntimeDuplicateUseCase(this._repository);

  Future<Result<void>> call({
    required BackupConflictType entityType,
    required String leftEntityId,
    required String rightEntityId,
    required RuntimeDuplicateDecision decision,
    String? winnerId,
    Map<String, dynamic>? mergedAttributes,
  }) {
    return _repository.resolveRuntimeDuplicate(
      entityType: entityType,
      leftEntityId: leftEntityId,
      rightEntityId: rightEntityId,
      decision: decision,
      winnerId: winnerId,
      mergedAttributes: mergedAttributes,
    );
  }
}
