import '../../../../core/sync/sync_deferred_exception.dart';

String requireRemoteId(String? remoteId, String message) {
  if (remoteId == null) throw SyncDeferredException(message);
  return remoteId;
}
