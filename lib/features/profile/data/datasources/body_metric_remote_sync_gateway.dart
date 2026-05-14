import '../../domain/entities/body_metric.dart';

/// Contract for remote body metric sync operations.
abstract interface class BodyMetricRemoteSyncGateway {
  String? get currentUserId;

  Future<List<BodyMetric>> fetchAllForCurrentUser();

  Future<DateTime> upsert({
    required String remoteId,
    required BodyMetric metric,
  });

  Future<void> delete(String remoteId);
}
