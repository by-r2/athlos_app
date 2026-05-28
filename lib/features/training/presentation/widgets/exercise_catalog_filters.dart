import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../core/theme/athlos_bottom_sheet.dart';
import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/enums/muscle_group.dart';
import '../helpers/exercise_l10n.dart';

/// Whether the catalog lists only verified, only custom, or both.
enum ExerciseCatalogSourceFilter { all, verifiedOnly, customOnly }

/// Opens a bottom sheet to pick muscle group and catalog source (common mobile
/// pattern instead of a long horizontal chip row).
Future<void> showExerciseCatalogFiltersSheet({
  required BuildContext context,
  required AppLocalizations l10n,
  required MuscleGroup? initialMuscleGroup,
  required ExerciseCatalogSourceFilter initialSource,
  required void Function(
    MuscleGroup? muscleGroup,
    ExerciseCatalogSourceFilter source,
  )
  onApply,
}) {
  return showAthlosModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return _ExerciseCatalogFiltersBody(
        l10n: l10n,
        initialMuscleGroup: initialMuscleGroup,
        initialSource: initialSource,
        onApply: onApply,
      );
    },
  );
}

class _ExerciseCatalogFiltersBody extends StatefulWidget {
  const _ExerciseCatalogFiltersBody({
    required this.l10n,
    required this.initialMuscleGroup,
    required this.initialSource,
    required this.onApply,
  });

  final AppLocalizations l10n;
  final MuscleGroup? initialMuscleGroup;
  final ExerciseCatalogSourceFilter initialSource;
  final void Function(
    MuscleGroup? muscleGroup,
    ExerciseCatalogSourceFilter source,
  )
  onApply;

  @override
  State<_ExerciseCatalogFiltersBody> createState() =>
      _ExerciseCatalogFiltersBodyState();
}

class _ExerciseCatalogFiltersBodyState
    extends State<_ExerciseCatalogFiltersBody> {
  late MuscleGroup? _muscle;
  late ExerciseCatalogSourceFilter _source;

  @override
  void initState() {
    super.initState();
    _muscle = widget.initialMuscleGroup;
    _source = widget.initialSource;
  }

  void _clearAll() {
    setState(() {
      _muscle = null;
      _source = ExerciseCatalogSourceFilter.all;
    });
  }

  Widget _surfaceSection(BuildContext context, {required Widget child}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.bottomSheetContainer,
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

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
                        l10n.exerciseCatalogFiltersTitle,
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        l10n.exerciseCatalogFiltersSubtitle,
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
                    l10n.exerciseCatalogFilterMuscleGroup,
                    style: textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const Gap(AthlosSpacing.sm),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final label = _muscle == null
                          ? l10n.filterAll
                          : localizedMuscleGroupName(_muscle!, l10n);
                      return PopupMenuButton<MuscleGroup?>(
                        tooltip: '',
                        elevation: 2,
                        position: PopupMenuPosition.under,
                        offset: const Offset(0, AthlosSpacing.xs),
                        initialValue: _muscle,
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
                        onSelected: (v) => setState(() => _muscle = v),
                        itemBuilder: (context) => [
                          _muscleMenuEntry(
                            context,
                            value: null,
                            text: l10n.filterAll,
                          ),
                          ...MuscleGroup.values.map(
                            (g) => _muscleMenuEntry(
                              context,
                              value: g,
                              text: localizedMuscleGroupName(g, l10n),
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
                            maxLines: 1,
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
            const Gap(AthlosSpacing.md),
            _surfaceSection(
              context,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.exerciseCatalogFilterSource,
                    style: textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const Gap(AthlosSpacing.xs),
                  Text(
                    l10n.exerciseCatalogFilterSourceIntro,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Gap(AthlosSpacing.sm),
                  RadioGroup<ExerciseCatalogSourceFilter>(
                    groupValue: _source,
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _source = v);
                    },
                    child: Column(
                      children: [
                        _sourceTile(
                          context,
                          filter: ExerciseCatalogSourceFilter.all,
                          title: l10n.exerciseCatalogFilterSourceAll,
                          subtitle: l10n.exerciseCatalogFilterSourceAllSubtitle,
                        ),
                        _sourceTile(
                          context,
                          filter: ExerciseCatalogSourceFilter.verifiedOnly,
                          title: l10n.exerciseCatalogFilterSourceVerified,
                          subtitle:
                              l10n.exerciseCatalogFilterSourceVerifiedSubtitle,
                        ),
                        _sourceTile(
                          context,
                          filter: ExerciseCatalogSourceFilter.customOnly,
                          title: l10n.exerciseCatalogFilterSourceCustom,
                          subtitle:
                              l10n.exerciseCatalogFilterSourceCustomSubtitle,
                        ),
                      ],
                    ),
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
                widget.onApply(_muscle, _source);
                Navigator.of(context).pop();
              },
              child: Text(l10n.exerciseCatalogFiltersApply),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<MuscleGroup?> _muscleMenuEntry(
    BuildContext context, {
    required MuscleGroup? value,
    required String text,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final selected = _muscle == value;
    return PopupMenuItem<MuscleGroup?>(
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

  Widget _sourceTile(
    BuildContext context, {
    required ExerciseCatalogSourceFilter filter,
    required String title,
    required String subtitle,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return RadioListTile<ExerciseCatalogSourceFilter>(
      value: filter,
      selected: _source == filter,
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
