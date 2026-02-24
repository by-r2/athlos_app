import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/exercise.dart';
import '../helpers/exercise_l10n.dart';

/// Returns a theme color for a superset group, alternating between
/// [ColorScheme.primary] and [ColorScheme.tertiary].
Color supersetColorFor(int groupIndex, ColorScheme colorScheme) =>
    groupIndex.isEven ? colorScheme.primary : colorScheme.tertiary;

/// Configuration of an exercise within the workout form (mutable in-memory).
class WorkoutExerciseEntry {
  final Exercise exercise;
  int sets;
  int reps;
  int restSeconds;
  int? groupId;

  WorkoutExerciseEntry({
    required this.exercise,
    this.sets = 3,
    this.reps = 12,
    this.restSeconds = 60,
    this.groupId,
  });
}

/// Tile for an exercise inside the workout builder form.
///
/// When the exercise belongs to a superset group, a colored left border
/// and a small "Superset" badge are shown. Each group gets a distinct
/// color from [supersetGroupPalette] via [groupColorIndex].
class WorkoutExerciseTile extends StatelessWidget {
  final WorkoutExerciseEntry entry;
  final VoidCallback onRemove;
  final ValueChanged<WorkoutExerciseEntry> onChanged;
  final bool isLinkedToNext;
  final bool isLinkedToPrevious;
  final VoidCallback? onToggleLinkNext;
  final int? groupColorIndex;

  const WorkoutExerciseTile({
    super.key,
    required this.entry,
    required this.onRemove,
    required this.onChanged,
    this.isLinkedToNext = false,
    this.isLinkedToPrevious = false,
    this.onToggleLinkNext,
    this.groupColorIndex,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isInGroup = isLinkedToNext || isLinkedToPrevious;
    final groupColor =
        isInGroup && groupColorIndex != null
            ? supersetColorFor(groupColorIndex!, colorScheme)
            : null;

    final displayName = localizedExerciseName(
      entry.exercise.name,
      isVerified: entry.exercise.isVerified,
      l10n: l10n,
    );
    final groupName =
        localizedMuscleGroupName(entry.exercise.muscleGroup, l10n);

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
                border: Border(
                  left: BorderSide(color: groupColor, width: 4),
                ),
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.all(AthlosSpacing.sm),
          child: Row(
            children: [
              ReorderableDragStartListener(
                index: 0,
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
                        if (isInGroup && !isLinkedToPrevious &&
                            groupColor != null)
                          Padding(
                            padding: const EdgeInsets.only(
                                right: AthlosSpacing.xs),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AthlosSpacing.sm,
                                vertical: AthlosSpacing.xxs,
                              ),
                              decoration: BoxDecoration(
                                color: groupColor.withValues(alpha: 0.15),
                                borderRadius: AthlosRadius.xsAll,
                                border: Border.all(
                                  color: groupColor.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.link,
                                      size: 10, color: groupColor),
                                  const SizedBox(width: AthlosSpacing.xs),
                                  Text(
                                    l10n.supersetLabel,
                                    style: textTheme.labelSmall?.copyWith(
                                      color: groupColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            displayName,
                            style: textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      groupName,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AthlosSpacing.sm),
                    Row(
                      children: [
                        _NumberField(
                          label: l10n.setsLabel,
                          value: entry.sets,
                          onChanged: (v) {
                            entry.sets = v;
                            onChanged(entry);
                          },
                        ),
                        const SizedBox(width: AthlosSpacing.sm),
                        _NumberField(
                          label: l10n.repsLabel,
                          value: entry.reps,
                          onChanged: (v) {
                            entry.reps = v;
                            onChanged(entry);
                          },
                        ),
                        const SizedBox(width: AthlosSpacing.sm),
                        _NumberField(
                          label: l10n.restSecondsLabel,
                          value: entry.restSeconds,
                          onChanged: (v) {
                            entry.restSeconds = v;
                            onChanged(entry);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: colorScheme.error),
                onPressed: onRemove,
                tooltip: l10n.removeExercise,
              ),
            ],
          ),
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        cardWidget,
        if (onToggleLinkNext != null)
          _SupersetLinkButton(
            isLinked: isLinkedToNext,
            onTap: onToggleLinkNext!,
            linkedColor: isLinkedToNext ? groupColor : null,
          ),
      ],
    );
  }
}

class _SupersetLinkButton extends StatelessWidget {
  final bool isLinked;
  final VoidCallback onTap;
  final Color? linkedColor;

  const _SupersetLinkButton({
    required this.isLinked,
    required this.onTap,
    this.linkedColor,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final activeColor = linkedColor ?? colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AthlosSpacing.xl),
      child: InkWell(
        onTap: onTap,
        borderRadius: AthlosRadius.lgAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AthlosSpacing.xs),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isLinked ? Icons.link : Icons.link_off,
                size: 14,
                color: isLinked ? activeColor : colorScheme.outline,
              ),
              const SizedBox(width: AthlosSpacing.xs),
              Text(
                isLinked ? l10n.unlinkSuperset : l10n.linkSuperset,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isLinked ? activeColor : colorScheme.outline,
                    ),
              ),
            ],
          ),
        ),
      ),
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
    return SizedBox(
      width: 64,
      child: TextField(
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
      ),
    );
  }
}
