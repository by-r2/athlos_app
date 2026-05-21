import '../entities/exercise.dart';
import '../entities/execution_set.dart';
import '../entities/workout_exercise.dart';
import '../enums/load_mode.dart';

/// Resolves the effective [LoadMode] for a set using the cascade:
/// `set.loadModeOverride` → [activeSetLoadModeOverride] (in-memory UI) →
/// `workoutExercise.loadModeOverride` → `exercise.defaultLoadMode`.
///
/// Any of the inputs may be null (e.g. for legacy data without an
/// associated [WorkoutExercise], or for ad-hoc analysis where only the
/// catalog default matters).
LoadMode resolveLoadMode({
  ExecutionSet? set,
  LoadMode? activeSetLoadModeOverride,
  WorkoutExercise? workoutExercise,
  required Exercise exercise,
}) {
  return set?.loadModeOverride ??
      activeSetLoadModeOverride ??
      workoutExercise?.loadModeOverride ??
      exercise.defaultLoadMode;
}

/// Calculates the effective load (in kg) of a set under a given [LoadMode].
///
/// - `LoadMode.weighted` → returns `setWeight` as-is (may be null).
/// - `LoadMode.bodyweight` → `(bodyWeight × loadFactor) + addedWeight`.
/// - `LoadMode.assisted` → `(bodyWeight × loadFactor) − assistedWeight`,
///   clamped to a non-negative value (assistance greater than the
///   bodyweight contribution still yields zero, never negative load).
///
/// `addedWeight` and `bodyWeight` default to 0 when null. `loadFactor`
/// defaults to 1.0 when null (treats the exercise as carrying full body
/// weight if the catalog hasn't been populated yet).
double? effectiveLoad({
  required LoadMode mode,
  double? setWeight,
  double? bodyWeight,
  double? loadFactor,
}) {
  switch (mode) {
    case LoadMode.weighted:
      return setWeight;
    case LoadMode.bodyweight:
      final body = (bodyWeight ?? 0) * (loadFactor ?? 1.0);
      final added = setWeight ?? 0;
      return body + added;
    case LoadMode.assisted:
      final body = (bodyWeight ?? 0) * (loadFactor ?? 1.0);
      final assistance = setWeight ?? 0;
      final net = body - assistance;
      return net < 0 ? 0 : net;
  }
}

/// Estimates 1-rep max using the Epley formula:
/// `1RM = weight × (1 + reps / 30)`
///
/// Returns null if weight is null/zero or reps <= 0.
double? estimated1RM({required double? weight, required int? reps}) {
  if (weight == null || weight <= 0 || reps == null || reps <= 0) {
    return null;
  }
  if (reps == 1) return weight;
  return weight * (1 + reps / 30);
}

/// Whether [set] should use per-arm volume (`left × loadL + right × loadR`).
///
/// Explicit bilateral (`isUnilateral == false`) stays on the legacy single-line
/// path so stray side fields cannot skew machines / barbell rows.
bool _recordsPerSideVolume(ExecutionSet set) {
  if (set.isUnilateral == false) return false;
  if (set.isUnilateral == true) return true;
  final left = set.leftReps ?? 0;
  final right = set.rightReps ?? 0;
  return left > 0 || right > 0;
}

/// Discrete load×reps pairs to evaluate Epley 1RM (including each drop tier).
///
/// For unilateral flat sets (no segments), yields left and right arms when
/// applicable. Callers should only pass completed, non-warmup sets.
Iterable<({double loadKg, int reps})> strengthEffortsForEstimated1Rm(
  ExecutionSet set, {
  required Exercise exercise,
  WorkoutExercise? workoutExercise,
  required double resolvedBodyWeight,
}) sync* {
  if (!set.isCompleted || set.isWarmup) return;

  final mode = resolveLoadMode(
    set: set,
    workoutExercise: workoutExercise,
    exercise: exercise,
  );
  final loadFactor = exercise.bodyweightLoadFactor;

  bool yieldsMeaningful(double loadKg, int reps) {
    if (reps <= 0) return false;
    if (mode == LoadMode.weighted && loadKg <= 0) return false;
    return estimated1RM(weight: loadKg, reps: reps) != null;
  }

  if (set.segments.isNotEmpty) {
    for (final seg in set.segments) {
      final loadKg = _effectiveLoadOrZero(
        mode: mode,
        setWeight: seg.weight,
        resolvedBodyWeight: resolvedBodyWeight,
        loadFactor: loadFactor,
      );
      if (yieldsMeaningful(loadKg, seg.reps)) {
        yield (loadKg: loadKg, reps: seg.reps);
      }
    }
    return;
  }

  if (_recordsPerSideVolume(set)) {
    final loadL = _effectiveLoadOrZero(
      mode: mode,
      setWeight: set.leftWeight ?? set.weight,
      resolvedBodyWeight: resolvedBodyWeight,
      loadFactor: loadFactor,
    );
    final loadR = _effectiveLoadOrZero(
      mode: mode,
      setWeight: set.rightWeight ?? set.leftWeight ?? set.weight,
      resolvedBodyWeight: resolvedBodyWeight,
      loadFactor: loadFactor,
    );
    final leftReps = set.leftReps ?? set.reps ?? 0;
    final rightReps = set.rightReps ?? 0;
    if (yieldsMeaningful(loadL, leftReps)) {
      yield (loadKg: loadL, reps: leftReps);
    }
    if (yieldsMeaningful(loadR, rightReps)) {
      yield (loadKg: loadR, reps: rightReps);
    }
    return;
  }

  final loadKg = _effectiveLoadOrZero(
    mode: mode,
    setWeight: set.weight,
    resolvedBodyWeight: resolvedBodyWeight,
    loadFactor: loadFactor,
  );
  final reps = set.reps ?? 0;
  if (yieldsMeaningful(loadKg, reps)) {
    yield (loadKg: loadKg, reps: reps);
  }
}

double _effectiveLoadOrZero({
  required LoadMode mode,
  required double? setWeight,
  required double resolvedBodyWeight,
  required double? loadFactor,
}) =>
    effectiveLoad(
      mode: mode,
      setWeight: setWeight,
      bodyWeight: resolvedBodyWeight,
      loadFactor: loadFactor,
    ) ??
    0;

/// Computes the volume contribution of a single execution [set] in `kg × reps`.
///
/// Rules:
/// - Returns 0 when the set is not completed.
/// - Returns 0 for warmup sets (warmups don't count toward volume).
/// - Unilateral recording (`isUnilateral` or legacy per-side reps): totals
///   `leftReps × effectiveLoad(left)` + `rightReps × effectiveLoad(right)`.
///   With drop-set segments stored per arm, mirrors that arm's tonnage onto
///   the other side proportional to reps when only one arm's ladder is persisted.
/// - Sums every drop-set segment when present (`segment.reps × segment.weight`).
/// - Otherwise: `set.reps × set.weight`.
///
/// When [exercise] is provided, the per-segment / per-set weight is replaced
/// by the [effectiveLoad] for the resolved [LoadMode]. This is what makes
/// bodyweight exercises contribute their actual carried mass to volume.
/// When [exercise] is `null`, the helper falls back to the legacy
/// "weight as-is" semantics, useful for low-level callers that don't have
/// the catalog entry handy.
double computeSetVolume(
  ExecutionSet set, {
  Exercise? exercise,
  WorkoutExercise? workoutExercise,
  double? profileBodyWeightOnExecutionDate,
  double? latestBodyWeight,
}) {
  if (!set.isCompleted) return 0;
  if (set.isWarmup) return 0;

  final mode = exercise == null
      ? LoadMode.weighted
      : resolveLoadMode(
          set: set,
          workoutExercise: workoutExercise,
          exercise: exercise,
        );
  final loadFactor = exercise?.bodyweightLoadFactor;
  final resolvedBodyWeight =
      set.bodyWeightSnapshot ??
      profileBodyWeightOnExecutionDate ??
      latestBodyWeight ??
      0;

  if (_recordsPerSideVolume(set)) {
    final leftReps = set.leftReps ?? set.reps ?? 0;
    final rightReps = set.rightReps ?? 0;

    if (set.segments.isNotEmpty) {
      var armVol = 0.0;
      for (final seg in set.segments) {
        final load = _effectiveLoadOrZero(
          mode: mode,
          setWeight: seg.weight,
          resolvedBodyWeight: resolvedBodyWeight,
          loadFactor: loadFactor,
        );
        armVol += seg.reps * load;
      }
      if (rightReps <= 0) return armVol;
      final leftTotalReps = set.segments.fold<int>(0, (a, s) => a + s.reps);
      if (leftTotalReps <= 0) return armVol;
      return armVol + armVol * (rightReps / leftTotalReps);
    }

    final loadL = _effectiveLoadOrZero(
      mode: mode,
      setWeight: set.leftWeight ?? set.weight,
      resolvedBodyWeight: resolvedBodyWeight,
      loadFactor: loadFactor,
    );
    final loadR = _effectiveLoadOrZero(
      mode: mode,
      setWeight: set.rightWeight ?? set.leftWeight ?? set.weight,
      resolvedBodyWeight: resolvedBodyWeight,
      loadFactor: loadFactor,
    );
    return leftReps * loadL + rightReps * loadR;
  }

  if (set.segments.isNotEmpty) {
    var total = 0.0;
    for (final seg in set.segments) {
      final load = _effectiveLoadOrZero(
        mode: mode,
        setWeight: seg.weight,
        resolvedBodyWeight: resolvedBodyWeight,
        loadFactor: loadFactor,
      );
      total += seg.reps * load;
    }
    return total;
  }

  final load =
      effectiveLoad(
        mode: mode,
        setWeight: set.weight,
        bodyWeight: resolvedBodyWeight,
        loadFactor: loadFactor,
      ) ??
      0;
  return (set.reps ?? 0) * load;
}

/// Sums the volume contribution of every set in [sets] using
/// [computeSetVolume] semantics (warmups and incomplete sets are excluded;
/// drop-set segments are summed when present).
///
/// [exerciseById] should map `ExecutionSet.exerciseId` → catalog [Exercise]
/// so the helper can resolve the per-set [LoadMode] and apply the
/// bodyweight load factor. When omitted, the function falls back to legacy
/// "weight as-is" semantics for every set.
double computeTotalVolume(
  Iterable<ExecutionSet> sets, {
  Map<String, Exercise>? exerciseById,
  Map<String, WorkoutExercise>? workoutExerciseByExerciseId,
  double? profileBodyWeightOnExecutionDate,
  double? latestBodyWeight,
}) {
  var total = 0.0;
  for (final s in sets) {
    final exercise = exerciseById?[s.exerciseId];
    final workoutExercise = workoutExerciseByExerciseId?[s.exerciseId];
    total += computeSetVolume(
      s,
      exercise: exercise,
      workoutExercise: workoutExercise,
      profileBodyWeightOnExecutionDate: profileBodyWeightOnExecutionDate,
      latestBodyWeight: latestBodyWeight,
    );
  }
  return total;
}
