import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/entities/workout_exercise.dart';
import 'duration_format.dart';
import 'load_mode_l10n.dart';

/// One-line prescription summary (sets × reps/duration · rest), aligned with
/// collapsed [WorkoutExerciseTile] and workout detail subtitles.
String formatWorkoutExercisePrescriptionSummary({
  required WorkoutExercise exercise,
  required Exercise catalogExercise,
  required AppLocalizations l10n,
}) {
  final usesDuration =
      catalogExercise.isCardio || catalogExercise.isIsometric;

  var summary = usesDuration
      ? '${exercise.sets}×${formatDuration(exercise.durationSeconds ?? 60)} · ${exercise.restSeconds}s'
      : '${exercise.sets}×${exercise.repsDisplay} · ${exercise.restSeconds}s';

  if (catalogExercise.supportsLoadModeOverride) {
    final effective =
        exercise.loadModeOverride ?? catalogExercise.defaultLoadMode;
    summary = '$summary · ${localizedLoadModeShort(effective, l10n)}';
  }

  return summary;
}
