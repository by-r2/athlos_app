// Calendar weeks (Monday 00:00 local) aligned with weekly consistency logic.

/// Strips time; keeps calendar date in the local timezone of [instant].
DateTime dateOnly(DateTime instant) =>
    DateTime(instant.year, instant.month, instant.day);

/// Monday 00:00 local for the ISO week that contains [instant].
DateTime weekStartMonday(DateTime instant) {
  final d = dateOnly(instant);
  return d.subtract(Duration(days: d.weekday - DateTime.monday));
}

/// Oldest-first list of `[weekStartMonday]` for the last [weekCount] ISO weeks,
/// ending on the Monday of the calendar week containing [now].
List<DateTime> weekStartsEndingCurrent(DateTime now, int weekCount) {
  assert(weekCount > 0);
  final thisMonday = weekStartMonday(now);
  return List<DateTime>.generate(
    weekCount,
    (i) => thisMonday.subtract(Duration(days: 7 * (weekCount - 1 - i))),
  );
}

/// Index into [orderedWeekStarts] (same length); -1 when out of range.
int calendarWeekBucketIndex(DateTime execInstant, DateTime anchorMonday) =>
    weekStartMonday(execInstant).difference(anchorMonday).inDays ~/ 7;
