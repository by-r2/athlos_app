import '../../errors/result.dart';
import '../entities/local_backup_models.dart';

/// Runtime duplicate detection and resolution (Conflict Center).
abstract interface class LocalBackupRepository {
  Future<Result<List<BackupPendingReview>>> scanRuntimeLocalDuplicates();

  Future<Result<void>> resolveRuntimeDuplicate({
    required BackupConflictType entityType,
    required String leftEntityId,
    required String rightEntityId,
    required RuntimeDuplicateDecision decision,
    String? winnerId,
    Map<String, dynamic>? mergedAttributes,
  });

  Future<Result<Map<String, dynamic>>> loadEntityAttributes({
    required BackupConflictType entityType,
    required String entityId,
  });
}
