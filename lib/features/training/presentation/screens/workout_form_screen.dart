import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/presentation/navigation/confirm_navigation_scope.dart';
import '../../../../core/presentation/navigation/navigation_leave_dialogs.dart';
import '../../../../core/theme/athlos_bottom_sheet.dart';
import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../core/widgets/feedback/athlos_messenger.dart';
import '../../../../core/widgets/layout/athlos_scaffold.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/entities/workout.dart';
import '../../domain/entities/workout_exercise.dart';
import '../helpers/exercise_l10n.dart';
import '../helpers/superset_grouping.dart';
import '../helpers/workout_exercise_prescription_summary.dart';
import '../helpers/workout_form_exercise_bridge.dart';
import '../providers/exercise_notifier.dart';
import '../providers/workout_notifier.dart';
import '../widgets/ad_hoc_exercise_config_sheet.dart';
import '../widgets/exercise_picker_sheet.dart';
import '../widgets/superset_selection_bar.dart';
import '../widgets/workout_builder_exercise_card.dart';
import '../widgets/workout_exercise_tile.dart';

/// Full-screen form for creating or editing a workout.
class WorkoutFormScreen extends ConsumerStatefulWidget {
  final String? workoutId;

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
  bool _hasLoadedExisting = false;
  bool _dirty = false;

  bool _isSupersetSelecting = false;
  bool _isJoiningExistingSuperset = false;
  String? _joinSeedExerciseId;
  int? _supersetEditingGroupId;
  Set<String> _supersetSelectedIds = {};

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _loadExistingWorkout(
    Workout workout,
    List<WorkoutExercise> exercises,
    List<Exercise> allExercises,
  ) {
    if (_hasLoadedExisting) return;
    _hasLoadedExisting = true;

    _nameController.text = workout.name;
    _descController.text = workout.description ?? '';

    final exerciseMap = {for (final e in allExercises) e.id: e};

    for (final we in exercises) {
      final exercise = exerciseMap[we.exerciseId];
      if (exercise != null) {
        _entries.add(
          WorkoutExerciseEntry(
            workoutExerciseRowId: we.id.isEmpty ? null : we.id,
            exercise: exercise,
            sets: we.sets,
            minReps: we.minReps,
            maxReps: we.maxReps,
            isAmrap: we.isAmrap,
            rest: we.restSeconds,
            duration: we.durationSeconds,
            groupId: we.groupId,
            isUnilateral: we.isUnilateral,
            loadModeOverride: we.loadModeOverride,
            notes: we.notes,
          ),
        );
      }
    }
    _dirty = false;
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Map<int, int> get _groupColorIndexMap =>
      supersetColorIndexByGroupId(entriesAsWorkoutExercises(_entries));

  bool _hasExistingSuperset() => _entries.any((e) => e.groupId != null);

  Future<void> _addExercise() async {
    final exercise = await showExercisePickerSheet(context);
    if (exercise == null || !mounted) return;

    try {
      _markDirty();
      setState(() {
        _entries.add(
          WorkoutExerciseEntry(
            exercise: exercise,
            minReps: exercise.isCardio ? null : 12,
            maxReps: exercise.isCardio ? null : 12,
            duration: exercise.isCardio ? 300 : null,
          ),
        );
      });
    } on Exception catch (_) {
      if (mounted) {
        context.showAthlosErrorSnack(AppLocalizations.of(context)!.genericError);
      }
    }
  }

  Future<void> _editExercise(WorkoutExerciseEntry entry) async {
    final workoutId = widget.workoutId ?? '';
    final index = _entries.indexOf(entry);
    if (index < 0) return;

    final updated = await showAdHocExerciseConfigSheet(
      context,
      workoutExercise: entryToWorkoutExercise(entry, index, workoutId: workoutId),
      exercise: entry.exercise,
      minSets: 1,
    );
    if (updated == null || !mounted) return;

    _markDirty();
    setState(() {
      final synced = syncSupersetRestInList(
        entriesAsWorkoutExercises(_entries, workoutId: workoutId),
        updated,
      );
      syncEntryListFromWorkoutExercises(_entries, synced);
    });
  }

  void _removeExerciseAt(int index) {
    _markDirty();
    setState(() {
      _entries.removeAt(index);
      final normalized = normalizeLonelySupersetGroups(
        entriesAsWorkoutExercises(_entries, workoutId: widget.workoutId ?? ''),
      );
      syncEntryListFromWorkoutExercises(_entries, normalized);
    });
  }

  void _onReorderEntries(int oldIndex, int newIndex) {
    _markDirty();
    setState(() {
      final reordered = reorderExercisesInList(
        entriesAsWorkoutExercises(_entries, workoutId: widget.workoutId ?? ''),
        oldIndex,
        newIndex,
      );
      syncEntryListFromWorkoutExercises(_entries, reordered);
    });
  }

  void _startSupersetSelection(WorkoutExerciseEntry seed) {
    if (seed.groupId != null) return;
    setState(() {
      _isSupersetSelecting = true;
      _isJoiningExistingSuperset = false;
      _joinSeedExerciseId = null;
      _supersetEditingGroupId = null;
      _supersetSelectedIds = {seed.exercise.id};
    });
  }

  void _startSupersetEditMode(WorkoutExerciseEntry seed) {
    final gid = seed.groupId;
    if (gid == null) return;
    setState(() {
      _isSupersetSelecting = true;
      _isJoiningExistingSuperset = false;
      _joinSeedExerciseId = null;
      _supersetEditingGroupId = gid;
      _supersetSelectedIds = {
        for (final e in _entries)
          if (e.groupId == gid) e.exercise.id,
      };
    });
  }

  void _startJoinExistingSupersetSelection(WorkoutExerciseEntry seed) {
    if (seed.groupId != null) return;
    setState(() {
      _isSupersetSelecting = true;
      _isJoiningExistingSuperset = true;
      _joinSeedExerciseId = seed.exercise.id;
      _supersetEditingGroupId = null;
      _supersetSelectedIds = {seed.exercise.id};
    });
  }

  bool _isJoinSupersetSelectionLocked(WorkoutExerciseEntry entry) {
    final seedId = _joinSeedExerciseId;
    if (seedId == null) return true;
    final gid = entry.groupId;
    if (gid != null) {
      return _supersetEditingGroupId != null && gid != _supersetEditingGroupId;
    }
    return entry.exercise.id != seedId;
  }

  void _cancelSupersetEdit() {
    setState(() {
      _isSupersetSelecting = false;
      _isJoiningExistingSuperset = false;
      _joinSeedExerciseId = null;
      _supersetEditingGroupId = null;
      _supersetSelectedIds = {};
    });
  }

  void _toggleSupersetSelection(WorkoutExerciseEntry entry) {
    final we = entryToWorkoutExercise(
      entry,
      _entries.indexOf(entry),
      workoutId: widget.workoutId ?? '',
    );

    if (_isJoiningExistingSuperset) {
      if (_isJoinSupersetSelectionLocked(entry)) return;

      final seedId = _joinSeedExerciseId;
      if (seedId == null) return;

      final gid = entry.groupId;
      if (gid == null) {
        setState(() {
          if (_supersetSelectedIds.contains(seedId)) {
            _supersetSelectedIds = {};
          } else {
            _supersetSelectedIds = {seedId};
          }
          _supersetEditingGroupId = null;
        });
        return;
      }

      if (_supersetEditingGroupId == gid) {
        setState(() {
          _supersetEditingGroupId = null;
          _supersetSelectedIds = {seedId};
        });
        return;
      }

      setState(() {
        _supersetEditingGroupId = gid;
        _supersetSelectedIds = {
          seedId,
          for (final e in _entries)
            if (e.groupId == gid) e.exercise.id,
        };
      });
      return;
    }

    if (isLockedInOtherSuperset(we, _supersetEditingGroupId)) return;
    setState(() {
      if (_supersetSelectedIds.contains(entry.exercise.id)) {
        _supersetSelectedIds = {..._supersetSelectedIds}
          ..remove(entry.exercise.id);
      } else {
        _supersetSelectedIds = {..._supersetSelectedIds, entry.exercise.id};
      }
    });
  }

  void _confirmSupersetEdit() {
    final l10n = AppLocalizations.of(context)!;
    if (_isJoiningExistingSuperset) {
      if (_supersetEditingGroupId == null || _supersetSelectedIds.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.adHocSupersetJoinConfirmNeedsGroup)),
        );
        return;
      }
    }

    _markDirty();
    setState(() {
      final updated = applySupersetSelection(
        entriesAsWorkoutExercises(_entries, workoutId: widget.workoutId ?? ''),
        _supersetSelectedIds,
        editingGroupId: _supersetEditingGroupId,
      );
      syncEntryListFromWorkoutExercises(_entries, updated);
      _isSupersetSelecting = false;
      _isJoiningExistingSuperset = false;
      _joinSeedExerciseId = null;
      _supersetEditingGroupId = null;
      _supersetSelectedIds = {};
    });
  }

  void _showExerciseOptionsSheet(WorkoutExerciseEntry entry) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final exerciseName = localizedExerciseName(
      entry.exercise.name,
      isVerified: entry.exercise.isVerified,
      l10n: l10n,
    );
    showAthlosModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AthlosSpacing.md,
              AthlosSpacing.sm,
              AthlosSpacing.md,
              AthlosSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(exerciseName, style: textTheme.titleMedium),
                const SizedBox(height: AthlosSpacing.md),
                if (entry.groupId == null) ...[
                  ListTile(
                    leading: Icon(Icons.link, color: colorScheme.primary),
                    title: Text(l10n.linkSuperset),
                    onTap: () {
                      Navigator.pop(ctx);
                      _startSupersetSelection(entry);
                    },
                  ),
                  if (_hasExistingSuperset())
                    ListTile(
                      leading: Icon(Icons.add_link, color: colorScheme.primary),
                      title: Text(l10n.adHocSupersetJoinExistingAction),
                      onTap: () {
                        Navigator.pop(ctx);
                        _startJoinExistingSupersetSelection(entry);
                      },
                    ),
                ] else
                  ListTile(
                    leading: Icon(Icons.tune, color: colorScheme.primary),
                    title: Text(l10n.adHocSupersetEditAction),
                    onTap: () {
                      Navigator.pop(ctx);
                      _startSupersetEditMode(entry);
                    },
                  ),
                ListTile(
                  leading: Icon(Icons.edit_outlined, color: colorScheme.primary),
                  title: Text(l10n.editExercise),
                  onTap: () {
                    Navigator.pop(ctx);
                    _editExercise(entry);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.delete_outline, color: colorScheme.error),
                  title: Text(
                    l10n.removeExercise,
                    style: TextStyle(color: colorScheme.error),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    final index = _entries.indexOf(entry);
                    if (index >= 0) _removeExerciseAt(index);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> _confirmDismissExercise(
    WorkoutExerciseEntry entry,
    DismissDirection direction,
  ) async {
    if (direction == DismissDirection.startToEnd) {
      await _editExercise(entry);
      return false;
    }
    return true;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_entries.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      context.showAthlosWarningSnack(l10n.workoutNeedsExercises);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final exercises = _entries
          .asMap()
          .entries
          .map(
            (e) => WorkoutExercise(
              id: e.value.workoutExerciseRowId ?? '',
              workoutId: widget.workoutId ?? '',
              exerciseId: e.value.exercise.id,
              sortOrder: e.key,
              sets: e.value.sets,
              minReps: e.value.minReps,
              maxReps: e.value.maxReps,
              isAmrap: e.value.isAmrap,
              restSeconds: e.value.rest,
              durationSeconds: e.value.duration,
              groupId: e.value.groupId,
              isUnilateral: e.value.isUnilateral,
              loadModeOverride: e.value.loadModeOverride,
              notes: e.value.notes,
            ),
          )
          .toList();

      if (widget.isEditing) {
        final existing = await ref.read(
          workoutByIdProvider(widget.workoutId!).future,
        );
        if (existing != null) {
          await ref
              .read(workoutListProvider.notifier)
              .updateWorkout(
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
        await ref
            .read(workoutListProvider.notifier)
            .createWorkout(
              name: _nameController.text.trim(),
              description: _descController.text.trim().isEmpty
                  ? null
                  : _descController.text.trim(),
              exercises: exercises,
            );
      }

      if (mounted) context.pop();
    } on Exception catch (_) {
      if (mounted) {
        context.showAthlosErrorSnack(AppLocalizations.of(context)!.genericError);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildExerciseList(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final groupColorMap = _groupColorIndexMap;
    final canReorder = !_isSupersetSelecting;

    if (_entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.fitness_center_outlined,
              size: 48,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: AthlosSpacing.sm),
            Text(
              l10n.emptyWorkoutExercises,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    Widget buildItem(BuildContext context, int index) {
      final entry = _entries[index];
      final we = entryToWorkoutExercise(
        entry,
        index,
        workoutId: widget.workoutId ?? '',
      );
      final gid = entry.groupId;
      final isGroupedWithPrev =
          index > 0 && gid != null && _entries[index - 1].groupId == gid;
      final isGroupedWithNext =
          index < _entries.length - 1 &&
          gid != null &&
          _entries[index + 1].groupId == gid;

      final exerciseName = localizedExerciseName(
        entry.exercise.name,
        isVerified: entry.exercise.isVerified,
        l10n: l10n,
      );
      final muscleGroup = localizedMuscleGroupName(
        entry.exercise.muscleGroup,
        l10n,
      );
      final prescriptionSummary = formatWorkoutExercisePrescriptionSummary(
        exercise: we,
        catalogExercise: entry.exercise,
        l10n: l10n,
      );

      final isSelected = _supersetSelectedIds.contains(entry.exercise.id);
      final isSupersetLocked = _isSupersetSelecting &&
          (_isJoiningExistingSuperset
              ? _isJoinSupersetSelectionLocked(entry)
              : isLockedInOtherSuperset(we, _supersetEditingGroupId));

      final card = WorkoutBuilderExerciseCard(
        exerciseName: exerciseName,
        muscleGroup: muscleGroup,
        prescriptionSummary: prescriptionSummary,
        isAmrap: entry.isAmrap,
        isUnilateral: entry.isUnilateral,
        isGroupedWithPrevious: isGroupedWithPrev,
        isGroupedWithNext: isGroupedWithNext,
        groupColorIndex: gid != null ? groupColorMap[gid] : null,
        isSupersetSelectionActive: _isSupersetSelecting,
        isSupersetSelected: isSelected,
        isSupersetSelectionLocked: isSupersetLocked,
        reorderListIndex: canReorder ? index : null,
        onTap: _isSupersetSelecting
            ? () => _toggleSupersetSelection(entry)
            : () => _showExerciseOptionsSheet(entry),
        onLongPress: _isSupersetSelecting
            ? null
            : () => _showExerciseOptionsSheet(entry),
      );

      if (_isSupersetSelecting) {
        return KeyedSubtree(key: ObjectKey(entry), child: card);
      }

      return Dismissible(
        key: ObjectKey(entry),
        direction: DismissDirection.horizontal,
        confirmDismiss: (direction) => _confirmDismissExercise(entry, direction),
        onDismissed: (_) {
          final removeIndex = _entries.indexOf(entry);
          if (removeIndex >= 0) _removeExerciseAt(removeIndex);
        },
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: AthlosSpacing.lg),
          margin: const EdgeInsets.symmetric(
            vertical: AthlosSpacing.xs,
            horizontal: AthlosSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: AthlosRadius.mdAll,
          ),
          child: Icon(
            Icons.edit_outlined,
            color: colorScheme.onPrimaryContainer,
          ),
        ),
        secondaryBackground: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: AthlosSpacing.lg),
          margin: const EdgeInsets.symmetric(
            vertical: AthlosSpacing.xs,
            horizontal: AthlosSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: colorScheme.errorContainer,
            borderRadius: AthlosRadius.mdAll,
          ),
          child: Icon(
            Icons.delete_outline,
            color: colorScheme.onErrorContainer,
          ),
        ),
        child: card,
      );
    }

    final list = canReorder
        ? ReorderableListView.builder(
            padding: const EdgeInsets.only(bottom: AthlosSpacing.sm),
            itemCount: _entries.length,
            onReorderItem: _onReorderEntries,
            itemBuilder: buildItem,
          )
        : ListView.builder(
            padding: const EdgeInsets.only(bottom: AthlosSpacing.sm),
            itemCount: _entries.length,
            itemBuilder: buildItem,
          );

    return Stack(
      children: [
        list,
        if (_isSupersetSelecting)
          Positioned(
            left: 0,
            right: 0,
            bottom: AthlosSpacing.lg,
            child: SupersetSelectionBar(
              onCancel: _cancelSupersetEdit,
              onConfirm: _confirmSupersetEdit,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (widget.isEditing && !_hasLoadedExisting) {
      final workoutAsync = ref.watch(workoutByIdProvider(widget.workoutId!));
      final exercisesAsync = ref.watch(
        workoutExercisesProvider(widget.workoutId!),
      );
      final allExercisesAsync = ref.watch(exerciseListProvider);

      final allReady =
          workoutAsync.hasValue &&
          exercisesAsync.hasValue &&
          allExercisesAsync.hasValue;

      if (!allReady) {
        return AthlosScaffold(
          appBar: AppBar(title: Text(l10n.editWorkout)),
          body: const Center(child: CircularProgressIndicator()),
        );
      }

      final workout = workoutAsync.value;
      if (workout == null) {
        return AthlosScaffold(
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

    return ConfirmNavigationScope(
      guardActive: _dirty,
      onConfirmLeave: confirmDiscardUnsavedEdits,
      onLeaveConfirmed: (ctx) {
        if (ctx.mounted) ctx.pop();
      },
      child: AthlosScaffold(
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
                      onChanged: (_) => _markDirty(),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? l10n.fieldRequired
                          : null,
                    ),
                    const SizedBox(height: AthlosSpacing.sm),
                    TextFormField(
                      controller: _descController,
                      decoration: InputDecoration(
                        labelText: l10n.workoutNotesTitle,
                        hintText: l10n.workoutDescriptionHint,
                      ),
                      maxLines: 2,
                      onChanged: (_) => _markDirty(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AthlosSpacing.md),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.exercisesInWorkout,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ),
              const SizedBox(height: AthlosSpacing.xs),
              Expanded(child: _buildExerciseList(context)),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AthlosSpacing.md),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isSupersetSelecting ? null : _addExercise,
                      icon: const Icon(Icons.add),
                      label: Text(l10n.addExerciseShort),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
