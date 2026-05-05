import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/errors/result.dart';
import '../../data/repositories/profile_providers.dart';
import '../../domain/entities/body_metric.dart';

part 'body_metric_notifier.g.dart';

/// All body metrics, most recent first.
@riverpod
class BodyMetricList extends _$BodyMetricList {
  @override
  Future<List<BodyMetric>> build() async {
    final repo = ref.watch(bodyMetricRepositoryProvider);
    final result = await repo.getAll();
    return result.getOrThrow();
  }

  Future<void> add({
    required double weight,
    double? bodyFatPercent,
    DateTime? recordedAt,
  }) async {
    final repo = ref.read(bodyMetricRepositoryProvider);
    final metric = BodyMetric(
      id: 0,
      weight: weight,
      bodyFatPercent: bodyFatPercent,
      recordedAt: recordedAt ?? DateTime.now(),
    );
    final result = await repo.create(metric);
    result.getOrThrow();
    if (ref.mounted) ref.invalidateSelf();
  }

  Future<void> remove(int id) async {
    final repo = ref.read(bodyMetricRepositoryProvider);
    final result = await repo.delete(id);
    result.getOrThrow();
    if (ref.mounted) ref.invalidateSelf();
  }
}

/// Latest body weight (convenience for load calculations and display).
@riverpod
Future<double?> latestBodyWeight(Ref ref) async {
  final metrics = await ref.watch(bodyMetricListProvider.future);
  if (metrics.isEmpty) return null;
  return metrics.first.weight;
}

