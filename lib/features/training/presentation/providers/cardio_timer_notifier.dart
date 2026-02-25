import 'dart:async';
import 'dart:math';

import 'package:riverpod_annotation/riverpod_annotation.dart';


part 'cardio_timer_notifier.g.dart';

class CardioTimerState {
  final int elapsedSeconds;
  final int goalSeconds;
  final bool isRunning;
  final bool isStopped;

  const CardioTimerState({
    this.elapsedSeconds = 0,
    this.goalSeconds = 0,
    this.isRunning = false,
    this.isStopped = false,
  });

  bool get hasReachedGoal => goalSeconds > 0 && elapsedSeconds >= goalSeconds;
  int get overtimeSeconds => max(0, elapsedSeconds - goalSeconds);
  double get progress =>
      goalSeconds > 0 ? (elapsedSeconds / goalSeconds).clamp(0.0, 1.0) : 0.0;

  /// True when timer has not started yet.
  bool get isReady => !isRunning && !isStopped && elapsedSeconds == 0;

  /// True when timer is paused (has elapsed time but not running or stopped).
  bool get isPaused =>
      !isRunning && !isStopped && elapsedSeconds > 0;

  CardioTimerState copyWith({
    int? elapsedSeconds,
    int? goalSeconds,
    bool? isRunning,
    bool? isStopped,
  }) =>
      CardioTimerState(
        elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
        goalSeconds: goalSeconds ?? this.goalSeconds,
        isRunning: isRunning ?? this.isRunning,
        isStopped: isStopped ?? this.isStopped,
      );
}

@Riverpod(keepAlive: true)
class CardioTimer extends _$CardioTimer {
  Timer? _timer;

  @override
  CardioTimerState build() => const CardioTimerState();

  void start(int goalSeconds) {
    _timer?.cancel();
    state = CardioTimerState(
      goalSeconds: goalSeconds,
      isRunning: true,
    );
    _startTicking();
  }

  void pause() {
    _timer?.cancel();
    state = state.copyWith(isRunning: false);
  }

  void resume() {
    if (state.isStopped) return;
    state = state.copyWith(isRunning: true);
    _startTicking();
  }

  void stop() {
    _timer?.cancel();
    state = state.copyWith(isRunning: false, isStopped: true);
  }

  void reset() {
    _timer?.cancel();
    state = const CardioTimerState();
  }

  void _startTicking() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
    });
  }
}

