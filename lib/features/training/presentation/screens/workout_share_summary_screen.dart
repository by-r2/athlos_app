import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../core/theme/athlos_spacing.dart';
import '../../../../core/widgets/layout/athlos_stacked_actions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../profile/presentation/providers/body_metric_notifier.dart';
import '../../domain/entities/execution_set.dart';
import '../../domain/entities/workout_exercise.dart';
import '../../domain/entities/workout_execution.dart';
import '../helpers/workout_share_image.dart';
import '../providers/exercise_notifier.dart';
import '../providers/workout_execution_notifier.dart';
import '../providers/workout_notifier.dart';
import '../widgets/workout_execution_share_summary.dart';

class WorkoutShareSummaryScreen extends ConsumerStatefulWidget {
  final int executionId;

  const WorkoutShareSummaryScreen({super.key, required this.executionId});

  @override
  ConsumerState<WorkoutShareSummaryScreen> createState() =>
      _WorkoutShareSummaryScreenState();
}

class _WorkoutShareSummaryScreenState
    extends ConsumerState<WorkoutShareSummaryScreen> {
  final GlobalKey _captureKey = GlobalKey();

  static final _placeholderSets = List.generate(
    3,
    (i) => ExecutionSet(
      id: i,
      executionId: 0,
      exerciseId: 0,
      setNumber: i + 1,
      plannedReps: 10,
      reps: 10,
      weight: 40,
      isCompleted: true,
    ),
  );

  static final _placeholderExecution = WorkoutExecution(
    id: 0,
    workoutId: 0,
    programId: 0,
    startedAt: DateTime(2025, 1, 15, 10, 30),
  );

  Future<void> _onShare(String workoutTitle) async {
    final l10n = AppLocalizations.of(context)!;
    await shareRepaintBoundaryAsPng(
      context: context,
      boundaryKey: _captureKey,
      shareText: l10n.workoutShareSummaryShareText(workoutTitle),
      fileName: 'athlos_workout_${widget.executionId}.png',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final executionsAsync = ref.watch(workoutExecutionListProvider);
    final setsAsync = ref.watch(
      executionSetsWithSegmentsProvider(widget.executionId),
    );

    WorkoutExecution? execution;
    for (final e in executionsAsync.value ?? const <WorkoutExecution>[]) {
      if (e.id == widget.executionId) {
        execution = e;
        break;
      }
    }

    if (executionsAsync.hasError || setsAsync.hasError) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.workoutShareSummaryTitle)),
        body: Center(child: Text(l10n.genericError)),
      );
    }

    if (!executionsAsync.isLoading && execution == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.workoutShareSummaryTitle)),
        body: Center(child: Text(l10n.genericError)),
      );
    }

    final workoutTitle = execution != null
        ? ref.watch(workoutByIdProvider(execution.workoutId)).value?.name ??
              l10n.unknownWorkout
        : l10n.unknownWorkout;

    final exercisesAsync = ref.watch(exerciseListProvider);
    final exerciseById =
        exercisesAsync.hasValue && (exercisesAsync.value?.isNotEmpty ?? false)
        ? {for (final e in exercisesAsync.value!) e.id: e}
        : null;

    final exerciseConfigAsync = execution != null
        ? ref.watch(executionExerciseConfigProvider(execution))
        : null;
    final workoutExerciseByExerciseId = <int, WorkoutExercise>{};
    if (exerciseConfigAsync?.value case final List<WorkoutExercise> wes) {
      for (final we in wes) {
        workoutExerciseByExerciseId[we.exerciseId] = we;
      }
    }

    final historicProfileWeight = execution != null
        ? ref.watch(profileBodyWeightAtProvider(execution.startedAt)).value
        : null;
    final latestBw = ref.watch(latestBodyWeightProvider).value;

    final exec = execution ?? _placeholderExecution;
    final sets = setsAsync.value ?? _placeholderSets;
    final isLoading = executionsAsync.isLoading || setsAsync.isLoading;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.workoutShareSummaryTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AthlosSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Skeletonizer(
                    enabled: isLoading,
                    child: WorkoutExecutionShareSummary(
                      captureKey: _captureKey,
                      execution: exec,
                      sets: sets,
                      workoutName: workoutTitle,
                      exerciseById: exerciseById,
                      workoutExerciseByExerciseId:
                          workoutExerciseByExerciseId.isEmpty
                          ? null
                          : workoutExerciseByExerciseId,
                      profileBodyWeightOnExecutionDate: historicProfileWeight,
                      latestBodyWeight: latestBw,
                    ),
                  ),
                ),
              ),
              const Gap(AthlosSpacing.md),
              AthlosStackedActions(
                spacing: AthlosSpacing.sm,
                children: [
                  OutlinedButton(
                    onPressed: isLoading ? null : () => context.pop(),
                    child: Text(l10n.workoutShareSummaryClose),
                  ),
                  FilledButton(
                    onPressed: isLoading ? null : () => _onShare(workoutTitle),
                    child: Text(l10n.workoutShareSummaryShareAction),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
