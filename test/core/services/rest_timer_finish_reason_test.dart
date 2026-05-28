import 'package:flutter_test/flutter_test.dart';

import 'package:athlos_app/features/training/presentation/providers/rest_timer_notifier.dart';

void main() {
  group('RestTimerFinishReason', () {
    test('natural completion is distinct from skip', () {
      const natural = RestTimerState(
        remainingSeconds: 0,
        isRunning: false,
        finishReason: RestTimerFinishReason.natural,
      );
      const skipped = RestTimerState(
        remainingSeconds: 0,
        isRunning: false,
        finishReason: RestTimerFinishReason.skipped,
      );

      expect(natural.finishReason, RestTimerFinishReason.natural);
      expect(skipped.finishReason, RestTimerFinishReason.skipped);
    });
  });
}
