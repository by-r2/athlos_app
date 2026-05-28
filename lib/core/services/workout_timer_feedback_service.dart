import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Foreground haptic + sound cues during workout execution timers.
enum WorkoutTimerFeedbackEvent { goalReached, restFinished }

/// Plays distinct feedback when a duration goal is hit or rest time ends.
///
/// Goal reached: ascending Dorian lyre motif — a brief "Nike" triumph cue.
/// Rest finished: paired bronze herald strikes — summons back to the set.
/// Both use custom assets under [assets/sounds/].
class WorkoutTimerFeedbackService {
  WorkoutTimerFeedbackService._();

  static final WorkoutTimerFeedbackService instance =
      WorkoutTimerFeedbackService._();

  static const _goalSoundAsset = 'sounds/goal_reached.wav';
  static const _restSoundAsset = 'sounds/rest_finished.wav';

  final AudioPlayer _player = AudioPlayer();
  bool _isDisposed = false;

  Future<void> play(WorkoutTimerFeedbackEvent event) async {
    if (_isDisposed || kIsWeb) return;

    switch (event) {
      case WorkoutTimerFeedbackEvent.goalReached:
        await _playGoalHaptics();
        await _playSound(_goalSoundAsset);
      case WorkoutTimerFeedbackEvent.restFinished:
        await _playRestHaptics();
        await _playSound(_restSoundAsset);
    }
  }

  Future<void> _playGoalHaptics() async {
    await HapticFeedback.mediumImpact();
  }

  Future<void> _playRestHaptics() async {
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await HapticFeedback.heavyImpact();
  }

  Future<void> _playSound(String assetPath) async {
    try {
      await _player.stop();
      await _player.play(AssetSource(assetPath));
    } on Object catch (_) {
      // Fallback when asset playback fails (e.g. tests, unsupported platform).
      await SystemSound.play(
        assetPath.contains('rest')
            ? SystemSoundType.alert
            : SystemSoundType.click,
      );
    }
  }

  @visibleForTesting
  Future<void> disposeForTest() async {
    _isDisposed = true;
    await _player.dispose();
  }
}
