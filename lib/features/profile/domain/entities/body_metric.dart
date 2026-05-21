/// A single body weight / composition measurement at a point in time.
class BodyMetric {
  final String id;
  final double weight;
  final double? bodyFatPercent;
  final DateTime recordedAt;

  const BodyMetric({
    required this.id,
    required this.weight,
    this.bodyFatPercent,
    required this.recordedAt,
  });

  BodyMetric copyWith({
    String? id,
    double? weight,
    double? Function()? bodyFatPercent,
    DateTime? recordedAt,
  }) => BodyMetric(
    id: id ?? this.id,
    weight: weight ?? this.weight,
    bodyFatPercent:
        bodyFatPercent != null ? bodyFatPercent() : this.bodyFatPercent,
    recordedAt: recordedAt ?? this.recordedAt,
  );
}
