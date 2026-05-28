import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/workout.dart';
import '../providers/program_notifier.dart';
import '../providers/training_analytics_provider.dart';

/// FAB to start the next workout in the program cycle, or guide setup.
class StartNextWorkoutFab extends ConsumerWidget {
  final Workout? nextWorkout;

  const StartNextWorkoutFab({this.nextWorkout, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final hasActiveProgram = ref.watch(activeProgramProvider).value != null;

    if (!hasActiveProgram) {
      return FloatingActionButton(
        heroTag: 'training_shell_start_fab',
        onPressed: () => context.push(RoutePaths.trainingProgramNew),
        tooltip: l10n.noProgramActiveCreateAction,
        child: const Icon(Icons.add),
      );
    }

    final hasCycleSteps =
        (ref.watch(effectiveCycleStepsProvider).value ?? const []).isNotEmpty;

    if (nextWorkout == null) {
      if (hasCycleSteps) {
        return const SizedBox.shrink();
      }
      return FloatingActionButton(
        heroTag: 'training_shell_start_fab',
        onPressed: () {
          context.go(RoutePaths.trainingWorkoutsOpenCyclePickerQuery());
        },
        tooltip: l10n.trainingCycleAddWorkout,
        child: const Icon(Icons.add),
      );
    }

    return FloatingActionButton(
      heroTag: 'training_shell_start_fab',
      onPressed: () => context.push(
        '${RoutePaths.trainingWorkouts}/${nextWorkout!.id}/execute',
      ),
      tooltip: nextWorkout!.name,
      child: const Icon(Icons.play_arrow),
    );
  }
}
