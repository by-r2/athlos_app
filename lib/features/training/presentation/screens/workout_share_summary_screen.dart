import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../core/theme/athlos_spacing.dart';
import '../../../../core/widgets/layout/athlos_scaffold.dart';
import '../../../../core/widgets/layout/athlos_stacked_actions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../profile/presentation/providers/body_metric_notifier.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/entities/execution_set.dart';
import '../../domain/entities/workout_exercise.dart';
import '../../domain/entities/workout_execution.dart';
import '../helpers/workout_share_image.dart';
import '../providers/exercise_notifier.dart';
import '../providers/execution_session_context.dart';
import '../providers/workout_execution_notifier.dart';
import '../widgets/workout_execution_share_summary.dart';

class WorkoutShareSummaryScreen extends ConsumerStatefulWidget {
  final String executionId;

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
      id: 'placeholder-$i',
      executionId: '',
      exerciseId: '',
      setNumber: i + 1,
      plannedReps: 10,
      reps: 10,
      weight: 40,
      isCompleted: true,
    ),
  );

  static final _placeholderExecution = WorkoutExecution(
    id: '',
    workoutId: '',
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
      return AthlosScaffold(
        appBar: AppBar(title: Text(l10n.workoutShareSummaryTitle)),
        body: Center(child: Text(l10n.genericError)),
      );
    }

    if (!executionsAsync.isLoading && execution == null) {
      return AthlosScaffold(
        appBar: AppBar(title: Text(l10n.workoutShareSummaryTitle)),
        body: Center(child: Text(l10n.genericError)),
      );
    }

    final sessionContextAsync = execution != null
        ? ref.watch(executionSessionContextProvider(execution))
        : null;
    final sessionContext = sessionContextAsync?.value;
    final workoutTitle = sessionContext?.resolveWorkoutName(l10n) ??
        l10n.unknownWorkout;

    final exerciseById = <String, Exercise>{
      for (final e in ref.watch(exerciseListProvider).value ?? const <Exercise>[])
        e.id: e,
    };
    final setsForIds = setsAsync.value ?? _placeholderSets;
    if (sessionContext != null) {
      for (final exId in setsForIds.map((s) => s.exerciseId).toSet()) {
        final resolved = sessionContext.catalogExerciseFor(exId);
        if (resolved != null) exerciseById[exId] = resolved;
      }
    }

    final workoutExerciseByExerciseId = <String, WorkoutExercise>{};
    if (sessionContext != null) {
      for (final exId in setsForIds.map((s) => s.exerciseId).toSet()) {
        final we = sessionContext.workoutExerciseFor(exId);
        if (we != null) workoutExerciseByExerciseId[exId] = we;
      }
    }

    final historicProfileWeight = execution != null
        ? ref.watch(profileBodyWeightAtProvider(execution.startedAt)).value
        : null;
    final latestBw = ref.watch(latestBodyWeightProvider).value;

    final exec = execution ?? _placeholderExecution;
    final sets = setsAsync.value ?? _placeholderSets;
    final isLoading = executionsAsync.isLoading || setsAsync.isLoading;

    return AthlosScaffold(
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
                      exerciseById: exerciseById.isEmpty ? null : exerciseById,
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
