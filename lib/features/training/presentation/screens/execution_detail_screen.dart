import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../core/theme/athlos_custom_colors.dart';
import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../core/widgets/feedback/athlos_truncated_text.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/entities/execution_set.dart';
import '../../domain/entities/workout_exercise.dart';
import '../../domain/entities/workout_execution.dart';
import '../../domain/helpers/training_metrics.dart';
import '../../../profile/presentation/providers/body_metric_notifier.dart';
import '../helpers/duration_format.dart';
import '../helpers/exercise_l10n.dart';
import '../helpers/rep_performance.dart';
import '../helpers/workout_share_image.dart';
import '../providers/exercise_notifier.dart';
import '../providers/training_metrics_provider.dart';
import '../providers/workout_execution_notifier.dart';
import '../providers/workout_notifier.dart';
import '../widgets/workout_execution_share_summary.dart';

final _placeholderExecution = WorkoutExecution(
  id: 0,
  workoutId: 0,
  programId: 0,
  startedAt: DateTime(0),
);

final _placeholderSets = List.generate(
  4,
  (i) => ExecutionSet(
    id: i,
    executionId: 0,
    exerciseId: 0,
    setNumber: i + 1,
    plannedReps: 10,
    reps: 10,
    weight: 20,
    isCompleted: true,
  ),
);

class ExecutionDetailScreen extends ConsumerStatefulWidget {
  final int executionId;

  const ExecutionDetailScreen({super.key, required this.executionId});

  @override
  ConsumerState<ExecutionDetailScreen> createState() =>
      _ExecutionDetailScreenState();
}

class _ExecutionDetailScreenState extends ConsumerState<ExecutionDetailScreen> {
  final GlobalKey _shareCaptureKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final executionId = widget.executionId;
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final executionsAsync = ref.watch(workoutExecutionListProvider);
    final setsAsync = ref.watch(executionSetsWithSegmentsProvider(executionId));
    final exercisesAsync = ref.watch(exerciseListProvider);

    final executions = executionsAsync.value;
    final execution =
        executions?.where((e) => e.id == executionId).firstOrNull;

    if (executionsAsync.hasError) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.tabHistory)),
        body: Center(child: Text(l10n.genericError)),
      );
    }

    if (!executionsAsync.isLoading && execution == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.tabHistory)),
        body: Center(child: Text(l10n.genericError)),
      );
    }

    final workoutAsync = execution != null
        ? ref.watch(workoutByIdProvider(execution.workoutId))
        : null;
    final workoutName =
        workoutAsync?.value?.name ?? l10n.unknownWorkout;

    final exerciseConfigAsync = execution != null
        ? ref.watch(executionExerciseConfigProvider(execution))
        : null;
    final unilateralMap = <int, bool>{};
    final workoutExerciseByExerciseId = <int, WorkoutExercise>{};
    if (exerciseConfigAsync?.value case final List<WorkoutExercise> wes) {
      for (final we in wes) {
        unilateralMap[we.exerciseId] = we.isUnilateral;
        workoutExerciseByExerciseId[we.exerciseId] = we;
      }
    }

    if (setsAsync.hasError) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.tabHistory)),
        body: Center(child: Text(l10n.genericError)),
      );
    }

    final sets = setsAsync.value ?? _placeholderSets;

    final prSetIdsPerExercise = <int, Set<int>>{};
    final allExercises = exercisesAsync.value ?? <Exercise>[];
    final exerciseMapLocal = {for (final e in allExercises) e.id: e};
    final profileWeight =
        ref.watch(latestBodyWeightProvider).value;
    final historicProfileWeight = execution != null
        ? ref
            .watch(profileBodyWeightAtProvider(execution.startedAt))
            .value
        : null;
    for (final exId in sets.map((s) => s.exerciseId).toSet()) {
      final pr = ref.watch(exercisePRProvider(exId)).value;
      if (pr == null) continue;
      final ex = exerciseMapLocal[exId];
      if (ex == null) continue;
      for (final s in sets.where((s) => s.exerciseId == exId)) {
        if (!s.isCompleted) continue;
        if (s.isWarmup) continue;
        final load = effectiveLoad(
          mode: resolveLoadMode(
            set: s,
            workoutExercise: workoutExerciseByExerciseId[s.exerciseId],
            exercise: ex,
          ),
          setWeight: s.weight,
          bodyWeight: s.bodyWeightSnapshot ??
              historicProfileWeight ??
              profileWeight,
          loadFactor: ex.bodyweightLoadFactor,
        );
        final e1rm = estimated1RM(weight: load, reps: s.reps);
        if (e1rm != null && e1rm >= pr.best1RM) {
          prSetIdsPerExercise
              .putIfAbsent(exId, () => {})
              .add(s.id);
        }
      }
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.tabHistory),
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(
              AthlosSpacing.sm + 24 + AthlosSpacing.xs + kTextTabBarHeight,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AthlosSpacing.md,
                    AthlosSpacing.xs,
                    AthlosSpacing.md,
                    AthlosSpacing.xs,
                  ),
                  child: AthlosTruncatedText(
                    workoutName,
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                  ),
                ),
                TabBar(
                  tabs: [
                    Tab(text: l10n.executionDetailTabSummary),
                    Tab(text: l10n.executionDetailTabDetails),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: Skeletonizer(
          enabled: setsAsync.isLoading,
          child: TabBarView(
            children: [
              _ExecutionShareSummaryTab(
                captureKey: _shareCaptureKey,
                execution: execution ?? _placeholderExecution,
                sets: sets,
                workoutName: workoutName,
                exerciseById:
                    exercisesAsync.hasValue ? exerciseMapLocal : null,
                workoutExerciseByExerciseId:
                    workoutExerciseByExerciseId.isEmpty
                        ? null
                        : workoutExerciseByExerciseId,
                profileBodyWeightOnExecutionDate:
                    historicProfileWeight,
                latestBodyWeight: profileWeight,
              ),
              _ExecutionDetailBody(
                execution: execution ?? _placeholderExecution,
                sets: sets,
                exercisesAsync: exercisesAsync,
                unilateralMap: unilateralMap,
                workoutExerciseByExerciseId: workoutExerciseByExerciseId,
                profileBodyWeightOnExecutionDate:
                    historicProfileWeight,
                latestBodyWeight: profileWeight,
                prSetIdsPerExercise: prSetIdsPerExercise,
                colorScheme: colorScheme,
                textTheme: textTheme,
                l10n: l10n,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExecutionShareSummaryTab extends StatefulWidget {
  final GlobalKey captureKey;
  final WorkoutExecution execution;
  final List<ExecutionSet> sets;
  final String workoutName;
  final Map<int, Exercise>? exerciseById;
  final Map<int, WorkoutExercise>? workoutExerciseByExerciseId;
  final double? profileBodyWeightOnExecutionDate;
  final double? latestBodyWeight;

  const _ExecutionShareSummaryTab({
    required this.captureKey,
    required this.execution,
    required this.sets,
    required this.workoutName,
    this.exerciseById,
    this.workoutExerciseByExerciseId,
    this.profileBodyWeightOnExecutionDate,
    this.latestBodyWeight,
  });

  @override
  State<_ExecutionShareSummaryTab> createState() =>
      _ExecutionShareSummaryTabState();
}

class _ExecutionShareSummaryTabState extends State<_ExecutionShareSummaryTab> {
  Future<void> _onShare() async {
    await shareRepaintBoundaryAsPng(
      context: context,
      boundaryKey: widget.captureKey,
      shareText: AppLocalizations.of(context)!
          .workoutShareSummaryShareText(widget.workoutName),
      fileName: 'athlos_workout_${widget.execution.id}.png',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(AthlosSpacing.md),
      children: [
        WorkoutExecutionShareSummary(
          captureKey: widget.captureKey,
          execution: widget.execution,
          sets: widget.sets,
          workoutName: widget.workoutName,
          exerciseById: widget.exerciseById,
          workoutExerciseByExerciseId: widget.workoutExerciseByExerciseId,
          profileBodyWeightOnExecutionDate:
              widget.profileBodyWeightOnExecutionDate,
          latestBodyWeight: widget.latestBodyWeight,
        ),
        const Gap(AthlosSpacing.md),
        FilledButton(
          onPressed: _onShare,
          child: Text(l10n.workoutShareSummaryShareAction),
        ),
      ],
    );
  }
}

class _ExecutionDetailBody extends StatelessWidget {
  final WorkoutExecution execution;
  final List<ExecutionSet> sets;
  final AsyncValue<List<Exercise>> exercisesAsync;
  final Map<int, bool> unilateralMap;
  final Map<int, WorkoutExercise> workoutExerciseByExerciseId;
  final double? profileBodyWeightOnExecutionDate;
  final double? latestBodyWeight;
  final Map<int, Set<int>> prSetIdsPerExercise;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final AppLocalizations l10n;

  const _ExecutionDetailBody({
    required this.execution,
    required this.sets,
    required this.exercisesAsync,
    required this.unilateralMap,
    required this.workoutExerciseByExerciseId,
    this.profileBodyWeightOnExecutionDate,
    this.latestBodyWeight,
    this.prSetIdsPerExercise = const {},
    required this.colorScheme,
    required this.textTheme,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final allExercises = exercisesAsync.value ?? <Exercise>[];
    final exerciseMap = {for (final e in allExercises) e.id: e};
    final exerciseIds = sets.map((s) => s.exerciseId).toSet().toList();

    final totalVolume = computeTotalVolume(
      sets,
      exerciseById: exerciseMap.isEmpty ? null : exerciseMap,
      workoutExerciseByExerciseId:
          workoutExerciseByExerciseId.isEmpty
              ? null
              : workoutExerciseByExerciseId,
      profileBodyWeightOnExecutionDate:
          profileBodyWeightOnExecutionDate,
      latestBodyWeight: latestBodyWeight,
    );
    int totalCompletedSets = 0;
    int totalPlannedSets = sets.length;

    for (final s in sets) {
      if (s.isCompleted) totalCompletedSets++;
    }

    final locale = Localizations.localeOf(context).toString();
    final dateStr =
        DateFormat.yMMMd(locale).add_Hm().format(execution.startedAt);
    final durationStr =
        formatWorkoutTotalDuration(execution.duration, l10n);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AthlosSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today,
                        size: 16, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: AthlosSpacing.xs),
                    Text(dateStr,
                        style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant)),
                    if (durationStr != null) ...[
                      const SizedBox(width: AthlosSpacing.md),
                      Icon(Icons.timer_outlined,
                          size: 16,
                          color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: AthlosSpacing.xs),
                      Text(durationStr,
                          style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant)),
                    ],
                  ],
                ),
                const SizedBox(height: AthlosSpacing.md),

                // Summary cards
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        icon: Icons.check_circle_outline,
                        label: l10n.setsCompletedOf(
                            totalCompletedSets, totalPlannedSets),
                        color: colorScheme.primary,
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                      ),
                    ),
                    const SizedBox(width: AthlosSpacing.sm),
                    Expanded(
                      child: _SummaryCard(
                        icon: Icons.fitness_center,
                        label: l10n.volumeLabel(
                            totalVolume.toStringAsFixed(0)),
                        color: colorScheme.tertiary,
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AthlosSpacing.lg),
              ],
            ),
          ),
        ),

        // Per-exercise breakdown
        ...exerciseIds.map((exId) {
          final exerciseSets =
              sets.where((s) => s.exerciseId == exId).toList();
          final ex = exerciseMap[exId];
          final name = ex != null
              ? localizedExerciseName(ex.name,
                  isVerified: ex.isVerified, l10n: l10n)
              : l10n.unknownExerciseId(exId);
          final group = ex != null
              ? localizedMuscleGroupName(ex.muscleGroup, l10n)
              : '';

          final prSetIds = prSetIdsPerExercise[exId] ?? {};

          final wasUnilateral = exerciseSets
                  .any((s) => s.isUnilateral == true) ||
              (exerciseSets.every((s) => s.isUnilateral == null) &&
                  (unilateralMap[exId] ?? false));

          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AthlosSpacing.md),
              child: _ExerciseBreakdown(
                exerciseName: name,
                muscleGroup: group,
                isUnilateral: wasUnilateral,
                isIsometric: ex?.isIsometric ?? false,
                sets: exerciseSets,
                prSetIds: prSetIds,
                colorScheme: colorScheme,
                textTheme: textTheme,
                l10n: l10n,
              ),
            ),
          );
        }),

        const SliverPadding(
            padding: EdgeInsets.only(bottom: AthlosSpacing.xl)),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AthlosSpacing.sm),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: AthlosRadius.mdAll,
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: AthlosSpacing.xs),
          Expanded(
            child: AthlosTruncatedText(
              label,
              style: textTheme.labelMedium?.copyWith(color: color),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseBreakdown extends StatelessWidget {
  final String exerciseName;
  final String muscleGroup;
  final bool isUnilateral;
  final bool isIsometric;
  final List<ExecutionSet> sets;
  final Set<int> prSetIds;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final AppLocalizations l10n;

  const _ExerciseBreakdown({
    required this.exerciseName,
    required this.muscleGroup,
    this.isUnilateral = false,
    this.isIsometric = false,
    required this.sets,
    this.prSetIds = const {},
    required this.colorScheme,
    required this.textTheme,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AthlosSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AthlosSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(exerciseName, style: textTheme.titleSmall),
            if (muscleGroup.isNotEmpty || isUnilateral)
              Row(
                children: [
                  if (muscleGroup.isNotEmpty)
                    Flexible(
                      child: Text(muscleGroup,
                          style: textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant)),
                    ),
                  if (isUnilateral) ...[
                    if (muscleGroup.isNotEmpty)
                      const SizedBox(width: AthlosSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AthlosSpacing.xs,
                        vertical: AthlosSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer
                            .withValues(alpha: 0.5),
                        borderRadius: AthlosRadius.fullAll,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.swap_horiz,
                              size: 10,
                              color: colorScheme.onSecondaryContainer),
                          const SizedBox(width: 2),
                          Text(
                            l10n.unilateralLabel,
                            style: textTheme.labelSmall?.copyWith(
                              fontSize: 9,
                              color: colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            const SizedBox(height: AthlosSpacing.sm),

            // Header
            Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: AthlosSpacing.xs),
              child: Row(
                children: [
                  SizedBox(
                      width: 40,
                      child: Text(l10n.setsLabel,
                          style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant))),
                  if (_isCardio) ...[
                    Expanded(
                        child: Text(l10n.durationLabel,
                            style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant))),
                    SizedBox(
                        width: 80,
                        child: Text(l10n.distanceLabel,
                            style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant))),
                  ] else if (isIsometric) ...[
                    Expanded(
                        child: Text(l10n.durationLabel,
                            style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant))),
                    SizedBox(
                        width: 60,
                        child: Text(l10n.weightColumnLabel,
                            style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant))),
                  ] else ...[
                    Expanded(
                        child: Text(l10n.repsLabel,
                            style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant))),
                    SizedBox(
                        width: 60,
                        child: Text(l10n.weightColumnLabel,
                            style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant))),
                  ],
                  const SizedBox(width: AthlosSpacing.lg),
                ],
              ),
            ),

            ...sets.map((s) => _SetRow(
                  setEntry: s,
                  isCardio: _isCardio,
                  isIsometric: isIsometric,
                  isPR: prSetIds.contains(s.id),
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                  l10n: l10n,
                )),
            Builder(
              builder: (ctx) =>
                  _feedbackChip(ctx) ?? const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  bool get _usesDuration => sets.isNotEmpty && sets.first.reps == null;
  bool get _isCardio => _usesDuration && !isIsometric;

  Widget? _feedbackChip(BuildContext context) {
    if (_usesDuration) return null;

    final workingSets = sets.where((s) => s.isCompleted).toList();
    if (workingSets.isEmpty) return null;

    final plannedReps = workingSets.first.plannedReps ?? 0;
    final feedback = loadFeedback(
      cs: colorScheme,
      custom: Theme.of(context).extension<AthlosCustomColors>()!,
      l10n: l10n,
      completedReps: workingSets.map((s) => s.reps!).toList(),
      minReps: plannedReps,
      maxReps: plannedReps,
      isAmrap: false,
    );
    if (feedback == null) return null;

    return Padding(
      padding: const EdgeInsets.only(top: AthlosSpacing.sm),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 14, color: feedback.color),
          const SizedBox(width: AthlosSpacing.xs),
          Flexible(
            child: Text(
              feedback.message,
              style: textTheme.bodySmall?.copyWith(color: feedback.color),
            ),
          ),
        ],
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  final ExecutionSet setEntry;
  final bool isCardio;
  final bool isIsometric;
  final bool isPR;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final AppLocalizations l10n;

  const _SetRow({
    required this.setEntry,
    this.isCardio = false,
    this.isIsometric = false,
    this.isPR = false,
    required this.colorScheme,
    required this.textTheme,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    if (isIsometric) return _buildIsometricRow(context);
    if (isCardio) return _buildCardioRow(context);
    return _buildStrengthRow(context);
  }

  String _fmtWeight(double? w) {
    if (w == null) return '-';
    return w % 1 == 0
        ? '${w.toInt()}${l10n.weightUnit}'
        : '${w.toStringAsFixed(1)}${l10n.weightUnit}';
  }

  Widget _buildIsometricRow(BuildContext context) {
    final statusColor = setEntry.isCompleted
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;

    final durationStr = setEntry.duration != null
        ? formatDuration(setEntry.duration!)
        : '-';
    final weightStr = _fmtWeight(setEntry.weight);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AthlosSpacing.xs),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text('${setEntry.setNumber}', style: textTheme.bodyMedium),
          ),
          Expanded(
            child: Text(durationStr,
                style: textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600, color: statusColor)),
          ),
          SizedBox(
            width: 60,
            child: Text(weightStr, style: textTheme.bodyMedium),
          ),
          SizedBox(
            width: 24,
            child: Icon(
              setEntry.isCompleted
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              size: 18,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardioRow(BuildContext context) {
    final statusColor = setEntry.isCompleted
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;

    final durationStr = setEntry.duration != null
        ? formatDuration(setEntry.duration!)
        : '-';
    final distanceStr = setEntry.distance != null
        ? '${(setEntry.distance! / 1000).toStringAsFixed(2)}km'
        : '-';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AthlosSpacing.xs),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text('${setEntry.setNumber}', style: textTheme.bodyMedium),
          ),
          Expanded(
            child: Text(durationStr,
                style: textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ),
          SizedBox(
            width: 80,
            child: Text(distanceStr, style: textTheme.bodyMedium),
          ),
          SizedBox(
            width: 24,
            child: Icon(
              setEntry.isCompleted
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              size: 18,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrengthRow(BuildContext context) {
    final customColors = Theme.of(context).extension<AthlosCustomColors>()!;
    final planned = setEntry.plannedReps ?? 0;
    final statusColor = setEntry.isCompleted
        ? (repsDeviationColor(colorScheme, customColors, setEntry.reps ?? 0,
                planned, planned, false) ??
            colorScheme.primary)
        : colorScheme.onSurfaceVariant;
    final diff = (setEntry.reps ?? 0) - (setEntry.plannedReps ?? 0);

    final weightStr = setEntry.weight != null
        ? '${setEntry.weight!.toStringAsFixed(setEntry.weight! % 1 == 0 ? 0 : 1)}${l10n.weightUnit}'
        : '-';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AthlosSpacing.xs),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                child: Text(
                  '${setEntry.setNumber}',
                  style: textTheme.bodyMedium,
                ),
              ),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${setEntry.reps ?? 0}',
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                      TextSpan(
                        text: '/${setEntry.plannedReps ?? 0}',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 60,
                child: Text(weightStr, style: textTheme.bodyMedium),
              ),
              if (setEntry.rpe != null)
                Padding(
                  padding: const EdgeInsets.only(right: AthlosSpacing.xs),
                  child: Text(
                    'RPE ${setEntry.rpe}',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              SizedBox(
                width: 24,
                child: isPR
                    ? Icon(Icons.emoji_events,
                        size: 18, color: colorScheme.tertiary)
                    : Icon(
                        setEntry.isCompleted
                            ? (diff.abs() <= 1
                                ? Icons.check_circle
                                : Icons.warning)
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color: statusColor,
                      ),
              ),
            ],
          ),
        ),

        // Drop set segments
        if (setEntry.segments.length > 1)
          ...setEntry.segments.skip(1).map((seg) {
            final segWeightStr = seg.weight != null
                ? '${seg.weight!.toStringAsFixed(seg.weight! % 1 == 0 ? 0 : 1)}${l10n.weightUnit}'
                : '-';
            return Padding(
              padding: const EdgeInsets.only(
                  left: AthlosSpacing.lg,
                  top: AthlosSpacing.xs,
                  bottom: AthlosSpacing.xs),
              child: Row(
                children: [
                  Icon(Icons.arrow_downward,
                      size: 12, color: colorScheme.tertiary),
                  const SizedBox(width: AthlosSpacing.xs),
                  SizedBox(
                    width: 16,
                    child: Text('', style: textTheme.bodySmall),
                  ),
                  Expanded(
                    child: Text(
                      '${seg.reps}',
                      style: textTheme.bodySmall
                          ?.copyWith(color: colorScheme.tertiary),
                    ),
                  ),
                  SizedBox(
                    width: 60,
                    child: Text(
                      segWeightStr,
                      style: textTheme.bodySmall
                          ?.copyWith(color: colorScheme.tertiary),
                    ),
                  ),
                  const SizedBox(width: AthlosSpacing.lg),
                ],
              ),
            );
          }),

        if (setEntry.leftReps != null || setEntry.rightReps != null)
          Padding(
            padding: const EdgeInsets.only(
              left: AthlosSpacing.lg + AthlosSpacing.sm,
              bottom: AthlosSpacing.xs,
            ),
            child: Row(
              children: [
                Icon(Icons.swap_horiz,
                    size: 12, color: colorScheme.secondary),
                const SizedBox(width: AthlosSpacing.xs),
                Text(
                  '${l10n.leftAbbr}: ${setEntry.leftReps ?? "-"}×${_fmtWeight(setEntry.leftWeight)}  '
                  '${l10n.rightAbbr}: ${setEntry.rightReps ?? "-"}×${_fmtWeight(setEntry.rightWeight)}',
                  style: textTheme.bodySmall
                      ?.copyWith(color: colorScheme.secondary),
                ),
              ],
            ),
          ),

      ],
    );
  }

}
