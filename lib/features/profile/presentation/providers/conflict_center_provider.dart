import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/repositories/local_backup_providers.dart';
import '../../../../core/domain/entities/local_backup_models.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/services/duplicate_scan_prefs.dart';

class ConflictCenterViewData {
  const ConflictCenterViewData({
    required this.runtimeLocalReviews,
    this.lastAnalyzedAt,
  });

  final List<BackupPendingReview> runtimeLocalReviews;
  final DateTime? lastAnalyzedAt;

  int get localDuplicateCount => runtimeLocalReviews.length;
}

final backupConflictCenterProvider =
    FutureProvider.autoDispose<ConflictCenterViewData>((ref) async {
      final scanUseCase = ref.watch(scanRuntimeLocalDuplicatesUseCaseProvider);
      final prefs = ref.watch(duplicateScanPrefsProvider);

      final localRuntimeResult = await scanUseCase();
      await prefs.recordAnalysis();

      return ConflictCenterViewData(
        runtimeLocalReviews: localRuntimeResult.getOrThrow(),
        lastAnalyzedAt: prefs.lastAnalyzedAt,
      );
    });
