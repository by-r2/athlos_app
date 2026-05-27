import '../entities/workout_execution.dart';

/// Bump when [computeFrequencyStreaks] semantics change.
const kTrainingStreaksSchemaVersion = 1;

/// [chronological]: finished executions, oldest → newest (by [WorkoutExecution.startedAt]).
({int current, int best}) computeFrequencyStreaks(
  List<WorkoutExecution> chronological,
  int weeklyTarget,
) {
  if (chronological.isEmpty || weeklyTarget <= 0) {
    return (current: 0, best: 0);
  }

  final finished = chronological.where((e) => e.finishedAt != null).toList();
  if (finished.isEmpty) {
    return (current: 0, best: 0);
  }

  final firstMonday = _mondayOf(finished.first.startedAt);
  final now = DateTime.now();
  final thisMonday = _mondayOf(now);

  var best = 0;
  var running = 0;
  for (
    var weekStart = firstMonday;
    !weekStart.isAfter(thisMonday);
    weekStart = weekStart.add(const Duration(days: 7))
  ) {
    final weekEnd = weekStart.add(const Duration(days: 7));
    final count = finished
        .where(
          (e) =>
              !e.startedAt.isBefore(weekStart) && e.startedAt.isBefore(weekEnd),
        )
        .length;
    if (count >= weeklyTarget) {
      running++;
      if (running > best) best = running;
    } else {
      running = 0;
    }
  }

  final current = _currentAnchoredWeeklyStreak(finished, weeklyTarget, now);
  return (current: current, best: best);
}

DateTime _mondayOf(DateTime d) =>
    DateTime(d.year, d.month, d.day - (d.weekday - 1));

/// Same anchoring as legacy [consistencyStatus]: current week in progress does not
/// break the historical chain until it closes without hitting the target.
int _currentAnchoredWeeklyStreak(
  List<WorkoutExecution> finished,
  int target,
  DateTime now,
) {
  final thisMonday = _mondayOf(now);
  final thisWeekEnd = thisMonday.add(const Duration(days: 7));
  final thisWeekCount = finished
      .where(
        (e) =>
            !e.startedAt.isBefore(thisMonday) &&
            e.startedAt.isBefore(thisWeekEnd),
      )
      .length;
  final isCurrentWeekSecured = thisWeekCount >= target;

  var streak = 0;
  var weekStart = isCurrentWeekSecured
      ? thisMonday
      : thisMonday.subtract(const Duration(days: 7));

  while (true) {
    final weekEnd = weekStart.add(const Duration(days: 7));
    final count = finished
        .where(
          (e) =>
              !e.startedAt.isBefore(weekStart) && e.startedAt.isBefore(weekEnd),
        )
        .length;
    if (count >= target) {
      streak++;
      weekStart = weekStart.subtract(const Duration(days: 7));
    } else {
      break;
    }
  }
  return streak;
}
