import '../../domain/entities/workout_exercise.dart';

/// Whether [catalogExerciseId] already appears in [exercises].
bool workoutAlreadyContainsExercise(
  Iterable<WorkoutExercise> exercises,
  String catalogExerciseId,
) => exercises.any((e) => e.exerciseId == catalogExerciseId);

/// Deep-copies [exercises] for in-session baseline snapshots.
List<WorkoutExercise> cloneWorkoutExercises(List<WorkoutExercise> exercises) =>
    [
      for (final e in exercises)
        WorkoutExercise(
          id: e.id,
          workoutId: e.workoutId,
          exerciseId: e.exerciseId,
          sortOrder: e.sortOrder,
          sets: e.sets,
          minReps: e.minReps,
          maxReps: e.maxReps,
          isAmrap: e.isAmrap,
          restSeconds: e.restSeconds,
          durationSeconds: e.durationSeconds,
          groupId: e.groupId,
          isUnilateral: e.isUnilateral,
          loadModeOverride: e.loadModeOverride,
          notes: e.notes,
        ),
    ];

/// Whether two exercise lists differ in structure (order, membership, prescription).
bool workoutExercisesStructurallyEqual(
  List<WorkoutExercise> a,
  List<WorkoutExercise> b,
) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    final x = a[i];
    final y = b[i];
    if (x.exerciseId != y.exerciseId ||
        x.sortOrder != y.sortOrder ||
        x.sets != y.sets ||
        x.minReps != y.minReps ||
        x.maxReps != y.maxReps ||
        x.restSeconds != y.restSeconds ||
        x.durationSeconds != y.durationSeconds ||
        x.groupId != y.groupId ||
        x.isAmrap != y.isAmrap ||
        x.isUnilateral != y.isUnilateral ||
        x.loadModeOverride != y.loadModeOverride) {
      return false;
    }
  }
  return true;
}

/// Whether a superset block or standalone exercise has any completed set.
bool blockHasCompletedSets({
  required List<WorkoutExercise> exercises,
  required int blockStartIndex,
  required bool Function(String rowId) hasCompletedSet,
}) {
  for (final rowId in blockWorkoutExerciseRowIds(exercises, blockStartIndex)) {
    if (hasCompletedSet(rowId)) return true;
  }
  return false;
}

/// WorkoutExercise row ids in the reorder block starting at [blockStartIndex].
List<String> blockWorkoutExerciseRowIds(
  List<WorkoutExercise> exercises,
  int blockStartIndex,
) {
  if (blockStartIndex < 0 || blockStartIndex >= exercises.length) {
    return const [];
  }
  final start = exercises[blockStartIndex];
  if (start.groupId == null) return [start.id];

  final groupId = start.groupId!;
  return [
    for (final e in exercises)
      if (e.groupId == groupId) e.id,
  ];
}
