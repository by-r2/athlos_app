import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/services/cloud_sync_prefs.dart';
import '../../../../core/services/supabase_config.dart';
import '../../../../core/sync/sync_providers.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';

part 'user_cloud_sync_status_provider.g.dart';

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
  final DateTime? lastSuccessfulSyncAt;
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

  final prefs = ref.watch(cloudSyncPrefsProvider);
  final pending = await ref.watch(pendingSyncDirtyCountProvider.future);

  return UserCloudSyncStatus(
    isAvailable: true,
    pendingCount: pending,
    failedCount: 0,
    lastSuccessfulSyncAt: prefs.lastSuccessAt,
    lastAttemptAt: prefs.lastAttemptAt,
  );
}
