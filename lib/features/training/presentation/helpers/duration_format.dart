/// Formats seconds into a human-readable duration string.
///
/// Examples: `45s`, `5min 30s`, `20min`, `1h 5min 30s`.
String formatDuration(int totalSeconds) {
  if (totalSeconds < 0) return '0s';

  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = totalSeconds % 60;

  final parts = <String>[];
  if (h > 0) parts.add('${h}h');
  if (m > 0) parts.add('${m}min');
  if (s > 0 || parts.isEmpty) parts.add('${s}s');

  return parts.join(' ');
}
