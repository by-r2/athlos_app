import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/errors/result.dart';
import '../../../profile/domain/entities/body_metric.dart';
import '../../../profile/presentation/providers/body_metric_notifier.dart';
import '../../../profile/presentation/providers/profile_notifier.dart';
import '../../data/repositories/training_providers.dart';
import '../../domain/entities/workout_exercise.dart';
import '../../domain/enums/load_mode.dart';
import '../../domain/helpers/training_metrics.dart';
import '../../domain/helpers/week_calendar.dart';
import 'exercise_notifier.dart';

part 'training_metrics_provider.g.dart';

/// Calendar week bucket (Monday local) with working-set tally for trend charts.
typedef WeeklyMuscleWorkingSetPoint = ({
  DateTime weekStartMonday,
  int workingSetCount,
});

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
  final latestWeight = metrics.isEmpty ? null : metrics.first.weight;

  final setsResult = await execRepo.getCompletedSetsWithDateForExercise(
    exerciseId,
  );
  if (!setsResult.isSuccess) return null;
  final rows = setsResult.getOrThrow();
  if (rows.isEmpty) return null;

  final execIds = rows.map((r) => r.set.executionId).toSet();
  final weByExecId = <int, WorkoutExercise?>{};
  for (final execId in execIds) {
    final execResult = await execRepo.getById(execId);
    final exec = execResult.isSuccess ? execResult.getOrThrow() : null;
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
        (s.bodyWeightSnapshot ?? profileAt ?? latestWeight) ?? 0.0;

    for (final probe in strengthEffortsForEstimated1Rm(
      s,
      exercise: exercise,
      workoutExercise: we,
      resolvedBodyWeight: resolvedBw,
    )) {
      final e1rm = estimated1RM(weight: probe.loadKg, reps: probe.reps);
      if (e1rm != null && (best == null || e1rm > best.best1RM)) {
        best = ExercisePR(
          exerciseId: exerciseId,
          best1RM: e1rm,
          weight: probe.loadKg,
          reps: probe.reps,
        );
      }
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
  final profileWeight =
      resolvedBodyWeight ?? await ref.watch(latestBodyWeightProvider.future);

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

/// Working sets per muscle group (excluding warmups) over the last 7 rolling days.
@riverpod
Future<Map<String, int>> weeklyVolumePerMuscleGroup(Ref ref) async {
  final execRepo = ref.watch(workoutExecutionRepositoryProvider);
  final exercises = await ref.watch(exerciseListProvider.future);
  final exerciseMap = {for (final e in exercises) e.id: e};

  final allExecsResult = await execRepo.getAll();
  if (!allExecsResult.isSuccess) return {};
  final allExecs = allExecsResult.getOrThrow();

  final cutoff = DateTime.now().subtract(const Duration(days: 7));
  final recentExecs = allExecs
      .where((e) => e.finishedAt != null && e.startedAt.isAfter(cutoff))
      .toList();

  final tally = <String, int>{};
  for (final exec in recentExecs) {
    final setsResult = await execRepo.getSets(exec.id);
    if (!setsResult.isSuccess) continue;
    final sets = setsResult.getOrThrow();
    for (final s in sets) {
      if (!s.isCompleted) continue;
      if (s.isWarmup) continue;
      final exercise = exerciseMap[s.exerciseId];
      if (exercise == null) continue;
      final key = exercise.muscleGroup.name;
      tally[key] = (tally[key] ?? 0) + 1;
    }
  }
  return tally;
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
  final thisMonday = DateTime(now.year, now.month, now.day - (now.weekday - 1));

  final thisWeekEnd = thisMonday.add(const Duration(days: 7));
  final thisWeekCount = finished
      .where(
        (e) =>
            !e.startedAt.isBefore(thisMonday) &&
            e.startedAt.isBefore(thisWeekEnd),
      )
      .length;
  final isCurrentWeekSecured = thisWeekCount >= target;

  var streak = 0;
  var weekStart = isCurrentWeekSecured
      ? thisMonday
      : thisMonday.subtract(const Duration(days: 7));

  while (true) {
    final weekEnd = weekStart.add(const Duration(days: 7));
    final count = finished
        .where(
          (e) =>
              !e.startedAt.isBefore(weekStart) && e.startedAt.isBefore(weekEnd),
        )
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
  final latestWeight = metrics.isEmpty ? null : metrics.first.weight;

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
    final exec = execResult.isSuccess ? execResult.getOrThrow() : null;
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
        (r.set.bodyWeightSnapshot ?? profileAt ?? latestWeight) ?? 0.0;

    for (final probe in strengthEffortsForEstimated1Rm(
      r.set,
      exercise: exercise,
      workoutExercise: we,
      resolvedBodyWeight: resolvedBw,
    )) {
      final e1rm = estimated1RM(weight: probe.loadKg, reps: probe.reps);
      if (e1rm == null) continue;
      final dayKey = '${r.date.year}-${r.date.month}-${r.date.day}';
      final existing = byDay[dayKey];
      if (existing == null || e1rm > existing.estimated1RM) {
        byDay[dayKey] = LoadDataPoint(
          date: DateTime(r.date.year, r.date.month, r.date.day),
          estimated1RM: e1rm,
          weight: probe.loadKg,
          reps: probe.reps,
        );
      }
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

/// Working sets per muscle group per **calendar** week (Mon–Sun), last [weeks]
/// ISO weeks ending in the current week.
@riverpod
Future<Map<String, List<WeeklyMuscleWorkingSetPoint>>> weeklyVolumeTrend(
  Ref ref, {
  int weeks = 8,
}) async {
  final execRepo = ref.watch(workoutExecutionRepositoryProvider);
  final exercises = await ref.watch(exerciseListProvider.future);
  final exerciseMap = {for (final e in exercises) e.id: e};

  final allExecsResult = await execRepo.getAll();
  if (!allExecsResult.isSuccess) return {};
  final allExecs = allExecsResult.getOrThrow();

  final now = DateTime.now();
  final orderedWeekStarts = weekStartsEndingCurrent(now, weeks);
  final anchorMonday = orderedWeekStarts.first;

  // { muscleGroup: { weekIndex: workingSetCount } }
  final data = <String, Map<int, int>>{};

  for (final exec in allExecs) {
    if (exec.finishedAt == null) continue;
    final weekIdx = calendarWeekBucketIndex(exec.startedAt, anchorMonday);
    if (weekIdx < 0 || weekIdx >= weeks) continue;

    final setsResult = await execRepo.getSets(exec.id);
    if (!setsResult.isSuccess) continue;
    for (final s in setsResult.getOrThrow()) {
      if (!s.isCompleted) continue;
      if (s.isWarmup) continue;
      final exercise = exerciseMap[s.exerciseId];
      if (exercise == null) continue;
      final key = exercise.muscleGroup.name;
      data.putIfAbsent(key, () => {});
      data[key]![weekIdx] = (data[key]![weekIdx] ?? 0) + 1;
    }
  }

  final result = <String, List<WeeklyMuscleWorkingSetPoint>>{};
  for (final entry in data.entries) {
    final points = <WeeklyMuscleWorkingSetPoint>[
      for (var i = 0; i < weeks; i++)
        (
          weekStartMonday: orderedWeekStarts[i],
          workingSetCount: entry.value[i] ?? 0,
        ),
    ];
    result[entry.key] = points;
  }
  return result;
}
