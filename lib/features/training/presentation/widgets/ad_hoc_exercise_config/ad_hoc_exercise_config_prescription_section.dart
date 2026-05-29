import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../../core/theme/athlos_bottom_sheet.dart';
import '../../../../../core/theme/athlos_spacing.dart';
import '../../../../../l10n/app_localizations.dart';
import 'ad_hoc_config_int_field.dart';
import 'ad_hoc_exercise_config_model.dart';

/// Prescription fields — same data as workout builder, roomier bottom-sheet layout.
class AdHocExerciseConfigPrescriptionSection extends StatelessWidget {
  final AdHocExerciseConfig config;
  final ValueChanged<AdHocExerciseConfig> onChanged;

  const AdHocExerciseConfigPrescriptionSection({
    required this.config,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AthlosBottomSheetContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdHocConfigSectionLabel(
            l10n.workoutFormSectionPrescription,
            icon: Icons.tune_outlined,
          ),
          if (config.usesDuration) ...[
            AdHocConfigMetricRow(
              children: [
                AdHocConfigNumberField(
                  label: l10n.setsLabel,
                  value: config.sets,
                  onChanged: (v) {
                    config.sets = v;
                    onChanged(config);
                  },
                ),
                AdHocConfigNumberField(
                  label: l10n.durationSecondsLabel,
                  suffix: 's',
                  value: config.durationSeconds ?? 300,
                  onChanged: (v) {
                    config.durationSeconds = v;
                    onChanged(config);
                  },
                ),
              ],
            ),
            const Gap(AthlosSpacing.sm),
            AdHocConfigNumberField(
              label: l10n.restSecondsLabel,
              suffix: 's',
              value: config.restSeconds,
              onChanged: (v) {
                config.restSeconds = v;
                onChanged(config);
              },
            ),
          ] else ...[
            AdHocConfigMetricRow(
              children: [
                AdHocConfigNumberField(
                  label: l10n.setsLabel,
                  value: config.sets,
                  onChanged: (v) {
                    config.sets = v;
                    onChanged(config);
                  },
                ),
                AdHocConfigNumberField(
                  label: l10n.restSecondsLabel,
                  suffix: 's',
                  value: config.restSeconds,
                  onChanged: (v) {
                    config.restSeconds = v;
                    onChanged(config);
                  },
                ),
              ],
            ),
            const Gap(AthlosSpacing.sm),
            AdHocConfigMetricRow(
              children: [
                AdHocConfigNumberField(
                  label: l10n.minRepsLabel,
                  value: config.minReps ?? 12,
                  onChanged: (v) {
                    config.minReps = v;
                    if ((config.maxReps ?? v) < v) config.maxReps = v;
                    onChanged(config);
                  },
                ),
                AdHocConfigNumberField(
                  label: l10n.maxRepsLabel,
                  value: config.maxReps ?? config.minReps ?? 12,
                  onChanged: (v) {
                    config.maxReps = v;
                    if ((config.minReps ?? v) > v) config.minReps = v;
                    onChanged(config);
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
