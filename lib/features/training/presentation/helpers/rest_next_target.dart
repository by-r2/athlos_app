import '../providers/active_execution_state.dart';

typedef RestNextTarget = ({int exerciseIndex, int setNumber});

/// Returns the next set that should open after the current rest timer.
///
/// Supersets restart at the first pending exercise in the group for the next
/// round, instead of continuing from the exercise that happened to finish last.
RestNextTarget? findNextRestTarget(
  ActiveExecutionState exec, {
  required int focusedExerciseIndex,
  required int focusedSetNumber,
}) {
  final currentExercise = exec.exercises[focusedExerciseIndex];
  final groupId = currentExercise.groupId;

  if (groupId != null) {
    final groupNext = <RestNextTarget>[];
    for (var i = 0; i < exec.exercises.length; i++) {
      if (exec.exercises[i].groupId != groupId) continue;

      final rowId = exec.exercises[i].id;
      final firstPending = (exec.exerciseSets[rowId] ?? [])
          .where((set) => !set.isCompleted)
          .firstOrNull;
      if (firstPending != null) {
        groupNext.add((exerciseIndex: i, setNumber: firstPending.setNumber));
      }
    }

    if (groupNext.isNotEmpty) {
      groupNext.sort((a, b) {
        final bySet = a.setNumber.compareTo(b.setNumber);
        if (bySet != 0) return bySet;
        return a.exerciseIndex.compareTo(b.exerciseIndex);
      });
      return groupNext.first;
    }
  }

  final rowId = currentExercise.id;
  final nextInExercise = (exec.exerciseSets[rowId] ?? [])
      .where((set) => !set.isCompleted && set.setNumber > focusedSetNumber)
      .firstOrNull;
  if (nextInExercise != null) {
    return (
      exerciseIndex: focusedExerciseIndex,
      setNumber: nextInExercise.setNumber,
    );
  }

  for (var i = 0; i < exec.exercises.length; i++) {
    final candidateRowId = exec.exercises[i].id;
    final firstPending = (exec.exerciseSets[candidateRowId] ?? [])
        .where((set) => !set.isCompleted)
        .firstOrNull;
    if (firstPending != null) {
      return (exerciseIndex: i, setNumber: firstPending.setNumber);
    }
  }

  return null;
}
