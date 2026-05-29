import 'package:flutter_test/flutter_test.dart';

import 'package:athlos_app/features/training/presentation/providers/cardio_timer_notifier.dart';

void main() {
  group('CardioTimerState', () {
    test('secondsUntilGoal reflects remaining time to goal', () {
      const running = CardioTimerState(
        elapsedSeconds: 45,
        goalSeconds: 120,
        isRunning: true,
      );
      const reached = CardioTimerState(
        elapsedSeconds: 120,
        goalSeconds: 120,
        isRunning: true,
      );

      expect(running.secondsUntilGoal, 75);
      expect(reached.secondsUntilGoal, 0);
      expect(reached.hasReachedGoal, isTrue);
    });
  });
}
