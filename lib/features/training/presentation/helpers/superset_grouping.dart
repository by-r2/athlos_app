import '../../domain/entities/workout_exercise.dart';

/// Next available superset [WorkoutExercise.groupId] for a workout list.
int nextSupersetGroupId(Iterable<WorkoutExercise> exercises) {
  var next = 0;
  for (final e in exercises) {
    final gid = e.groupId;
    if (gid != null && gid >= next) next = gid + 1;
  }
  return next;
}

/// Maps each distinct [WorkoutExercise.groupId] to a color index (0, 1, 2, …).
Map<int, int> supersetColorIndexByGroupId(Iterable<WorkoutExercise> exercises) {
  final seen = <int, int>{};
  var nextIdx = 0;
  for (final e in exercises) {
    final gid = e.groupId;
    if (gid != null && !seen.containsKey(gid)) {
      seen[gid] = nextIdx++;
    }
  }
  return seen;
}

/// Copies [source] with optional overrides (all other fields preserved).
WorkoutExercise copyWorkoutExercise(
  WorkoutExercise source, {
  int? groupId,
  bool clearGroupId = false,
  int? restSeconds,
  int? sortOrder,
}) {
  return WorkoutExercise(
    id: source.id,
    workoutId: source.workoutId,
    exerciseId: source.exerciseId,
    sortOrder: sortOrder ?? source.sortOrder,
    sets: source.sets,
    minReps: source.minReps,
    maxReps: source.maxReps,
    isAmrap: source.isAmrap,
    restSeconds: restSeconds ?? source.restSeconds,
    durationSeconds: source.durationSeconds,
    groupId: clearGroupId ? null : (groupId ?? source.groupId),
    isUnilateral: source.isUnilateral,
    loadModeOverride: source.loadModeOverride,
    notes: source.notes,
  );
}

/// Toggles superset link between [index] and [index + 1] (same rules as workout builder).
List<WorkoutExercise> toggleSupersetLinkAt(
  List<WorkoutExercise> exercises,
  int index, {
  required int nextGroupId,
}) {
  if (index < 0 || index >= exercises.length - 1) return exercises;

  final current = exercises[index];
  final next = exercises[index + 1];
  final updated = List<WorkoutExercise>.from(exercises);

  if (current.groupId != null && current.groupId == next.groupId) {
    final oldGroupId = current.groupId;
    for (var i = 0; i < updated.length; i++) {
      if (updated[i].groupId == oldGroupId) {
        updated[i] = copyWorkoutExercise(updated[i], clearGroupId: true);
      }
    }
    return updated;
  }

  final gid = current.groupId ?? next.groupId ?? nextGroupId;
  final groupRest = current.restSeconds;

  updated[index] = copyWorkoutExercise(updated[index], groupId: gid, restSeconds: groupRest);
  updated[index + 1] =
      copyWorkoutExercise(updated[index + 1], groupId: gid, restSeconds: groupRest);

  for (var i = 0; i < updated.length; i++) {
    if (updated[i].groupId == gid) {
      updated[i] = copyWorkoutExercise(updated[i], groupId: gid, restSeconds: groupRest);
    }
  }

  return reorderSupersetBlocksContiguously(updated);
}

/// Clears [groupId] when a group has only one exercise left (e.g. after removal).
List<WorkoutExercise> normalizeLonelySupersetGroups(List<WorkoutExercise> exercises) {
  final counts = <int, int>{};
  for (final e in exercises) {
    final gid = e.groupId;
    if (gid != null) counts[gid] = (counts[gid] ?? 0) + 1;
  }

  final lonely = counts.entries
      .where((e) => e.value < 2)
      .map((e) => e.key)
      .toSet();
  if (lonely.isEmpty) return exercises;

  return [
    for (final e in exercises)
      lonely.contains(e.groupId)
          ? copyWorkoutExercise(e, clearGroupId: true)
          : e,
  ];
}

/// Whether [exercise] belongs to a different superset than [editingGroupId].
bool isLockedInOtherSuperset(WorkoutExercise exercise, int? editingGroupId) =>
    exercise.groupId != null && exercise.groupId != editingGroupId;

/// Applies membership for one superset without touching other groups.
///
/// [linkedExerciseIds]: marked = in this superset after confirm.
/// [editingGroupId]: `null` when creating a new group; set when editing an existing one.
List<WorkoutExercise> applySupersetSelection(
  List<WorkoutExercise> exercises,
  Set<String> linkedExerciseIds, {
  int? editingGroupId,
}) {
  final updated = List<WorkoutExercise>.from(exercises);

  for (var i = 0; i < updated.length; i++) {
    final e = updated[i];
    if (isLockedInOtherSuperset(e, editingGroupId)) continue;

    if (!linkedExerciseIds.contains(e.exerciseId)) {
      updated[i] = copyWorkoutExercise(e, clearGroupId: true);
    }
  }

  final linkedInScope = linkedExerciseIds
      .where(
        (id) => exercises.any(
          (e) => e.exerciseId == id && !isLockedInOtherSuperset(e, editingGroupId),
        ),
      )
      .toSet();

  if (linkedInScope.length < 2) {
    for (var i = 0; i < updated.length; i++) {
      if (linkedInScope.contains(updated[i].exerciseId)) {
        updated[i] = copyWorkoutExercise(updated[i], clearGroupId: true);
      }
    }
    return reorderSupersetBlocksContiguously(
      normalizeLonelySupersetGroups(updated),
    );
  }

  final gid = editingGroupId ?? nextSupersetGroupId(exercises);
  var groupRest = updated
      .firstWhere((e) => linkedInScope.contains(e.exerciseId))
      .restSeconds;
  for (final e in updated) {
    if (!linkedInScope.contains(e.exerciseId)) continue;
    if (e.restSeconds < groupRest) groupRest = e.restSeconds;
  }

  for (var i = 0; i < updated.length; i++) {
    final e = updated[i];
    if (isLockedInOtherSuperset(e, editingGroupId)) continue;
    if (linkedInScope.contains(e.exerciseId)) {
      updated[i] = copyWorkoutExercise(e, groupId: gid, restSeconds: groupRest);
    }
  }

  return reorderSupersetBlocksContiguously(
    normalizeLonelySupersetGroups(updated),
  );
}

/// Puts each superset's members in one adjacent block (at the first member's slot).
List<WorkoutExercise> reorderSupersetBlocksContiguously(
  List<WorkoutExercise> exercises,
) {
  final result = <WorkoutExercise>[];
  final emittedExerciseIds = <String>{};
  final emittedGroupIds = <int>{};

  for (final e in exercises) {
    if (emittedExerciseIds.contains(e.exerciseId)) continue;

    final gid = e.groupId;
    if (gid != null && !emittedGroupIds.contains(gid)) {
      final block = [
        for (final x in exercises)
          if (x.groupId == gid) x,
      ];
      if (block.length >= 2) {
        emittedGroupIds.add(gid);
        for (final x in block) {
          result.add(x);
          emittedExerciseIds.add(x.exerciseId);
        }
        continue;
      }
    }

    result.add(e);
    emittedExerciseIds.add(e.exerciseId);
  }

  return reindexSortOrder(result);
}

List<WorkoutExercise> reindexSortOrder(List<WorkoutExercise> exercises) => [
      for (var i = 0; i < exercises.length; i++)
        copyWorkoutExercise(exercises[i], sortOrder: i),
    ];

/// Reorders [exercises]; when [oldIndex] is in a superset, the whole block moves.
List<WorkoutExercise> reorderExercisesInList(
  List<WorkoutExercise> exercises,
  int oldIndex,
  int newIndex,
) {
  if (oldIndex < 0 ||
      oldIndex >= exercises.length ||
      newIndex < 0 ||
      newIndex > exercises.length ||
      oldIndex == newIndex) {
    return exercises;
  }

  var blockStart = oldIndex;
  var blockEnd = oldIndex;
  final gid = exercises[oldIndex].groupId;
  if (gid != null) {
    while (blockStart > 0 && exercises[blockStart - 1].groupId == gid) {
      blockStart--;
    }
    while (blockEnd < exercises.length - 1 &&
        exercises[blockEnd + 1].groupId == gid) {
      blockEnd++;
    }
  }

  final updated = List<WorkoutExercise>.from(exercises);
  final block = updated.sublist(blockStart, blockEnd + 1);
  updated.removeRange(blockStart, blockEnd + 1);

  var insertAt = newIndex;
  if (blockStart < insertAt) {
    insertAt -= block.length;
  }
  insertAt = insertAt.clamp(0, updated.length);
  updated.insertAll(insertAt, block);

  return reindexSortOrder(updated);
}

/// Removes a single exercise from its superset; other groups are unchanged.
List<WorkoutExercise> unlinkExerciseFromSuperset(
  List<WorkoutExercise> exercises,
  String exerciseId,
) {
  final updated = [
    for (final e in exercises)
      e.exerciseId == exerciseId
          ? copyWorkoutExercise(e, clearGroupId: true)
          : e,
  ];
  return normalizeLonelySupersetGroups(updated);
}

/// When one exercise in a superset changes rest, sync the whole group.
List<WorkoutExercise> syncSupersetRestInList(
  List<WorkoutExercise> exercises,
  WorkoutExercise updated,
) {
  final gid = updated.groupId;
  return [
    for (final e in exercises)
      if (gid != null && e.groupId == gid)
        copyWorkoutExercise(e, groupId: gid, restSeconds: updated.restSeconds)
      else if (e.id == updated.id)
        updated
      else
        e,
  ];
}
