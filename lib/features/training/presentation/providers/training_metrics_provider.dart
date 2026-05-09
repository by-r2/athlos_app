import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/errors/result.dart';
import '../../../profile/domain/entities/body_metric.dart';
import '../../../profile/presentation/providers/body_metric_notifier.dart';
import '../../../profile/presentation/providers/profile_notifier.dart';
import '../../data/repositories/training_providers.dart';
import '../../domain/entities/execution_set.dart';
import '../../domain/entities/execution_set_segment.dart';
import '../../domain/entities/workout_exercise.dart';
import '../../domain/enums/load_mode.dart';
import '../../domain/helpers/training_metrics.dart';
import '../../domain/repositories/workout_execution_repository.dart';
import 'exercise_notifier.dart';

part 'training_metrics_provider.g.dart';

/// Weight from the body timeline at or before [instant] ([metrics] newest first).
double? profileWeightAtOrBefore(
  List<BodyMetric> metricsNewestFirst,
  DateTime instant,
) {
  for (final m in metricsNewestFirst) {
    if (!m.recordedAt.isAfter(instant)) return m.weight;
  }
  return null;
}

/// Personal record for an exercise: best estimated 1RM ever achieved.
class ExercisePR {
  final int exerciseId;

  /// Best estimated 1RM across all completed sets.
  final double best1RM;

  /// Weight and reps of the set that produced the best 1RM.
  final double weight;
  final int reps;

  const ExercisePR({
    required this.exerciseId,
    required this.best1RM,
    required this.weight,
    required this.reps,
  });
}

/// Returns the personal record (best estimated 1RM) for [exerciseId],
/// accounting for bodyweight exercises using profile weight.
@riverpod
Future<ExercisePR?> exercisePR(Ref ref, int exerciseId) async {
  final execRepo = ref.watch(workoutExecutionRepositoryProvider);
  final workoutRepo = ref.watch(workoutRepositoryProvider);
  final exercises = await ref.watch(exerciseListProvider.future);
  final exercise = exercises.where((e) => e.id == exerciseId).firstOrNull;
  if (exercise == null) return null;

  final metrics = await ref.watch(bodyMetricListProvider.future);
  final latestWeight =
      metrics.isEmpty ? null : metrics.first.weight;

  final setsResult =
      await execRepo.getCompletedSetsWithDateForExercise(exerciseId);
  if (!setsResult.isSuccess) return null;
  final rows = setsResult.getOrThrow();
  if (rows.isEmpty) return null;

  final execIds =
      rows.map((r) => r.set.executionId).toSet();
  final weByExecId = <int, WorkoutExercise?>{};
  for (final execId in execIds) {
    final execResult = await execRepo.getById(execId);
    final exec =
        execResult.isSuccess ? execResult.getOrThrow() : null;
    if (exec == null) {
      weByExecId[execId] = null;
      continue;
    }
    final wesResult = await workoutRepo.getExercises(exec.workoutId);
    if (!wesResult.isSuccess) {
      weByExecId[execId] = null;
      continue;
    }
    weByExecId[execId] = wesResult
        .getOrThrow()
        .where((we) => we.exerciseId == exerciseId)
        .firstOrNull;
  }

  ExercisePR? best;
  for (final row in rows) {
    final s = row.set;
    if (s.isWarmup) continue;

    final we = weByExecId[s.executionId];
    final profileAt = profileWeightAtOrBefore(metrics, row.date);
    final resolvedBw =
        s.bodyWeightSnapshot ?? profileAt ?? latestWeight;
    final load = effectiveLoad(
      mode: resolveLoadMode(
        set: s,
        workoutExercise: we,
        exercise: exercise,
      ),
      setWeight: s.weight,
      bodyWeight: resolvedBw,
      loadFactor: exercise.bodyweightLoadFactor,
    );
    final e1rm = estimated1RM(weight: load, reps: s.reps);
    if (e1rm != null && (best == null || e1rm > best.best1RM)) {
      best = ExercisePR(
        exerciseId: exerciseId,
        best1RM: e1rm,
        weight: load ?? 0,
        reps: s.reps ?? 1,
      );
    }
  }
  return best;
}

/// Checks whether a specific execution set represents a new PR for
/// the given exercise. Compares the set's estimated 1RM against the
/// existing PR (excluding the current execution).
///
/// The [loadMode] should already be resolved by the caller (taking into
/// account workout-level and per-set overrides). [loadFactor] is the
/// catalog's bodyweight load factor (null when the exercise is
/// pure-weighted or when the catalog hasn't populated it yet).
@riverpod
Future<bool> isSetNewPR(
  Ref ref, {
  required int exerciseId,
  required double? weight,
  required int? reps,
  required LoadMode loadMode,
  double? loadFactor,
  /// When set (e.g. snapshot + historic timeline resolved by caller), skips
  /// fetching latest weight only.
  double? resolvedBodyWeight,
}) async {
  final profileWeight = resolvedBodyWeight ??
      await ref.watch(latestBodyWeightProvider.future);

  final load = effectiveLoad(
    mode: loadMode,
    setWeight: weight,
    bodyWeight: profileWeight,
    loadFactor: loadFactor,
  );
  final setE1rm = estimated1RM(weight: load, reps: reps);
  if (setE1rm == null) return false;

  final pr = await ref.watch(exercisePRProvider(exerciseId).future);
  if (pr == null) return true;
  return setE1rm > pr.best1RM;
}

/// Weekly volume per muscle group in kg (tonnage)
/// per [MuscleGroup] in the last 7 days.
@riverpod
Future<Map<String, int>> weeklyVolumePerMuscleGroup(Ref ref) async {
  final execRepo = ref.watch(workoutExecutionRepositoryProvider);
  final exercises = await ref.watch(exerciseListProvider.future);
  final exerciseMap = {for (final e in exercises) e.id: e};
  final metrics = await ref.watch(bodyMetricListProvider.future);
  final latestBodyWeight =
      metrics.isEmpty ? null : metrics.first.weight;

  final allExecsResult = await execRepo.getAll();
  if (!allExecsResult.isSuccess) return {};
  final allExecs = allExecsResult.getOrThrow();

  final cutoff = DateTime.now().subtract(const Duration(days: 7));
  final recentExecs = allExecs
      .where((e) => e.finishedAt != null && e.startedAt.isAfter(cutoff))
      .toList();

  final volume = <String, int>{};
  for (final exec in recentExecs) {
    final sets = await _setsWithSegments(execRepo, exec.id);
    final workoutExercisesResult = await ref
        .read(workoutRepositoryProvider)
        .getExercises(exec.workoutId);
    if (!workoutExercisesResult.isSuccess) continue;
    final workoutExerciseByExerciseId = {
      for (final we in workoutExercisesResult.getOrThrow()) we.exerciseId: we,
    };
    final profileAtExec =
        profileWeightAtOrBefore(metrics, exec.startedAt);
    for (final s in sets) {
      if (!s.isCompleted) continue;
      if (s.isWarmup) continue;
      final exercise = exerciseMap[s.exerciseId];
      if (exercise == null) continue;
      final key = exercise.muscleGroup.name;
      final setVolume = computeSetVolume(
        s,
        exercise: exercise,
        workoutExercise: workoutExerciseByExerciseId[s.exerciseId],
        profileBodyWeightOnExecutionDate: profileAtExec,
        latestBodyWeight: latestBodyWeight,
      );
      volume[key] = (volume[key] ?? 0) + setVolume.round();
    }
  }
  return volume;
}

/// Volume recommendation ranges based on experience level.
/// Returns (min, max) sets per muscle group per week.
({int min, int max}) volumeTargetForLevel(String? experienceLevel) =>
    switch (experienceLevel) {
      'beginner' => (min: 10, max: 14),
      'intermediate' => (min: 14, max: 20),
      'advanced' || 'expert' => (min: 20, max: 30),
      _ => (min: 10, max: 20),
    };

/// Finished sessions in the current calendar week (Mon–Sun).
@riverpod
Future<int> thisWeekSessionCount(Ref ref) async {
  final execRepo = ref.watch(workoutExecutionRepositoryProvider);
  final allResult = await execRepo.getAll();
  if (!allResult.isSuccess) return 0;
  final all = allResult.getOrThrow();

  final now = DateTime.now();
  final weekday = now.weekday; // 1=Mon … 7=Sun
  final monday = DateTime(now.year, now.month, now.day - (weekday - 1));
  return all
      .where((e) => e.finishedAt != null && !e.startedAt.isBefore(monday))
      .length;
}

/// Default training frequency when the user hasn't set one.
const kDefaultTrainingFrequency = 3;

/// Weekly consistency status for the frequency streak card.
class ConsistencyStatus {
  final int streakCount;
  final bool isCurrentWeekSecured;

  const ConsistencyStatus({
    required this.streakCount,
    required this.isCurrentWeekSecured,
  });
}

/// Consecutive secured weeks (Mon-Sun) where the user completed at least
/// [trainingFrequency] sessions.
///
/// If the current week is not secured yet, the streak is anchored on the
/// previous week so the historical streak persists while the current week is
/// still in progress.
@riverpod
Future<ConsistencyStatus> consistencyStatus(Ref ref) async {
  final execRepo = ref.watch(workoutExecutionRepositoryProvider);
  final profile = await ref.watch(profileProvider.future);
  final target = profile?.trainingFrequency ?? kDefaultTrainingFrequency;

  final allResult = await execRepo.getAll();
  if (!allResult.isSuccess) {
    return const ConsistencyStatus(streakCount: 0, isCurrentWeekSecured: false);
  }
  final all = allResult.getOrThrow();
  final finished = all.where((e) => e.finishedAt != null).toList();
  if (finished.isEmpty) {
    return const ConsistencyStatus(streakCount: 0, isCurrentWeekSecured: false);
  }

  final now = DateTime.now();
  final thisMonday =
      DateTime(now.year, now.month, now.day - (now.weekday - 1));

  final thisWeekEnd = thisMonday.add(const Duration(days: 7));
  final thisWeekCount = finished
      .where((e) =>
          !e.startedAt.isBefore(thisMonday) && e.startedAt.isBefore(thisWeekEnd))
      .length;
  final isCurrentWeekSecured = thisWeekCount >= target;

  var streak = 0;
  var weekStart = isCurrentWeekSecured
      ? thisMonday
      : thisMonday.subtract(const Duration(days: 7));

  while (true) {
    final weekEnd = weekStart.add(const Duration(days: 7));
    final count = finished
        .where((e) =>
            !e.startedAt.isBefore(weekStart) && e.startedAt.isBefore(weekEnd))
        .length;
    if (count >= target) {
      streak++;
      weekStart = weekStart.subtract(const Duration(days: 7));
    } else {
      break;
    }
  }
  return ConsistencyStatus(
    streakCount: streak,
    isCurrentWeekSecured: isCurrentWeekSecured,
  );
}

/// Backward-compatible streak count for existing call sites.
@riverpod
Future<int> consistencyStreak(Ref ref) async {
  final status = await ref.watch(consistencyStatusProvider.future);
  return status.streakCount;
}

// ── Phase 10: Progress Visualization providers ──────────────────────

/// A data point for the per-exercise load chart.
class LoadDataPoint {
  final DateTime date;
  final double estimated1RM;
  final double weight;
  final int reps;

  const LoadDataPoint({
    required this.date,
    required this.estimated1RM,
    required this.weight,
    required this.reps,
  });
}

/// Time range filter for charts.
enum ChartTimeRange { days30, days90, allTime }

/// Per-exercise load history for charting (best estimated 1RM per session day).
@riverpod
Future<List<LoadDataPoint>> exerciseLoadHistory(
  Ref ref,
  int exerciseId, {
  ChartTimeRange range = ChartTimeRange.allTime,
}) async {
  final execRepo = ref.watch(workoutExecutionRepositoryProvider);
  final exercises = await ref.watch(exerciseListProvider.future);
  final exercise = exercises.where((e) => e.id == exerciseId).firstOrNull;
  if (exercise == null) return [];

  final workoutRepo = ref.watch(workoutRepositoryProvider);
  final metrics = await ref.watch(bodyMetricListProvider.future);
  final latestWeight =
      metrics.isEmpty ? null : metrics.first.weight;

  final result = await execRepo.getCompletedSetsWithDateForExercise(exerciseId);
  if (!result.isSuccess) return [];
  var rows = result.getOrThrow();

  if (range != ChartTimeRange.allTime) {
    final days = range == ChartTimeRange.days30 ? 30 : 90;
    final cutoff = DateTime.now().subtract(Duration(days: days));
    rows = rows.where((r) => r.date.isAfter(cutoff)).toList();
  }

  final execIds = rows.map((r) => r.set.executionId).toSet();
  final weByExecId = <int, WorkoutExercise?>{};
  for (final execId in execIds) {
    final execResult = await execRepo.getById(execId);
    final exec =
        execResult.isSuccess ? execResult.getOrThrow() : null;
    if (exec == null) {
      weByExecId[execId] = null;
      continue;
    }
    final wesResult = await workoutRepo.getExercises(exec.workoutId);
    if (!wesResult.isSuccess) {
      weByExecId[execId] = null;
      continue;
    }
    weByExecId[execId] = wesResult
        .getOrThrow()
        .where((we) => we.exerciseId == exerciseId)
        .firstOrNull;
  }

  // Group by date (day precision) → pick best e1RM per day.
  final byDay = <String, LoadDataPoint>{};
  for (final r in rows) {
    if (r.set.isWarmup) continue;
    final we = weByExecId[r.set.executionId];
    final profileAt = profileWeightAtOrBefore(metrics, r.date);
    final resolvedBw =
        r.set.bodyWeightSnapshot ?? profileAt ?? latestWeight;
    final load = effectiveLoad(
      mode: resolveLoadMode(
        set: r.set,
        workoutExercise: we,
        exercise: exercise,
      ),
      setWeight: r.set.weight,
      bodyWeight: resolvedBw,
      loadFactor: exercise.bodyweightLoadFactor,
    );
    final e1rm = estimated1RM(weight: load, reps: r.set.reps);
    if (e1rm == null) continue;
    final dayKey = '${r.date.year}-${r.date.month}-${r.date.day}';
    final existing = byDay[dayKey];
    if (existing == null || e1rm > existing.estimated1RM) {
      byDay[dayKey] = LoadDataPoint(
        date: DateTime(r.date.year, r.date.month, r.date.day),
        estimated1RM: e1rm,
        weight: load ?? 0,
        reps: r.set.reps ?? 1,
      );
    }
  }
  return byDay.values.toList()..sort((a, b) => a.date.compareTo(b.date));
}

/// PR data for a single exercise (for PR History screen).
class ExercisePRRecord {
  final int exerciseId;
  final String exerciseName;
  final String muscleGroup;
  final bool isVerified;
  final double best1RM;
  final double weight;
  final int reps;

  const ExercisePRRecord({
    required this.exerciseId,
    required this.exerciseName,
    required this.muscleGroup,
    required this.isVerified,
    required this.best1RM,
    required this.weight,
    required this.reps,
  });
}

/// All PRs across all exercises, sorted by best 1RM descending.
@riverpod
Future<List<ExercisePRRecord>> allExercisePRs(Ref ref) async {
  final exercises = await ref.watch(exerciseListProvider.future);
  final prs = <ExercisePRRecord>[];
  for (final ex in exercises) {
    final pr = await ref.watch(exercisePRProvider(ex.id).future);
    if (pr != null) {
      prs.add(
        ExercisePRRecord(
          exerciseId: ex.id,
          exerciseName: ex.name,
          muscleGroup: ex.muscleGroup.name,
          isVerified: ex.isVerified,
          best1RM: pr.best1RM,
          weight: pr.weight,
          reps: pr.reps,
        ),
      );
    }
  }
  prs.sort((a, b) => b.best1RM.compareTo(a.best1RM));
  return prs;
}

/// Weekly volume per muscle group over [weeks] weeks (kg tonnage trend).
@riverpod
Future<Map<String, List<({DateTime weekStart, int sets})>>> weeklyVolumeTrend(
  Ref ref, {
  int weeks = 8,
}) async {
  final execRepo = ref.watch(workoutExecutionRepositoryProvider);
  final exercises = await ref.watch(exerciseListProvider.future);
  final exerciseMap = {for (final e in exercises) e.id: e};
  final metrics = await ref.watch(bodyMetricListProvider.future);
  final latestBodyWeight =
      metrics.isEmpty ? null : metrics.first.weight;

  final allExecsResult = await execRepo.getAll();
  if (!allExecsResult.isSuccess) return {};
  final allExecs = allExecsResult.getOrThrow();

  final now = DateTime.now();
  final cutoff = now.subtract(Duration(days: weeks * 7));
  final recentExecs = allExecs
      .where((e) => e.finishedAt != null && e.startedAt.isAfter(cutoff))
      .toList();

  // { muscleGroup: { weekIndex: kg } }
  final data = <String, Map<int, int>>{};

  for (final exec in recentExecs) {
    final sets = await _setsWithSegments(execRepo, exec.id);
    final workoutExercisesResult = await ref
        .read(workoutRepositoryProvider)
        .getExercises(exec.workoutId);
    if (!workoutExercisesResult.isSuccess) continue;
    final workoutExerciseByExerciseId = {
      for (final we in workoutExercisesResult.getOrThrow()) we.exerciseId: we,
    };
    final profileAtExec =
        profileWeightAtOrBefore(metrics, exec.startedAt);
    final weekIdx = now.difference(exec.startedAt).inDays ~/ 7;
    for (final s in sets) {
      if (!s.isCompleted) continue;
      if (s.isWarmup) continue;
      final exercise = exerciseMap[s.exerciseId];
      if (exercise == null) continue;
      final key = exercise.muscleGroup.name;
      data.putIfAbsent(key, () => {});
      final setVolume = computeSetVolume(
        s,
        exercise: exercise,
        workoutExercise: workoutExerciseByExerciseId[s.exerciseId],
        profileBodyWeightOnExecutionDate: profileAtExec,
        latestBodyWeight: latestBodyWeight,
      );
      data[key]![weekIdx] = (data[key]![weekIdx] ?? 0) + setVolume.round();
    }
  }

  // Convert to list of (weekStart, sets) per muscle group.
  final result = <String, List<({DateTime weekStart, int sets})>>{};
  for (final entry in data.entries) {
    final points = <({DateTime weekStart, int sets})>[];
    for (var w = weeks - 1; w >= 0; w--) {
      final weekStart = now.subtract(Duration(days: (w + 1) * 7));
      points.add((
        weekStart: DateTime(weekStart.year, weekStart.month, weekStart.day),
        sets: entry.value[w] ?? 0,
      ));
    }
    result[entry.key] = points;
  }
  return result;
}

Future<List<ExecutionSet>> _setsWithSegments(
  WorkoutExecutionRepository execRepo,
  int executionId,
) async {
  final setsResult = await execRepo.getSets(executionId);
  if (!setsResult.isSuccess) return const [];
  final sets = setsResult.getOrThrow();

  final segmentsResult = await execRepo.getSegmentsForExecution(executionId);
  if (!segmentsResult.isSuccess) return sets;
  final allSegments = segmentsResult.getOrThrow();
  if (allSegments.isEmpty) return sets;

  final bySetId = <int, List<ExecutionSetSegment>>{};
  for (final seg in allSegments) {
    bySetId.putIfAbsent(seg.executionSetId, () => []).add(seg);
  }

  return sets.map((s) {
    final attached = bySetId[s.id];
    if (attached == null || attached.isEmpty) return s;
    return ExecutionSet(
      id: s.id,
      executionId: s.executionId,
      exerciseId: s.exerciseId,
      setNumber: s.setNumber,
      plannedReps: s.plannedReps,
      plannedWeight: s.plannedWeight,
      reps: s.reps,
      weight: s.weight,
      duration: s.duration,
      distance: s.distance,
      isCompleted: s.isCompleted,
      isWarmup: s.isWarmup,
      rpe: s.rpe,
      bodyWeightSnapshot: s.bodyWeightSnapshot,
      loadModeOverride: s.loadModeOverride,
      leftReps: s.leftReps,
      leftWeight: s.leftWeight,
      rightReps: s.rightReps,
      rightWeight: s.rightWeight,
      isUnilateral: s.isUnilateral,
      segments: attached,
    );
  }).toList();
}
