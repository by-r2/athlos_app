import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/services/cloud_sync_prefs.dart';
import '../../../../core/services/supabase_config.dart';
import '../../../../core/sync/sync_providers.dart';
import '../../../../core/sync/sync_status.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';

part 'user_cloud_sync_status_provider.g.dart';

/// Aggregated cloud sync status for Profile > Dados.
class UserCloudSyncStatus {
  const UserCloudSyncStatus({
    required this.isAvailable,
    required this.pendingCount,
    required this.failedCount,
    required this.lastSuccessfulSyncAt,
    required this.lastAttemptAt,
  });

  const UserCloudSyncStatus.unavailable()
    : isAvailable = false,
      pendingCount = 0,
      failedCount = 0,
      lastSuccessfulSyncAt = null,
      lastAttemptAt = null;

  final bool isAvailable;
  final int pendingCount;
  final int failedCount;

  /// Last sync without pending/failed records (persisted + derived).
  final DateTime? lastSuccessfulSyncAt;

  /// Last sync attempt (success or not).
  final DateTime? lastAttemptAt;

  bool get hasPending => pendingCount > 0;

  bool get hasFailed => failedCount > 0;

  bool get isUpToDate => !hasPending && !hasFailed;

  bool get hasEverSynced =>
      lastSuccessfulSyncAt != null || lastAttemptAt != null;
}

@riverpod
Future<UserCloudSyncStatus> userCloudSyncStatus(Ref ref) async {
  if (!isSupabaseConfigured) return const UserCloudSyncStatus.unavailable();
  if (ref.watch(authProvider).value == null) {
    return const UserCloudSyncStatus.unavailable();
  }

  final store = ref.watch(syncRecordStoreProvider);
  final prefs = ref.watch(cloudSyncPrefsProvider);
  final tables = ref.watch(userOwnedSyncRegistryProvider).targets
      .map((target) => target.tableName)
      .toSet();

  var pendingCount = 0;
  var failedCount = 0;
  DateTime? lastPushedAt;

  for (final table in tables) {
    final records = await store.listForTable(table);
    for (final record in records) {
      if (record.status == SyncStatus.pending) pendingCount++;
      if (record.status == SyncStatus.failed) failedCount++;
      final pushedAt = record.lastPushedAt;
      if (pushedAt != null &&
          (lastPushedAt == null || pushedAt.isAfter(lastPushedAt))) {
        lastPushedAt = pushedAt;
      }
    }
  }

  final lastSuccess = prefs.lastSuccessAt ?? lastPushedAt;

  return UserCloudSyncStatus(
    isAvailable: true,
    pendingCount: pendingCount,
    failedCount: failedCount,
    lastSuccessfulSyncAt: lastSuccess,
    lastAttemptAt: prefs.lastAttemptAt,
  );
}
