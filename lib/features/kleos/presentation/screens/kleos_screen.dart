import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../core/theme/athlos_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../../profile/presentation/providers/profile_notifier.dart';
import '../../../training/domain/enums/muscle_group.dart';
import '../../../training/presentation/helpers/exercise_l10n.dart';
import '../../../training/presentation/providers/training_analytics_provider.dart';
import '../../../training/presentation/providers/training_metrics_provider.dart';
import '../helpers/kleos_pr_grouping.dart';
import '../widgets/kleos_consistency_panel.dart';
import '../widgets/kleos_evolution_snippet.dart';
import '../widgets/kleos_hero_header.dart';
import '../widgets/kleos_muscle_pr_selector.dart';
import '../widgets/kleos_objective_summary.dart';
import '../widgets/kleos_related_links.dart';
import '../widgets/kleos_section.dart';

Future<void> _invalidateKleosData(WidgetRef ref) async {
  ref.invalidate(profileProvider);
  ref.invalidate(allExercisePRsProvider);
  ref.invalidate(trainingHomeAnalyticsProvider);
  ref.invalidate(finishedSessionCountProvider);
  ref.invalidate(thisWeekSessionCountProvider);
  ref.invalidate(consistencyStatusProvider);
  ref.invalidate(lastExecutedWorkoutComparisonProvider);
  await ref.read(allExercisePRsProvider.future);
}

bool _hasFrequencyStreakSignal(UserProfile? profile) {
  if (profile == null) return false;
  return profile.currentFrequencyStreak > 0 ||
      profile.bestFrequencyStreak > 0;
}

/// Kleos (κλέος): factual training wins — summary and consistency before PR depth.
class KleosScreen extends ConsumerWidget {
  const KleosScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const KleosScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final profileAsync = ref.watch(profileProvider);
    final prsAsync = ref.watch(allExercisePRsProvider);
    final analyticsAsync = ref.watch(trainingHomeAnalyticsProvider);
    final finishedCountAsync = ref.watch(finishedSessionCountProvider);
    final thisWeekAsync = ref.watch(thisWeekSessionCountProvider);
    final consistencyAsync = ref.watch(consistencyStatusProvider);

    final isLoading =
        profileAsync.isLoading ||
        prsAsync.isLoading ||
        analyticsAsync.isLoading;

    if (!isLoading &&
        (profileAsync.hasError ||
            prsAsync.hasError ||
            analyticsAsync.hasError)) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.kleosScreenTitle)),
        body: Center(child: Text(l10n.genericError)),
      );
    }

    final profile = profileAsync.value;
    final prs = prsAsync.value ?? const [];
    final analytics = analyticsAsync.value;
    final finishedTotal = finishedCountAsync.value ??
        (analytics != null ? finishedSessionsFromAnalytics(analytics) : 0);
    final finishedSessionCount = finishedCountAsync.value ?? finishedTotal;

    final thisWeek = thisWeekAsync.value ?? 0;
    final weeklyTarget =
        profile?.trainingFrequency ?? kDefaultTrainingFrequency;
    final consistency = consistencyAsync.value ??
        const ConsistencyStatus(
          streakCount: 0,
          isCurrentWeekSecured: false,
        );

    final hasStrengthData = prs.isNotEmpty;
    final hasMeaningfulData =
        profile != null &&
        (finishedTotal > 0 ||
            hasStrengthData ||
            _hasFrequencyStreakSignal(profile));

    List<MapEntry<String, ExercisePRRecord>> muscleEntries;
    if (!hasStrengthData) {
      muscleEntries = const [];
    } else {
      final best = bestPrPerMuscleGroup(prs);
      muscleEntries = best.entries.toList()
        ..sort((a, b) {
          final ga =
              MuscleGroup.values.where((g) => g.name == a.key).firstOrNull;
          final gb =
              MuscleGroup.values.where((g) => g.name == b.key).firstOrNull;
          final la =
              ga != null ? localizedMuscleGroupName(ga, l10n) : a.key;
          final lb =
              gb != null ? localizedMuscleGroupName(gb, l10n) : b.key;
          return la.compareTo(lb);
        });
    }

    final scrollChildren = <Widget>[
      KleosHeroHeader(l10n: l10n),
      const Gap(AthlosSpacing.xl),
    ];

    if (!hasMeaningfulData && !hasStrengthData) {
      scrollChildren.add(
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(AthlosSpacing.xl),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(AthlosSpacing.lg),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.insights_outlined,
                    size: 36,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const Gap(AthlosSpacing.md),
                Text(
                  l10n.kleosEmptyTitle,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Gap(AthlosSpacing.sm),
                Text(
                  l10n.kleosEmptyBody,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      scrollChildren.addAll([
        KleosSection(
          title: l10n.kleosSectionSnapshotTitle,
          icon: Icons.dashboard_outlined,
          child: KleosObjectiveSummary(
            l10n: l10n,
            finishedSessions: finishedTotal,
            estimatedPrCount: prs.length,
            muscleGroupsWithPr: muscleEntries.length,
          ),
        ),
        const Gap(AthlosSpacing.xl),
        if (profile != null)
          KleosSection(
            title: l10n.kleosSectionConsistency,
            hint: l10n.kleosSectionConsistencyHint,
            icon: Icons.local_fire_department_outlined,
            child: KleosConsistencyPanel(
              profile: profile,
              finishedSessionCount: finishedSessionCount,
              thisWeekCount: thisWeek,
              weeklyTarget: weeklyTarget,
              consistency: consistency,
              l10n: l10n,
            ),
          )
        else
          KleosSection(
            title: l10n.kleosSectionConsistency,
            icon: Icons.local_fire_department_outlined,
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(AthlosSpacing.md),
                child: Text(
                  l10n.kleosConsistencyPlaceholder,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        Consumer(
          builder: (context, ref, _) {
            final evolution = ref.watch(lastExecutedWorkoutComparisonProvider);
            final hasData = evolution.maybeWhen(
              data: (d) => d != null,
              orElse: () => false,
            );
            if (!hasData) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Gap(AthlosSpacing.xl),
                KleosSection(
                  title: l10n.kleosEvolutionSectionTitle,
                  hint: l10n.kleosEvolutionSectionHint,
                  icon: Icons.show_chart_outlined,
                  child: const KleosEvolutionSnippet(),
                ),
              ],
            );
          },
        ),
        const Gap(AthlosSpacing.xl),
        KleosSection(
          title: l10n.kleosSectionStrengthByMuscle,
          hint: l10n.kleosSectionStrengthByMuscleHint,
          icon: Icons.fitness_center_outlined,
          child: muscleEntries.isEmpty
              ? Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(AthlosSpacing.lg),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const Gap(AthlosSpacing.md),
                        Expanded(
                          child: Text(
                            hasStrengthData
                                ? l10n.kleosStrengthEmpty
                                : l10n.kleosNoPrDataYet,
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : KleosMusclePrSelector(
                  l10n: l10n,
                  entries: muscleEntries,
                  allPrs: prs,
                ),
        ),
        if (hasMeaningfulData || hasStrengthData) ...[
          const Gap(AthlosSpacing.xl),
          KleosSection(
            title: l10n.kleosRelatedTitle,
            icon: Icons.arrow_outward_rounded,
            child: KleosRelatedLinks(l10n: l10n),
          ),
        ],
      ]);
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.kleosScreenTitle)),
      body: Skeletonizer(
        enabled: isLoading,
        child: RefreshIndicator(
          onRefresh: () => _invalidateKleosData(ref),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AthlosSpacing.md,
              AthlosSpacing.md,
              AthlosSpacing.md,
              AthlosSpacing.xxl,
            ),
            children: scrollChildren,
          ),
        ),
      ),
    );
  }
}
