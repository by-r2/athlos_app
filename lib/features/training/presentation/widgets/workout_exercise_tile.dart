import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/athlos_bottom_sheet.dart';
import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../core/widgets/feedback/athlos_truncated_text.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/enums/load_mode.dart';
import '../helpers/exercise_l10n.dart';
import '../helpers/load_mode_l10n.dart'
    show localizedLoadModeOptionTitle, localizedLoadModeShort;

/// Distinct accent per superset group (cycles primary → secondary → tertiary).
Color supersetColorFor(int groupIndex, ColorScheme colorScheme) =>
    switch (groupIndex % 3) {
      0 => colorScheme.primary,
      1 => colorScheme.secondary,
      _ => colorScheme.tertiary,
    };

/// Configuration of an exercise within the workout form (mutable in-memory).
class WorkoutExerciseEntry {
  /// Stable `workout_exercises.id` when editing an existing row; null for new rows.
  final String? workoutExerciseRowId;
  final Exercise exercise;
  int sets;
  int? minReps;
  int? maxReps;
  bool isAmrap;
  int rest;
  int? duration;
  int? groupId;
  bool isUnilateral;
  LoadMode? loadModeOverride;
  String? notes;

  WorkoutExerciseEntry({
    this.workoutExerciseRowId,
    required this.exercise,
    this.sets = 3,
    this.minReps = 12,
    this.maxReps = 12,
    this.isAmrap = false,
    this.rest = 60,
    this.duration,
    this.groupId,
    this.isUnilateral = false,
    this.loadModeOverride,
    this.notes,
  });

  bool get isCardio => exercise.isCardio;
  bool get isIsometric => exercise.isIsometric;

  /// True when the exercise uses duration instead of reps (cardio or isometric).
  bool get usesDuration => isCardio || isIsometric;
}

/// Tile for an exercise inside the workout builder form.
///
/// When the exercise belongs to a superset group, a colored left border
/// and a small "Superset" badge are shown. Each group gets a distinct
/// color from [supersetGroupPalette] via [groupColorIndex].
class WorkoutExerciseTile extends StatefulWidget {
  final WorkoutExerciseEntry entry;
  final VoidCallback onRemove;
  final ValueChanged<WorkoutExerciseEntry> onChanged;
  final bool isLinkedToNext;
  final bool isLinkedToPrevious;
  final int? groupColorIndex;
  final int index;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final bool showRemoveButton;
  final bool showExpandToggle;

  const WorkoutExerciseTile({
    super.key,
    required this.entry,
    required this.onRemove,
    required this.onChanged,
    required this.index,
    required this.isExpanded,
    required this.onToggleExpand,
    this.isLinkedToNext = false,
    this.isLinkedToPrevious = false,
    this.groupColorIndex,
    this.showRemoveButton = true,
    this.showExpandToggle = true,
  });

  @override
  State<WorkoutExerciseTile> createState() => _WorkoutExerciseTileState();
}

class _WorkoutExerciseTileState extends State<WorkoutExerciseTile> {
  late bool _showNotes;

  @override
  void initState() {
    super.initState();
    _showNotes = widget.entry.notes != null && widget.entry.notes!.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final entry = widget.entry;
    final isInGroup = widget.isLinkedToNext || widget.isLinkedToPrevious;
    final groupColor = isInGroup && widget.groupColorIndex != null
        ? supersetColorFor(widget.groupColorIndex!, colorScheme)
        : null;

    final displayName = localizedExerciseName(
      entry.exercise.name,
      isVerified: entry.exercise.isVerified,
      l10n: l10n,
    );
    final groupName = localizedMuscleGroupName(
      entry.exercise.muscleGroup,
      l10n,
    );
    final effectiveLoadMode =
        entry.loadModeOverride ?? entry.exercise.defaultLoadMode;
    var summary = entry.usesDuration
        ? '${entry.sets}x ${entry.duration ?? 60}s · ${entry.rest}s'
        : '${entry.sets}x ${entry.minReps ?? 12}-${entry.maxReps ?? entry.minReps ?? 12} · ${entry.rest}s';
    if (entry.exercise.supportsLoadModeOverride) {
      summary = '$summary · ${localizedLoadModeShort(effectiveLoadMode, l10n)}';
    }

    final cardWidget = Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AthlosSpacing.md,
        vertical: AthlosSpacing.xs,
      ),
      shape: groupColor != null
          ? RoundedRectangleBorder(
              borderRadius: AthlosRadius.mdAll,
              side: BorderSide(color: groupColor.withValues(alpha: 0.4)),
            )
          : null,
      child: Container(
        decoration: groupColor != null
            ? BoxDecoration(
                borderRadius: AthlosRadius.mdAll,
                border: Border(left: BorderSide(color: groupColor, width: 4)),
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.all(AthlosSpacing.sm),
          child: Column(
            children: [
              InkWell(
                onTap: widget.onToggleExpand,
                borderRadius: AthlosRadius.mdAll,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AthlosSpacing.xxs,
                  ),
                  child: Row(
                    children: [
                      ReorderableDragStartListener(
                        index: widget.index,
                        child: Icon(
                          Icons.drag_handle,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: AthlosSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (isInGroup &&
                                    !widget.isLinkedToPrevious &&
                                    groupColor != null)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      right: AthlosSpacing.xs,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AthlosSpacing.sm,
                                        vertical: AthlosSpacing.xxs,
                                      ),
                                      decoration: BoxDecoration(
                                        color: groupColor.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: AthlosRadius.xsAll,
                                        border: Border.all(
                                          color: groupColor.withValues(
                                            alpha: 0.4,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.link,
                                            size: 10,
                                            color: groupColor,
                                          ),
                                          const SizedBox(
                                            width: AthlosSpacing.xs,
                                          ),
                                          Text(
                                            l10n.supersetLabel,
                                            style: textTheme.labelSmall
                                                ?.copyWith(
                                                  color: groupColor,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                Expanded(
                                  child: AthlosTruncatedText(
                                    displayName,
                                    style: textTheme.titleSmall,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AthlosSpacing.xxs),
                            Text(
                              groupName,
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (!widget.isExpanded) ...[
                              const SizedBox(height: AthlosSpacing.xxs),
                              Row(
                                children: [
                                  Text(
                                    summary,
                                    style: textTheme.labelSmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  if (entry.isAmrap) ...[
                                    const SizedBox(width: AthlosSpacing.xs),
                                    Icon(
                                      Icons.whatshot,
                                      size: 12,
                                      color: colorScheme.tertiary,
                                    ),
                                  ],
                                  if (entry.isUnilateral) ...[
                                    const SizedBox(width: AthlosSpacing.xs),
                                    Icon(
                                      Icons.swap_horiz,
                                      size: 12,
                                      color: colorScheme.secondary,
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (widget.showExpandToggle)
                        IconButton(
                          icon: Icon(
                            widget.isExpanded
                                ? Icons.expand_less
                                : Icons.expand_more,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          onPressed: widget.onToggleExpand,
                          tooltip: null,
                        ),
                      if (widget.showRemoveButton)
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          onPressed: widget.onRemove,
                          tooltip: l10n.removeExercise,
                        ),
                    ],
                  ),
                ),
              ),
              if (widget.isExpanded) ...[
                Divider(
                  height: 1,
                  thickness: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
                const SizedBox(height: AthlosSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.workoutFormSectionPrescription,
                    style: textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: AthlosSpacing.xs),
                Row(
                  children: [
                    Expanded(
                      child: _NumberField(
                        label: l10n.setsLabel,
                        value: entry.sets,
                        onChanged: (v) {
                          entry.sets = v;
                          widget.onChanged(entry);
                        },
                      ),
                    ),
                    const SizedBox(width: AthlosSpacing.sm),
                    if (entry.usesDuration)
                      Expanded(
                        child: _NumberField(
                          label: l10n.durationSecondsLabel,
                          value: entry.duration ?? 60,
                          onChanged: (v) {
                            entry.duration = v;
                            widget.onChanged(entry);
                          },
                        ),
                      ),
                    const SizedBox(width: AthlosSpacing.sm),
                    Expanded(
                      child: _NumberField(
                        label: l10n.restSecondsLabel,
                        value: entry.rest,
                        onChanged: (v) {
                          entry.rest = v;
                          widget.onChanged(entry);
                        },
                      ),
                    ),
                  ],
                ),
                if (!entry.usesDuration)
                  Padding(
                    padding: const EdgeInsets.only(top: AthlosSpacing.xs),
                    child: Row(
                      children: [
                        Expanded(
                          child: _NumberField(
                            label: l10n.minRepsLabel,
                            value: entry.minReps ?? 12,
                            onChanged: (v) {
                              entry.minReps = v;
                              if (entry.maxReps != null && entry.maxReps! < v) {
                                entry.maxReps = v;
                              }
                              widget.onChanged(entry);
                            },
                          ),
                        ),
                        const SizedBox(width: AthlosSpacing.sm),
                        Expanded(
                          child: _NumberField(
                            label: l10n.maxRepsLabel,
                            value: entry.maxReps ?? entry.minReps ?? 12,
                            onChanged: (v) {
                              entry.maxReps = v;
                              if (entry.minReps != null && entry.minReps! > v) {
                                entry.minReps = v;
                              }
                              widget.onChanged(entry);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: AthlosSpacing.md),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: AthlosSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.workoutFormSectionMoreOptions,
                    style: textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: AthlosSpacing.xs),
                Wrap(
                  spacing: AthlosSpacing.sm,
                  runSpacing: AthlosSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (entry.exercise.supportsLoadModeOverride)
                      Tooltip(
                        message: l10n.workoutFormLoadModeFieldLabel,
                        triggerMode: TooltipTriggerMode.longPress,
                        child: GestureDetector(
                          onTap: () => _pickLoadMode(context, entry, l10n),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AthlosSpacing.sm,
                              vertical: AthlosSpacing.xxs,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: AthlosRadius.fullAll,
                              border: Border.all(
                                color: colorScheme.outline.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.scale_outlined,
                                  size: 14,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(width: AthlosSpacing.xs),
                                Text(
                                  localizedLoadModeShort(
                                    effectiveLoadMode,
                                    l10n,
                                  ),
                                  style: textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: AthlosSpacing.xxs),
                                Icon(
                                  Icons.expand_more,
                                  size: 14,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (!entry.usesDuration) ...[
                      Tooltip(
                        message: l10n.amrapTooltip,
                        triggerMode: TooltipTriggerMode.longPress,
                        child: GestureDetector(
                          onTap: () {
                            entry.isAmrap = !entry.isAmrap;
                            widget.onChanged(entry);
                            setState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AthlosSpacing.sm,
                              vertical: AthlosSpacing.xxs,
                            ),
                            decoration: BoxDecoration(
                              color: entry.isAmrap
                                  ? colorScheme.tertiaryContainer
                                  : colorScheme.surfaceContainerHighest,
                              borderRadius: AthlosRadius.fullAll,
                              border: Border.all(
                                color: entry.isAmrap
                                    ? colorScheme.tertiary.withValues(
                                        alpha: 0.5,
                                      )
                                    : colorScheme.outline.withValues(
                                        alpha: 0.3,
                                      ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.whatshot,
                                  size: 14,
                                  color: entry.isAmrap
                                      ? colorScheme.onTertiaryContainer
                                      : colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: AthlosSpacing.xs),
                                Text(
                                  l10n.amrapLabel,
                                  style: textTheme.labelSmall?.copyWith(
                                    color: entry.isAmrap
                                        ? colorScheme.onTertiaryContainer
                                        : colorScheme.onSurfaceVariant,
                                    fontWeight: entry.isAmrap
                                        ? FontWeight.w600
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          entry.isUnilateral = !entry.isUnilateral;
                          widget.onChanged(entry);
                          setState(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AthlosSpacing.sm,
                            vertical: AthlosSpacing.xxs,
                          ),
                          decoration: BoxDecoration(
                            color: entry.isUnilateral
                                ? colorScheme.secondaryContainer
                                : colorScheme.surfaceContainerHighest,
                            borderRadius: AthlosRadius.fullAll,
                            border: Border.all(
                              color: entry.isUnilateral
                                  ? colorScheme.secondary.withValues(alpha: 0.5)
                                  : colorScheme.outline.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.swap_horiz,
                                size: 14,
                                color: entry.isUnilateral
                                    ? colorScheme.onSecondaryContainer
                                    : colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: AthlosSpacing.xs),
                              Text(
                                l10n.unilateralLabel,
                                style: textTheme.labelSmall?.copyWith(
                                  color: entry.isUnilateral
                                      ? colorScheme.onSecondaryContainer
                                      : colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    GestureDetector(
                      onTap: () => setState(() => _showNotes = !_showNotes),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AthlosSpacing.sm,
                          vertical: AthlosSpacing.xxs,
                        ),
                        decoration: BoxDecoration(
                          color: _showNotes
                              ? colorScheme.secondaryContainer
                              : colorScheme.surfaceContainerHighest,
                          borderRadius: AthlosRadius.fullAll,
                          border: Border.all(
                            color: _showNotes
                                ? colorScheme.secondary.withValues(alpha: 0.5)
                                : colorScheme.outline.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.note_alt_outlined,
                              size: 14,
                              color: _showNotes
                                  ? colorScheme.onSecondaryContainer
                                  : colorScheme.onSurfaceVariant,
                            ),
                            if (entry.notes != null &&
                                entry.notes!.isNotEmpty &&
                                !_showNotes) ...[
                              const SizedBox(width: AthlosSpacing.xs),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 180,
                                ),
                                child: AthlosTruncatedText(
                                  entry.notes!,
                                  style: textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (_showNotes)
                  Padding(
                    padding: const EdgeInsets.only(top: AthlosSpacing.sm),
                    child: _NotesField(
                      value: entry.notes ?? '',
                      hintText: l10n.exerciseNotesHint,
                      onChanged: (v) {
                        entry.notes = v.trim().isEmpty ? null : v.trim();
                        widget.onChanged(entry);
                      },
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );

    return cardWidget;
  }

  IconData _loadModeIcon(LoadMode mode) => switch (mode) {
    LoadMode.bodyweight => Icons.person_outline,
    LoadMode.weighted => Icons.fitness_center_outlined,
    LoadMode.assisted => Icons.trending_down,
  };

  Future<void> _pickLoadMode(
    BuildContext context,
    WorkoutExerciseEntry entry,
    AppLocalizations l10n,
  ) async {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final effective = entry.loadModeOverride ?? entry.exercise.defaultLoadMode;

    await showAthlosModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AthlosSpacing.md,
              AthlosSpacing.sm,
              AthlosSpacing.md,
              AthlosSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.workoutFormLoadModePickerTitle,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AthlosSpacing.sm),
                for (final mode in LoadMode.values)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      _loadModeIcon(mode),
                      color: colorScheme.primary,
                    ),
                    title: Text(localizedLoadModeOptionTitle(mode, l10n)),
                    trailing: mode == effective
                        ? Icon(Icons.check, color: colorScheme.primary)
                        : null,
                    onTap: () {
                      entry.loadModeOverride =
                          mode == entry.exercise.defaultLoadMode ? null : mode;
                      widget.onChanged(entry);
                      Navigator.of(sheetContext).pop();
                      setState(() {});
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NumberField extends StatefulWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _NumberField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toString());
  }

  @override
  void didUpdateWidget(_NumberField old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value &&
        _controller.text != widget.value.toString()) {
      _controller.text = widget.value.toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        labelText: widget.label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AthlosSpacing.xs,
          vertical: AthlosSpacing.sm,
        ),
      ),
      onChanged: (text) {
        final v = int.tryParse(text);
        if (v != null && v > 0) widget.onChanged(v);
      },
    );
  }
}

class _NotesField extends StatefulWidget {
  final String value;
  final String hintText;
  final ValueChanged<String> onChanged;

  const _NotesField({
    required this.value,
    required this.hintText,
    required this.onChanged,
  });

  @override
  State<_NotesField> createState() => _NotesFieldState();
}

class _NotesFieldState extends State<_NotesField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        hintText: widget.hintText,
        isDense: true,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AthlosSpacing.sm,
          vertical: AthlosSpacing.sm,
        ),
      ),
      maxLines: 2,
      minLines: 1,
      textInputAction: TextInputAction.done,
      onChanged: widget.onChanged,
    );
  }
}
