import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../core/theme/athlos_bottom_sheet.dart';
import '../../../../core/theme/athlos_screen_button_styles.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../core/widgets/feedback/athlos_messenger.dart';
import '../../../../core/widgets/layout/athlos_stacked_actions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/entities/workout_exercise.dart';
import 'ad_hoc_exercise_config/ad_hoc_exercise_config_header.dart';
import 'ad_hoc_exercise_config/ad_hoc_exercise_config_model.dart';
import 'ad_hoc_exercise_config/ad_hoc_exercise_config_options_section.dart';
import 'ad_hoc_exercise_config/ad_hoc_exercise_config_prescription_section.dart';

/// Bottom sheet to edit prescription for an exercise in an improvised workout.
Future<WorkoutExercise?> showAdHocExerciseConfigSheet(
  BuildContext context, {
  required WorkoutExercise workoutExercise,
  required Exercise exercise,
  required int minSets,
}) {
  return showAthlosModalBottomSheet<WorkoutExercise>(
    context: context,
    isScrollControlled: true,
    wrapInShell: false,
    builder: (_) => _AdHocExerciseConfigSheet(
      workoutExercise: workoutExercise,
      exercise: exercise,
      minSets: minSets,
    ),
  );
}

class _AdHocExerciseConfigSheet extends StatefulWidget {
  final WorkoutExercise workoutExercise;
  final Exercise exercise;
  final int minSets;

  const _AdHocExerciseConfigSheet({
    required this.workoutExercise,
    required this.exercise,
    required this.minSets,
  });

  @override
  State<_AdHocExerciseConfigSheet> createState() =>
      _AdHocExerciseConfigSheetState();
}

class _AdHocExerciseConfigSheetState extends State<_AdHocExerciseConfigSheet> {
  late AdHocExerciseConfig _config;

  @override
  void initState() {
    super.initState();
    _config = AdHocExerciseConfig.fromWorkoutExercise(
      widget.workoutExercise,
      widget.exercise,
    );
  }

  void _notifyChanged() => setState(() {});

  void _save() {
    final l10n = AppLocalizations.of(context)!;
    if (_config.sets < widget.minSets) {
      context.showAthlosWarningSnack(
        l10n.adHocEditExerciseMinSets(widget.minSets),
      );
      return;
    }
    if (_config.sets < 1) {
      context.showAthlosWarningSnack(l10n.fieldRequired);
      return;
    }
    Navigator.of(context).pop(_config.toWorkoutExercise());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.45,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return AthlosBottomSheetShell(
          expand: true,
          child: Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(
                      AthlosSpacing.md,
                      AthlosSpacing.sm,
                      AthlosSpacing.md,
                      AthlosSpacing.md,
                    ),
                    children: [
                      AthlosBottomSheetHeader(
                        title: l10n.adHocEditExerciseTitle,
                        padding: EdgeInsets.zero,
                      ),
                      const Gap(AthlosSpacing.md),
                      AdHocExerciseConfigHeader(exercise: widget.exercise),
                      const Gap(AthlosSpacing.lg),
                      AdHocExerciseConfigPrescriptionSection(
                        config: _config,
                        onChanged: (_) => _notifyChanged(),
                      ),
                      const Gap(AthlosSpacing.md),
                      AdHocExerciseConfigOptionsSection(
                        config: _config,
                        onChanged: (_) => _notifyChanged(),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: colorScheme.bottomSheet,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        AthlosSpacing.md,
                        AthlosSpacing.sm,
                        AthlosSpacing.md,
                        AthlosSpacing.md + bottomInset + keyboardInset,
                      ),
                      child: AthlosStackedActions(
                        children: [
                          TextButton(
                            style: AthlosScreenButtonStyles.stackedGhost(
                              context,
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(
                              MaterialLocalizations.of(
                                context,
                              ).cancelButtonLabel,
                            ),
                          ),
                          FilledButton(
                            style: AthlosScreenButtonStyles.stackedFilled(
                              context,
                            ),
                            onPressed: _save,
                            child: Text(l10n.save),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
