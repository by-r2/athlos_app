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
  int get secondsUntilGoal =>
      goalSeconds > 0 ? max(0, goalSeconds - elapsedSeconds) : 0;
  double get progress =>
      goalSeconds > 0 ? (elapsedSeconds / goalSeconds).clamp(0.0, 1.0) : 0.0;

  /// True when timer has not started yet.
  bool get isReady => !isRunning && !isStopped && elapsedSeconds == 0;

  /// True when timer is paused (has elapsed time but not running or stopped).
  bool get isPaused => !isRunning && !isStopped && elapsedSeconds > 0;

  CardioTimerState copyWith({
    int? elapsedSeconds,
    int? goalSeconds,
    bool? isRunning,
    bool? isStopped,
  }) => CardioTimerState(
    elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
    goalSeconds: goalSeconds ?? this.goalSeconds,
    isRunning: isRunning ?? this.isRunning,
    isStopped: isStopped ?? this.isStopped,
  );
}

@Riverpod(keepAlive: true)
class CardioTimer extends _$CardioTimer {
  Timer? _timer;
  DateTime? _runningSinceUtc;
  int _accumulatedSeconds = 0;

  @override
  CardioTimerState build() => const CardioTimerState();

  void start(int goalSeconds) {
    _timer?.cancel();
    _accumulatedSeconds = 0;
    _runningSinceUtc = _nowUtc();
    state = CardioTimerState(goalSeconds: goalSeconds, isRunning: true);
    _startTicking();
  }

  void pause() {
    _syncWithClock();
    _accumulatedSeconds = state.elapsedSeconds;
    _timer?.cancel();
    _runningSinceUtc = null;
    state = state.copyWith(isRunning: false);
  }

  void resume() {
    if (state.isStopped) return;
    _runningSinceUtc = _nowUtc();
    state = state.copyWith(isRunning: true);
    _startTicking();
  }

  void stop() {
    _syncWithClock();
    _timer?.cancel();
    _runningSinceUtc = null;
    state = state.copyWith(isRunning: false, isStopped: true);
  }

  void reset() {
    _timer?.cancel();
    _runningSinceUtc = null;
    _accumulatedSeconds = 0;
    state = const CardioTimerState();
  }

  /// Reconciles elapsed time with the wall clock after background suspension.
  void syncWithClock() {
    _syncWithClock();
  }

  /// Whether [syncWithClock] would mark the goal as reached.
  bool wouldReachGoalOnSync() {
    if (!state.isRunning || state.goalSeconds <= 0) return false;
    return _currentElapsedSeconds() >= state.goalSeconds;
  }

  /// Seconds until the goal based on the wall clock (for background scheduling).
  int wallClockSecondsUntilGoal() {
    if (!state.isRunning || state.goalSeconds <= 0) return 0;
    return max(0, state.goalSeconds - _currentElapsedSeconds());
  }

  int _currentElapsedSeconds() {
    if (!state.isRunning || _runningSinceUtc == null) {
      return state.elapsedSeconds;
    }
    return _accumulatedSeconds +
        _nowUtc().difference(_runningSinceUtc!).inSeconds;
  }

  void _startTicking() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _syncWithClock();
    });
  }

  void _syncWithClock() {
    if (!state.isRunning || _runningSinceUtc == null) return;
    final elapsed =
        _accumulatedSeconds + _nowUtc().difference(_runningSinceUtc!).inSeconds;
    if (elapsed != state.elapsedSeconds) {
      state = state.copyWith(elapsedSeconds: elapsed);
    }
  }

  DateTime _nowUtc() => DateTime.now().toUtc();
}
