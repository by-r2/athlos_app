import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chiron/presentation/widgets/chiron_bottom_sheet.dart';
import '../providers/training_analytics_provider.dart';
import '../providers/workout_notifier.dart';
import '../screens/training_exercises_screen.dart';
import 'expandable_workout_fab.dart';
import 'start_next_workout_fab.dart';

/// FAB for the training module shell, painted above the floating bottom nav.
Widget? buildTrainingShellFloatingActionButton(
  BuildContext context,
  WidgetRef ref,
  String path,
) {
  final l10n = AppLocalizations.of(context)!;

  switch (path) {
    case RoutePaths.trainingHome:
    case RoutePaths.trainingWorkouts:
      final nextWorkout = ref.watch(nextWorkoutToStartProvider).value;
      return StartNextWorkoutFab(nextWorkout: nextWorkout);
    case RoutePaths.trainingWorkoutCatalog:
      final workoutCount = ref.watch(workoutListProvider).value?.length ?? 0;
      return ExpandableWorkoutFab(
        chironLabel: workoutCount == 0
            ? l10n.chironCreateWorkoutShortcut
            : l10n.chironAnalyzeWorkoutsShortcut,
        createManualLabel: l10n.trainingWorkoutActionCreateManual,
        onChiron: () => showChironSheet(
          context,
          initialMessage: workoutCount == 0
              ? l10n.chironAskToCreateWorkout
              : l10n.chironAnalyzeWorkoutsMessage,
        ),
        onCreateManual: () => context.push(RoutePaths.trainingWorkoutNew),
      );
    case RoutePaths.trainingExercises:
      return FloatingActionButton(
        onPressed: () => showTrainingExerciseAddSheet(context),
        tooltip: l10n.addExercise,
        heroTag: 'training_exercises_fab',
        child: const Icon(Icons.add),
      );
    case RoutePaths.trainingPrograms:
      return FloatingActionButton(
        heroTag: 'programs_fab',
        onPressed: () => context.push(RoutePaths.trainingProgramNew),
        tooltip: l10n.programCreateTitle,
        child: const Icon(Icons.add),
      );
    default:
      return null;
  }
}
