enum BackupConflictType { exercise }

enum BackupPendingReviewType {
  fuzzyMatchCandidate,
}

enum RuntimeDuplicateDecision {
  notDuplicate,
  confirmDuplicate,
  mergeAttributes,
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
