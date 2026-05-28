import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../core/theme/athlos_bottom_sheet.dart';
import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/workout.dart';

/// Opens a bottom sheet to pick which workout the history list is scoped to (same
/// pattern as [showExerciseCatalogFiltersSheet]).
Future<void> showTrainingHistoryWorkoutFilterSheet({
  required BuildContext context,
  required AppLocalizations l10n,
  required List<Workout> workouts,
  required String? initialWorkoutId,
  required ValueChanged<String?> onApply,
}) {
  return showAthlosModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return _TrainingHistoryFiltersBody(
        l10n: l10n,
        workouts: workouts,
        initialWorkoutId: initialWorkoutId,
        onApply: onApply,
      );
    },
  );
}

class _TrainingHistoryFiltersBody extends StatefulWidget {
  const _TrainingHistoryFiltersBody({
    required this.l10n,
    required this.workouts,
    required this.initialWorkoutId,
    required this.onApply,
  });

  final AppLocalizations l10n;
  final List<Workout> workouts;
  final String? initialWorkoutId;
  final ValueChanged<String?> onApply;

  @override
  State<_TrainingHistoryFiltersBody> createState() =>
      _TrainingHistoryFiltersBodyState();
}

class _TrainingHistoryFiltersBodyState
    extends State<_TrainingHistoryFiltersBody> {
  late String? _workoutId;

  @override
  void initState() {
    super.initState();
    _workoutId = widget.initialWorkoutId;
  }

  void _clearAll() {
    setState(() => _workoutId = null);
  }

  Widget _surfaceSection(BuildContext context, {required Widget child}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: AthlosRadius.mdAll,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AthlosSpacing.smd,
          AthlosSpacing.md,
          AthlosSpacing.smd,
          AthlosSpacing.md,
        ),
        child: child,
      ),
    );
  }

  List<Workout> _sortedWorkouts() {
    final list = widget.workouts.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final sorted = _sortedWorkouts();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.paddingOf(context).bottom + AthlosSpacing.md,
        left: AthlosSpacing.md,
        right: AthlosSpacing.md,
        top: AthlosSpacing.sm,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.trainingHistoryFiltersTitle,
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        l10n.trainingHistoryFiltersSubtitle,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _clearAll,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(l10n.exerciseCatalogFiltersClear),
                ),
              ],
            ),
            const Gap(AthlosSpacing.md),
            _surfaceSection(
              context,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.trainingHistoryFilterWorkout,
                    style: textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const Gap(AthlosSpacing.sm),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final matches = sorted.where((w) => w.id == _workoutId);
                      final selected = matches.isEmpty ? null : matches.first;
                      final label = switch (_workoutId) {
                        null => l10n.filterAll,
                        _ when selected != null => selected.name,
                        _ => l10n.unknownWorkout,
                      };
                      return PopupMenuButton<String?>(
                        tooltip: '',
                        elevation: 2,
                        position: PopupMenuPosition.under,
                        offset: const Offset(0, AthlosSpacing.xs),
                        initialValue: _workoutId,
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth,
                        ),
                        color: colorScheme.surfaceContainerHigh,
                        surfaceTintColor: Colors.transparent,
                        shadowColor: colorScheme.shadow.withValues(alpha: 0.12),
                        shape: RoundedRectangleBorder(
                          borderRadius: AthlosRadius.mdAll,
                          side: BorderSide(color: colorScheme.outlineVariant),
                        ),
                        onSelected: (v) => setState(() => _workoutId = v),
                        itemBuilder: (context) => [
                          _workoutMenuEntry(
                            context,
                            value: null,
                            text: l10n.filterAll,
                          ),
                          ...sorted.map(
                            (w) => _workoutMenuEntry(
                              context,
                              value: w.id,
                              text: w.name,
                            ),
                          ),
                        ],
                        child: ListTile(
                          dense: true,
                          minVerticalPadding: AthlosSpacing.smd,
                          horizontalTitleGap: AthlosSpacing.sm,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AthlosSpacing.smd,
                          ),
                          title: Text(
                            label,
                            style: textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurface,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Icon(
                            Icons.expand_more_rounded,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: AthlosRadius.mdAll,
                            side: BorderSide(color: colorScheme.outlineVariant),
                          ),
                          tileColor: colorScheme.surface,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const Gap(AthlosSpacing.lg),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: AthlosRadius.mdAll),
                elevation: 0,
              ),
              onPressed: () {
                widget.onApply(_workoutId);
                Navigator.of(context).pop();
              },
              child: Text(l10n.exerciseCatalogFiltersApply),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String?> _workoutMenuEntry(
    BuildContext context, {
    required String? value,
    required String text,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final selected = _workoutId == value;
    return PopupMenuItem<String?>(
      value: value,
      padding: const EdgeInsets.symmetric(horizontal: AthlosSpacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Center(
              child: selected
                  ? Icon(Icons.check, size: 20, color: colorScheme.primary)
                  : const SizedBox.shrink(),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyLarge,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
