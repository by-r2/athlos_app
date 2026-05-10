import 'package:athlos_app/features/training/domain/helpers/week_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('weekStartMonday aligns to ISO Monday', () {
    // Wednesday May 13, 2026
    final wed = DateTime(2026, 5, 13, 21, 30);
    final mon = weekStartMonday(wed);
    expect(mon.weekday, DateTime.monday);
    expect(mon, DateTime(2026, 5, 11));
  });

  test('calendarWeekBucketIndex places execution in correct week bucket', () {
    final anchorMonday = DateTime(2026, 5, 4);
    final execWednesday = DateTime(2026, 5, 6);
    expect(calendarWeekBucketIndex(execWednesday, anchorMonday), 0);
    final execNextMonday = DateTime(2026, 5, 18);
    expect(calendarWeekBucketIndex(execNextMonday, anchorMonday), 2);
  });
}
