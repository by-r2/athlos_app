import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/athlos_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/exercise.dart';
import '../helpers/exercise_l10n.dart';

/// Configuration of an exercise within the workout form (mutable in-memory).
class WorkoutExerciseEntry {
  final Exercise exercise;
  int sets;
  int reps;
  int restSeconds;

  WorkoutExerciseEntry({
    required this.exercise,
    this.sets = 3,
    this.reps = 12,
    this.restSeconds = 60,
  });
}

/// Tile for an exercise inside the workout builder form.
///
/// Shows exercise name, muscle group, editable sets/reps/rest fields,
/// a drag handle and a remove button.
class WorkoutExerciseTile extends StatelessWidget {
  final WorkoutExerciseEntry entry;
  final VoidCallback onRemove;
  final ValueChanged<WorkoutExerciseEntry> onChanged;

  const WorkoutExerciseTile({
    super.key,
    required this.entry,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final displayName = localizedExerciseName(
      entry.exercise.name,
      isVerified: entry.exercise.isVerified,
      l10n: l10n,
    );
    final groupName =
        localizedMuscleGroupName(entry.exercise.muscleGroup, l10n);

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AthlosSpacing.md,
        vertical: AthlosSpacing.xs,
      ),
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
                  Text(
                    displayName,
                    style: textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
