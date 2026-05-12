import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'rest_timer_notifier.g.dart';

class RestTimerState {
  final int remainingSeconds;
  final int totalSeconds;
  final bool isRunning;

  const RestTimerState({
    this.remainingSeconds = 0,
    this.totalSeconds = 0,
    this.isRunning = false,
  });

  bool get isActive => remainingSeconds > 0 || isRunning;

  double get progress => totalSeconds > 0 ? remainingSeconds / totalSeconds : 0;

  RestTimerState copyWith({
    int? remainingSeconds,
    int? totalSeconds,
    bool? isRunning,
  }) => RestTimerState(
    remainingSeconds: remainingSeconds ?? this.remainingSeconds,
    totalSeconds: totalSeconds ?? this.totalSeconds,
    isRunning: isRunning ?? this.isRunning,
  );
}

@Riverpod(keepAlive: true)
class RestTimer extends _$RestTimer {
  Timer? _timer;
  DateTime? _endsAtUtc;

  @override
  RestTimerState build() => const RestTimerState();

  void start(int seconds) {
    if (seconds <= 0) {
      reset();
      return;
    }
    _cancelTicker();
    state = RestTimerState(
      remainingSeconds: seconds,
      totalSeconds: seconds,
      isRunning: true,
    );
    _endsAtUtc = _nowUtc().add(Duration(seconds: seconds));
    _startTicker();
  }

  void pause() {
    _syncWithClock();
    _cancelTicker();
    _endsAtUtc = null;
    state = state.copyWith(isRunning: false);
  }

  void resume() {
    if (state.remainingSeconds <= 0) return;
    _cancelTicker();
    _endsAtUtc = _nowUtc().add(Duration(seconds: state.remainingSeconds));
    state = state.copyWith(isRunning: true);
    _startTicker();
  }

  void addTime(int seconds) {
    if (state.remainingSeconds <= 0 || seconds <= 0) return;
    _syncWithClock();
    if (state.isRunning && _endsAtUtc != null) {
      _endsAtUtc = _endsAtUtc!.add(Duration(seconds: seconds));
    }
    state = state.copyWith(
      remainingSeconds: state.remainingSeconds + seconds,
      totalSeconds: state.totalSeconds + seconds,
    );
  }

  void skip() {
    _cancelTicker();
    _endsAtUtc = null;
    state = state.copyWith(remainingSeconds: 0, isRunning: false);
  }

  void reset() {
    _cancelTicker();
    _endsAtUtc = null;
    state = const RestTimerState();
  }

  /// Reconciles timer state with real clock time.
  /// Needed when app resumes after iOS background suspension.
  void syncWithClock() {
    _syncWithClock();
  }

  void _startTicker() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _syncWithClock();
    });
  }

  void _cancelTicker() {
    _timer?.cancel();
    _timer = null;
  }

  void _syncWithClock() {
    if (!state.isRunning || _endsAtUtc == null) return;
    final remainingMs = _endsAtUtc!.difference(_nowUtc()).inMilliseconds;
    final nextRemaining = remainingMs <= 0 ? 0 : ((remainingMs + 999) ~/ 1000);
    if (nextRemaining <= 0) {
      _cancelTicker();
      _endsAtUtc = null;
      state = state.copyWith(remainingSeconds: 0, isRunning: false);
      return;
    }
    if (nextRemaining != state.remainingSeconds) {
      state = state.copyWith(remainingSeconds: nextRemaining);
    }
  }

  DateTime _nowUtc() => DateTime.now().toUtc();
}
