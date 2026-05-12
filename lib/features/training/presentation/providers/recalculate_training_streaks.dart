import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/errors/result.dart';
import '../../../profile/data/repositories/profile_providers.dart';
import '../../../profile/domain/repositories/user_profile_repository.dart';
import '../../../profile/presentation/providers/profile_notifier.dart';
import '../../data/repositories/training_providers.dart';
import '../../domain/helpers/training_streak_calculator.dart';
import '../../domain/repositories/cycle_repository.dart';
import '../../domain/repositories/workout_execution_repository.dart';
import 'training_metrics_provider.dart';

part 'recalculate_training_streaks.g.dart';

/// Recomputes persisted streaks from finished workout history and saves to profile.
@Riverpod(keepAlive: true)
class RecalculateTrainingStreaks extends _$RecalculateTrainingStreaks {
  @override
  void build() {}

  Future<void> run() async {
    final UserProfileRepository profileRepo = ref.read(
      userProfileRepositoryProvider,
    );
    final WorkoutExecutionRepository execRepo = ref.read(
      workoutExecutionRepositoryProvider,
    );
    final CycleRepository cycleRepo = ref.read(cycleRepositoryProvider);

    final profileResult = await profileRepo.get();
    final loaded = profileResult.getOrThrow();
    if (loaded == null) return;

    final execsNewestFirst = (await execRepo.getAll()).getOrThrow();
    final chronological = execsNewestFirst.reversed.toList();

    final target = loaded.trainingFrequency ?? kDefaultTrainingFrequency;

    final programIds = chronological.map((e) => e.programId).toSet();
    final cycleByProgram = <int, List<int>>{};
    for (final pid in programIds) {
      final steps = (await cycleRepo.getSteps(pid)).getOrThrow();
      cycleByProgram[pid] = [for (final s in steps) s.workoutId];
    }

    final cycleTotals = computeCycleStreaks(chronological, cycleByProgram);
    final freqTotals = computeFrequencyStreaks(chronological, target);

    final updated = loaded.copyWith(
      currentCycleStreak: cycleTotals.current,
      bestCycleStreak: cycleTotals.best,
      currentFrequencyStreak: freqTotals.current,
      bestFrequencyStreak: freqTotals.best,
      trainingStreaksSchema: kTrainingStreaksSchemaVersion,
    );
    (await profileRepo.update(updated)).getOrThrow();
  }
}

/// Ensures legacy installs get streak columns filled once (schema 0 in DB).
@Riverpod(keepAlive: true)
Future<void> trainingStreaksMaterialized(Ref ref) async {
  final profile = await ref.watch(profileProvider.future);
  if (profile == null) return;
  if (profile.trainingStreaksSchema >= kTrainingStreaksSchemaVersion) {
    return;
  }

  await ref.read(recalculateTrainingStreaksProvider.notifier).run();
  ref.invalidate(profileProvider);
}
