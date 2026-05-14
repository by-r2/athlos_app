/// A single body weight / composition measurement at a point in time.
class BodyMetric {
  final int id;
  final double weight;
  final double? bodyFatPercent;
  final DateTime recordedAt;
  final String? remoteId;
  final DateTime? lastSyncedAt;

  const BodyMetric({
    required this.id,
    required this.weight,
    this.bodyFatPercent,
    required this.recordedAt,
    this.remoteId,
    this.lastSyncedAt,
  });

  BodyMetric copyWith({
    int? id,
    double? weight,
    double? Function()? bodyFatPercent,
    DateTime? recordedAt,
    String? Function()? remoteId,
    DateTime? Function()? lastSyncedAt,
  }) => BodyMetric(
    id: id ?? this.id,
    weight: weight ?? this.weight,
    bodyFatPercent:
        bodyFatPercent != null ? bodyFatPercent() : this.bodyFatPercent,
    recordedAt: recordedAt ?? this.recordedAt,
    remoteId: remoteId != null ? remoteId() : this.remoteId,
    lastSyncedAt: lastSyncedAt != null ? lastSyncedAt() : this.lastSyncedAt,
  );
}
