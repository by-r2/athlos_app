import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/errors/result.dart';
import '../../../profile/data/repositories/profile_providers.dart';
import '../../../profile/domain/repositories/user_profile_repository.dart';
import '../../../profile/presentation/providers/profile_notifier.dart';
import '../../data/repositories/training_providers.dart';
import '../../domain/helpers/training_frequency_streak_calculator.dart';
import '../../domain/repositories/workout_execution_repository.dart';
import 'training_metrics_provider.dart';

part 'recalculate_training_streaks.g.dart';

/// Recomputes persisted weekly frequency streaks from finished workout history.
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

    final profileResult = await profileRepo.get();
    final loaded = profileResult.getOrThrow();
    if (loaded == null) return;

    final execsNewestFirst = (await execRepo.getAll()).getOrThrow();
    final chronological = execsNewestFirst.reversed.toList();

    final target = loaded.trainingFrequency ?? kDefaultTrainingFrequency;
    final freqTotals = computeFrequencyStreaks(chronological, target);

    final updated = loaded.copyWith(
      currentFrequencyStreak: freqTotals.current,
      bestFrequencyStreak: freqTotals.best,
      trainingStreaksSchema: kTrainingStreaksSchemaVersion,
    );
    (await profileRepo.update(updated)).getOrThrow();
  }
}

/// Ensures legacy installs get frequency streak columns filled once (schema 0 in DB).
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
