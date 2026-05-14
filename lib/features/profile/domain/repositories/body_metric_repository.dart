import '../../../../core/errors/result.dart';
import '../entities/body_metric.dart';

/// Contract for body weight / composition timeline persistence.
abstract interface class BodyMetricRepository {
  /// All records, most recent first.
  Future<Result<List<BodyMetric>>> getAll();

  /// Most recent record, or null.
  Future<Result<BodyMetric?>> getLatest();

  /// Latest record with [recordedAt] on or before [instant], or null.
  Future<Result<BodyMetric?>> getLatestAtOrBefore(DateTime instant);

  Future<Result<int>> create(BodyMetric metric);
  Future<Result<void>> update(BodyMetric metric);
  Future<Result<void>> delete(int id);

  /// Reconciles the local timeline with the authenticated remote account.
  Future<Result<void>> reconcileOnAuth();

  /// Pushes pending or failed local entries to the remote account.
  Future<Result<void>> pushPendingLocalChanges();
}
