import '../../domain/entities/body_metric.dart';

/// Contract for remote body metric sync operations.
abstract interface class BodyMetricRemoteSyncGateway {
  String? get currentUserId;

  Future<List<BodyMetric>> fetchAllForCurrentUser();

  Future<List<BodyMetric>> fetchUpdatedSince(DateTime lastPullAt);

  Future<DateTime> upsert({
    required String id,
    required BodyMetric metric,
  });

  Future<void> delete(String id);
}
