import 'package:flutter/material.dart';

import '../../../../core/theme/athlos_custom_colors.dart';
import '../../../../l10n/app_localizations.dart';

/// Returns a color reflecting how far [actual] reps deviate from [planned].
///
/// Tolerance bands based on autoregulation (RPE/RIR) guidelines:
/// - ±1 rep  → null (neutral / on-target)
/// - ±2–3    → warning (attention — weight may be inadequate)
/// - ±4+     → error (weight clearly wrong)
Color? repsDeviationColor(
    ColorScheme cs, AthlosCustomColors custom, int actual, int planned) {
  final diff = actual - planned;
  if (diff.abs() >= 4) return cs.error;
  if (diff.abs() >= 2) return custom.warning;
  return null;
}

/// Feedback about load adjustment based on aggregate rep performance.
///
/// [completedReps] and [plannedReps] are parallel lists for each completed set.
/// Returns null when performance is in the ideal zone (no feedback needed).
({String message, Color color})? loadFeedback({
  required ColorScheme cs,
  required AthlosCustomColors custom,
  required AppLocalizations l10n,
  required List<int> completedReps,
  required int plannedReps,
}) {
  if (completedReps.isEmpty) return null;

  final avgDiff =
      completedReps.map((r) => r - plannedReps).reduce((a, b) => a + b) /
          completedReps.length;

  if (avgDiff <= -4) {
    return (message: l10n.executionFeedbackWeightTooHigh, color: cs.error);
  }
  if (avgDiff <= -2) {
    return (
      message: l10n.executionFeedbackWeightSlightlyHigh,
      color: custom.warning,
    );
  }
  if (avgDiff >= 4) {
    return (message: l10n.executionFeedbackWeightTooLight, color: cs.error);
  }
  if (avgDiff >= 2) {
    return (
      message: l10n.executionFeedbackWeightTooLight,
      color: custom.warning,
    );
  }
  return null;
}
