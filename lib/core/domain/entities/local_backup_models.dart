enum BackupConflictType { exercise }

enum BackupPendingReviewType {
  fuzzyMatchCandidate,
}

enum RuntimeDuplicateDecision {
  notDuplicate,
  confirmDuplicate,
  mergeAttributes,
}

/// Ids hard-deleted locally during duplicate merge; must be removed on Supabase too.
///
/// [removedExerciseId] is always a **non-verified** custom copy; verified catalog
/// rows are never included.
class RuntimeDuplicateMergeSyncPayload {
  const RuntimeDuplicateMergeSyncPayload({
    required this.removedExerciseId,
    this.removedWorkoutExerciseIds = const [],
    this.removedProgressionRuleIds = const [],
  });

  final String removedExerciseId;
  final List<String> removedWorkoutExerciseIds;
  final List<String> removedProgressionRuleIds;
}

class BackupPendingReview {
  final String reviewId;
  final BackupPendingReviewType type;
  final BackupConflictType entityType;
  final String importedLabel;
  final String? existingLabel;
  final double? similarityScore;
  final String? leftEntityId;
  final String? rightEntityId;

  final bool isLeftVerified;
  final bool isRightVerified;

  const BackupPendingReview({
    required this.reviewId,
    required this.type,
    required this.entityType,
    required this.importedLabel,
    this.existingLabel,
    this.similarityScore,
    this.leftEntityId,
    this.rightEntityId,
    this.isLeftVerified = false,
    this.isRightVerified = false,
  });

  bool get hasVerifiedSide => isLeftVerified || isRightVerified;
}
