import '../../domain/entities/execution_context_fallback.dart';
import '../../domain/entities/execution_set.dart';

/// One block in execution detail (template line or legacy catalog exercise).
class ExecutionDetailGroup {
  final String? workoutExerciseId;
  final String primaryExerciseId;
  final List<ExecutionSet> sets;
  final ExecutionContextFallbackLine? lineSnapshot;

  const ExecutionDetailGroup({
    this.workoutExerciseId,
    required this.primaryExerciseId,
    required this.sets,
    this.lineSnapshot,
  });

  /// Distinct catalog ids performed in this block (preserves insertion order).
  List<String> get performedExerciseIds {
    final seen = <String>{};
    final ordered = <String>[];
    for (final s in sets) {
      if (seen.add(s.exerciseId)) ordered.add(s.exerciseId);
    }
    return ordered;
  }
}

/// Groups [sets] by template line when [workoutExerciseId] is present; otherwise
/// by catalog [exerciseId] (legacy sessions).
List<ExecutionDetailGroup> groupExecutionSetsForDetail({
  required List<ExecutionSet> sets,
  ExecutionContextFallback? fallback,
}) {
  if (sets.isEmpty) return const [];

  final hasRowIds = sets.any(
    (s) => s.workoutExerciseId != null && s.workoutExerciseId!.isNotEmpty,
  );

  if (!hasRowIds) {
    final byExercise = <String, List<ExecutionSet>>{};
    for (final s in sets) {
      (byExercise[s.exerciseId] ??= []).add(s);
    }
    return [
      for (final entry in byExercise.entries)
        ExecutionDetailGroup(
          primaryExerciseId: entry.key,
          sets: entry.value
            ..sort((a, b) => a.setNumber.compareTo(b.setNumber)),
        ),
    ];
  }

  final byRow = <String, List<ExecutionSet>>{};
  final legacyByExercise = <String, List<ExecutionSet>>{};
  for (final s in sets) {
    final rowId = s.workoutExerciseId;
    if (rowId != null && rowId.isNotEmpty) {
      (byRow[rowId] ??= []).add(s);
    } else {
      (legacyByExercise[s.exerciseId] ??= []).add(s);
    }
  }

  final groups = <ExecutionDetailGroup>[];

  if (fallback != null && fallback.lines.isNotEmpty) {
    final sortedLines = fallback.lines.values.toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    for (final line in sortedLines) {
      final rowSets = byRow.remove(line.workoutExerciseId);
      if (rowSets == null || rowSets.isEmpty) continue;
      rowSets.sort((a, b) => a.setNumber.compareTo(b.setNumber));
      groups.add(
        ExecutionDetailGroup(
          workoutExerciseId: line.workoutExerciseId,
          primaryExerciseId: line.exerciseId,
          sets: rowSets,
          lineSnapshot: line,
        ),
      );
    }
  }

  for (final entry in byRow.entries) {
    entry.value.sort((a, b) => a.setNumber.compareTo(b.setNumber));
    final primary = entry.value.first.exerciseId;
    groups.add(
      ExecutionDetailGroup(
        workoutExerciseId: entry.key,
        primaryExerciseId: primary,
        sets: entry.value,
      ),
    );
  }

  for (final entry in legacyByExercise.entries) {
    entry.value.sort((a, b) => a.setNumber.compareTo(b.setNumber));
    groups.add(
      ExecutionDetailGroup(
        primaryExerciseId: entry.key,
        sets: entry.value,
      ),
    );
  }

  return groups;
}
