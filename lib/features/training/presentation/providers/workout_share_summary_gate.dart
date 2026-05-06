import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'workout_share_summary_gate.g.dart';

/// Whether to open the full-screen share summary right after finishing a workout.
///
/// Extension point: read a user preference from [SharedPreferences] or profile
/// when a settings screen exists.
@Riverpod(keepAlive: true)
bool shouldAutoShowWorkoutShareSummary(Ref ref) {
  return true;
}
