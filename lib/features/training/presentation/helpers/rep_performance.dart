import 'package:flutter/material.dart';

import '../../../../core/theme/athlos_custom_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/active_execution_state.dart';

/// Bands for heuristic load guidance from average reps vs prescription.
///
/// Kept public for unit tests (no [BuildContext] / l10n).
enum LoadAdviceBand {
  neutral,
  weightTooHeavySevere,
  weightTooHeavyMild,
  weightTooLightMild,
  weightTooLightSevere,
}

/// Classifies averaged rep performance vs prescription boundaries.
///
/// [maxReps] may be zero when callers only supply [minReps] (falls back internally).
@visibleForTesting
LoadAdviceBand computeLoadAdviceBand({
  required double averageReps,
  required int minReps,
  required int maxReps,
  required bool isAmrap,
}) {
  if (isAmrap) {
    final lo = minReps > 0 ? minReps : 0;
    if (lo <= 0) return LoadAdviceBand.neutral;
    if (averageReps < lo - 2) return LoadAdviceBand.weightTooHeavySevere;
    if (averageReps < lo) return LoadAdviceBand.weightTooHeavyMild;
    return LoadAdviceBand.neutral;
  }

  final lo = minReps;
  final hi = maxReps > 0 ? maxReps : minReps;
  if (lo <= 0 && hi <= 0) return LoadAdviceBand.neutral;

  if (averageReps < lo - 2) return LoadAdviceBand.weightTooHeavySevere;
  if (averageReps < lo) return LoadAdviceBand.weightTooHeavyMild;
  if (averageReps > hi + 2) return LoadAdviceBand.weightTooLightSevere;
  if (averageReps > hi) return LoadAdviceBand.weightTooLightMild;
  return LoadAdviceBand.neutral;
}

/// Aggregated reps for execution/history rows (excluding warm-ups is the caller's job).
int repsForAggregateLoadFeedback({
  required int? reps,
  required int? leftReps,
  required int? rightReps,
}) {
  if (leftReps != null && rightReps != null) {
    return ((leftReps + rightReps) / 2).round();
  }
  if (leftReps != null) return leftReps;
  if (rightReps != null) return rightReps;
  return reps ?? 0;
}

/// Double progression (+2.5%) only when **every planned work set** hit at least [maxReps].
bool workSetsQualifyForSuggestedWeightIncrease({
  required List<SetEntry> latestSetsForExercise,
  required int maxReps,
}) {
  final workSets = latestSetsForExercise.where((s) => !s.isWarmup).toList();
  if (workSets.isEmpty) return false;
  if (!workSets.every((s) => s.isCompleted)) return false;
  return workSets.every(
    (s) => s.reps != null && s.reps! >= maxReps,
  );
}

/// Next nominal bar/plate suggestion (minimum +0.25 kg) after all sets hit caps.
double? nextRoundedSuggestedWorkingWeightKg({
  required List<SetEntry> latestSetsForExercise,
  double loadIncreaseFraction = 0.025,
}) {
  final workSets = latestSetsForExercise.where((s) => !s.isWarmup).toList();
  if (workSets.isEmpty) return null;
  final peak = workSets
      .map((s) => s.weight ?? 0.0)
      .reduce((a, b) => a > b ? a : b);
  if (peak <= 0) return null;
  const plate = 0.25;
  final raw =
      (peak * (1 + loadIncreaseFraction) / plate).roundToDouble() * plate;
  if (raw <= peak + 1e-9) {
    return peak + plate;
  }
  return raw;
}

/// Returns a color reflecting how far [actual] reps deviate from the
/// planned range [minPlanned]..[maxPlanned].
///
/// For AMRAP, anything at or above [minPlanned] is on-target.
Color? repsDeviationColor(
  ColorScheme cs,
  AthlosCustomColors custom,
  int actual,
  int minPlanned,
  int maxPlanned,
  bool isAmrap,
) {
  final lo = minPlanned;
  final hi = maxPlanned > 0 ? maxPlanned : minPlanned;

  if (isAmrap) {
    if (lo <= 0) return null;
    if (actual < lo - 2) return cs.error;
    if (actual < lo) return custom.warning;
    return null;
  }
  if (lo <= 0 && hi <= 0) return null;
  if (actual >= lo && actual <= hi) return null;

  if (actual < lo) {
    if (actual <= lo - 3) return cs.error;
    return custom.warning;
  }
  if (actual > hi + 2) return cs.error;
  return custom.warning;
}

/// Feedback about load adjustment based on aggregate rep performance
/// across completed sets.
///
/// Returns null when performance is in the ideal zone.
({String message, Color color})? loadFeedback({
  required ColorScheme cs,
  required AthlosCustomColors custom,
  required AppLocalizations l10n,
  required List<int> completedReps,
  required int minReps,
  required int maxReps,
  required bool isAmrap,
}) {
  if (completedReps.isEmpty) return null;

  final avg = completedReps.reduce((a, b) => a + b) / completedReps.length;

  final band = computeLoadAdviceBand(
    averageReps: avg,
    minReps: minReps,
    maxReps: maxReps,
    isAmrap: isAmrap,
  );

  switch (band) {
    case LoadAdviceBand.neutral:
      return null;
    case LoadAdviceBand.weightTooHeavySevere:
      return (message: l10n.executionFeedbackWeightTooHigh, color: cs.error);
    case LoadAdviceBand.weightTooHeavyMild:
      return (
        message: l10n.executionFeedbackWeightSlightlyHigh,
        color: custom.warning,
      );
    case LoadAdviceBand.weightTooLightMild:
      return (
        message: l10n.executionFeedbackWeightTooLight,
        color: custom.warning,
      );
    case LoadAdviceBand.weightTooLightSevere:
      return (
        message: l10n.executionFeedbackWeightTooLight,
        color: cs.error,
      );
  }
}
