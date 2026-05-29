import '../../domain/entities/workout_exercise.dart';
import '../widgets/workout_exercise_tile.dart';

/// Maps in-memory [WorkoutExerciseEntry] rows to [WorkoutExercise] for shared list ops.
WorkoutExercise entryToWorkoutExercise(
  WorkoutExerciseEntry entry,
  int sortOrder, {
  String workoutId = '',
}) {
  return WorkoutExercise(
    id: entry.workoutExerciseRowId ?? '',
    workoutId: workoutId,
    exerciseId: entry.exercise.id,
    sortOrder: sortOrder,
    sets: entry.sets,
    minReps: entry.minReps,
    maxReps: entry.maxReps,
    isAmrap: entry.isAmrap,
    restSeconds: entry.rest,
    durationSeconds: entry.duration,
    groupId: entry.groupId,
    isUnilateral: entry.isUnilateral,
    loadModeOverride: entry.loadModeOverride,
    notes: entry.notes,
  );
}

List<WorkoutExercise> entriesAsWorkoutExercises(
  List<WorkoutExerciseEntry> entries, {
  String workoutId = '',
}) => [
  for (var i = 0; i < entries.length; i++)
    entryToWorkoutExercise(entries[i], i, workoutId: workoutId),
];

void applyWorkoutExerciseToEntry(
  WorkoutExercise source,
  WorkoutExerciseEntry target,
) {
  target.sets = source.sets;
  target.minReps = source.minReps;
  target.maxReps = source.maxReps;
  target.isAmrap = source.isAmrap;
  target.rest = source.restSeconds;
  target.duration = source.durationSeconds;
  target.groupId = source.groupId;
  target.isUnilateral = source.isUnilateral;
  target.loadModeOverride = source.loadModeOverride;
  target.notes = source.notes;
}

/// Reorders [target] and syncs prescription fields from [ordered].
void syncEntryListFromWorkoutExercises(
  List<WorkoutExerciseEntry> target,
  List<WorkoutExercise> ordered,
) {
  final byExerciseId = {for (final e in target) e.exercise.id: e};
  target
    ..clear()
    ..addAll([
      for (final we in ordered)
        () {
          final entry = byExerciseId[we.exerciseId]!;
          applyWorkoutExerciseToEntry(we, entry);
          return entry;
        }(),
    ]);
}

int maxSupersetGroupId(Iterable<WorkoutExerciseEntry> entries) {
  var next = 0;
  for (final e in entries) {
    final gid = e.groupId;
    if (gid != null && gid >= next) next = gid + 1;
  }
  return next;
}
