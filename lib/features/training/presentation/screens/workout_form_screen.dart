import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/athlos_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/entities/workout.dart';
import '../../domain/entities/workout_exercise.dart';
import '../providers/equipment_notifier.dart';
import '../providers/exercise_notifier.dart';
import '../providers/workout_notifier.dart';
import '../widgets/equipment_warning_dialog.dart';
import '../widgets/exercise_picker_sheet.dart';
import '../widgets/workout_exercise_tile.dart';

/// Full-screen form for creating or editing a workout.
class WorkoutFormScreen extends ConsumerStatefulWidget {
  final int? workoutId;

  const WorkoutFormScreen({super.key, this.workoutId});

  bool get isEditing => workoutId != null;

  @override
  ConsumerState<WorkoutFormScreen> createState() => _WorkoutFormScreenState();
}

class _WorkoutFormScreenState extends ConsumerState<WorkoutFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final List<WorkoutExerciseEntry> _entries = [];
  bool _isLoading = false;
  bool _didLoadExisting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _loadExistingWorkout(Workout workout, List<WorkoutExercise> exercises,
      List<Exercise> allExercises) {
    if (_didLoadExisting) return;
    _didLoadExisting = true;

    _nameController.text = workout.name;
    _descController.text = workout.description ?? '';

    final exerciseMap = {for (final e in allExercises) e.id: e};

    for (final we in exercises) {
      final exercise = exerciseMap[we.exerciseId];
      if (exercise != null) {
        _entries.add(WorkoutExerciseEntry(
          exercise: exercise,
          sets: we.sets,
          reps: we.reps,
          restSeconds: we.restSeconds,
        ));
      }
    }
  }

  Future<void> _addExercise() async {
    final exercise = await showExercisePickerSheet(context);
    if (exercise == null || !mounted) return;

    final exerciseEquipmentIds =
        await ref.read(exerciseEquipmentIdsProvider(exercise.id).future);
    final userEquipment =
        await ref.read(userEquipmentIdsProvider.future);
    final allEquipment =
        await ref.read(equipmentListProvider.future);

    final missingIds =
        exerciseEquipmentIds.where((id) => !userEquipment.contains(id)).toList();

    if (missingIds.isNotEmpty && mounted) {
      final missingEquipment =
          allEquipment.where((e) => missingIds.contains(e.id)).toList();

      final confirmed = await showEquipmentWarningDialog(
        context,
        missingEquipment: missingEquipment,
      );

      if (confirmed != true) return;
    }

    setState(() {
      _entries.add(WorkoutExerciseEntry(exercise: exercise));
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_entries.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.workoutNeedsExercises)),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final exercises = _entries
          .asMap()
          .entries
          .map((e) => WorkoutExercise(
                workoutId: widget.workoutId ?? 0,
                exerciseId: e.value.exercise.id,
                order: e.key,
                sets: e.value.sets,
                reps: e.value.reps,
                restSeconds: e.value.restSeconds,
              ))
          .toList();

      final notifier = ref.read(workoutListProvider.notifier);

      if (widget.isEditing) {
        final existing =
            await ref.read(workoutByIdProvider(widget.workoutId!).future);
        if (existing != null) {
          await notifier.updateWorkout(
            workout: Workout(
              id: existing.id,
              name: _nameController.text.trim(),
              description: _descController.text.trim().isEmpty
                  ? null
                  : _descController.text.trim(),
              createdAt: existing.createdAt,
            ),
            exercises: exercises,
          );
        }
      } else {
        await notifier.createWorkout(
          name: _nameController.text.trim(),
          description: _descController.text.trim().isEmpty
              ? null
              : _descController.text.trim(),
          exercises: exercises,
        );
      }

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    if (widget.isEditing && !_didLoadExisting) {
      final workoutAsync =
          ref.watch(workoutByIdProvider(widget.workoutId!));
      final exercisesAsync =
          ref.watch(workoutExercisesProvider(widget.workoutId!));
      final allExercisesAsync = ref.watch(exerciseListProvider);

      final allReady = workoutAsync.hasValue &&
          exercisesAsync.hasValue &&
          allExercisesAsync.hasValue;

      if (!allReady) {
        return Scaffold(
          appBar: AppBar(title: Text(l10n.editWorkout)),
          body: const Center(child: CircularProgressIndicator()),
        );
      }

      final workout = workoutAsync.value;
      if (workout == null) {
        return Scaffold(
          appBar: AppBar(title: Text(l10n.editWorkout)),
          body: Center(child: Text(l10n.workoutNotFound)),
        );
      }

      _loadExistingWorkout(
        workout,
        exercisesAsync.value!,
        allExercisesAsync.value!,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? l10n.editWorkout : l10n.createWorkout),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(AthlosSpacing.md),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _save,
              tooltip: l10n.save,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AthlosSpacing.md),
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: l10n.workoutNameLabel,
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? l10n.fieldRequired : null,
                  ),
                  const SizedBox(height: AthlosSpacing.sm),
                  TextFormField(
                    controller: _descController,
                    decoration: InputDecoration(
                      labelText: l10n.workoutDescriptionLabel,
                      hintText: l10n.workoutDescriptionHint,
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AthlosSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.exercisesInWorkout,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  TextButton.icon(
                    onPressed: _addExercise,
                    icon: const Icon(Icons.add),
                    label: Text(l10n.addExerciseShort),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _entries.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.fitness_center_outlined,
                            size: 48,
                            color: colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: AthlosSpacing.sm),
                          Text(
                            l10n.emptyWorkoutExercises,
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    )
                  : ReorderableListView.builder(
                      itemCount: _entries.length,
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) newIndex--;
                          final item = _entries.removeAt(oldIndex);
                          _entries.insert(newIndex, item);
                        });
                      },
                      itemBuilder: (context, index) {
                        final entry = _entries[index];
                        return WorkoutExerciseTile(
                          key: ValueKey(
                              '${entry.exercise.id}_$index'),
                          entry: entry,
                          onRemove: () =>
                              setState(() => _entries.removeAt(index)),
                          onChanged: (_) => setState(() {}),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
