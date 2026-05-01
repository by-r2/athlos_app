import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/athlos_router_pages.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../core/widgets/app_bar_menu.dart';
import '../../../../l10n/app_localizations.dart';
import 'equipment_screen.dart';
import 'program_detail_screen.dart';
import 'program_form_screen.dart';
import 'program_list_screen.dart';
import 'training_exercises_screen.dart';
import 'training_history_screen.dart';
import 'training_home_screen.dart';
import 'training_workouts_screen.dart';
import 'workout_catalog_screen.dart';

/// Training module shell with bottom navigation bar.
///
/// 3 tabs: Home, Workouts, History plus nested training routes share the same
/// Material Motion fade-through ([AthlosRouterPages.fadeThrough]), not slide.
/// Sub-pages: Exercises, Equipment, Programs, ProgramDetail, ProgramForm.
ShellRoute trainingShellRoute() {
  return ShellRoute(
    builder: (context, state, child) {
      return _TrainingShell(child: child);
    },
    routes: [
      GoRoute(
        path: RoutePaths.training,
        redirect: (context, state) {
          if (state.fullPath == RoutePaths.training) {
            return RoutePaths.trainingHome;
          }
          return null;
        },
      ),
      GoRoute(
        path: RoutePaths.trainingHome,
        pageBuilder: (context, state) => AthlosRouterPages.fadeThrough(
              state,
              const _TrainingRootTabBackGuard(child: TrainingHomeScreen()),
            ),
      ),
      GoRoute(
        path: RoutePaths.trainingWorkouts,
        pageBuilder: (context, state) => AthlosRouterPages.fadeThrough(
              state,
              const _TrainingRootTabBackGuard(child: TrainingWorkoutsScreen()),
            ),
      ),
      GoRoute(
        path: RoutePaths.trainingHistory,
        pageBuilder: (context, state) => AthlosRouterPages.fadeThrough(
              state,
              const _TrainingRootTabBackGuard(child: TrainingHistoryScreen()),
            ),
      ),
      GoRoute(
        path: RoutePaths.trainingWorkoutCatalog,
        pageBuilder: (context, state) => AthlosRouterPages.fadeThrough(
          state,
          const WorkoutCatalogScreen(),
        ),
      ),
      GoRoute(
        path: RoutePaths.trainingExercises,
        pageBuilder: (context, state) => AthlosRouterPages.fadeThrough(
          state,
          const TrainingExercisesScreen(),
        ),
      ),
      GoRoute(
        path: RoutePaths.trainingEquipment,
        pageBuilder: (context, state) => AthlosRouterPages.fadeThrough(
          state,
          const EquipmentScreen(),
        ),
      ),
      GoRoute(
        path: RoutePaths.trainingPrograms,
        pageBuilder: (context, state) => AthlosRouterPages.fadeThrough(
          state,
          const ProgramListScreen(),
        ),
      ),
      GoRoute(
        path: RoutePaths.trainingProgramNew,
        pageBuilder: (context, state) => AthlosRouterPages.fadeThrough(
          state,
          const ProgramFormScreen(),
        ),
      ),
      GoRoute(
        path: '${RoutePaths.trainingPrograms}/:programId',
        pageBuilder: (context, state) {
          final programId = int.parse(state.pathParameters['programId']!);
          return AthlosRouterPages.fadeThrough(
            state,
            ProgramDetailScreen(programId: programId),
          );
        },
      ),
      GoRoute(
        path: '${RoutePaths.trainingPrograms}/:programId/edit',
        pageBuilder: (context, state) {
          final programId = int.parse(state.pathParameters['programId']!);
          return AthlosRouterPages.fadeThrough(
            state,
            ProgramFormScreen(programId: programId),
          );
        },
      ),
    ],
  );
}

class _TrainingShell extends ConsumerWidget {
  final Widget child;

  const _TrainingShell({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentPath =
        GoRouterState.of(context).fullPath ?? RoutePaths.trainingHome;

    final isSubPage = _isSubPage(currentPath);

    final subPageBackTarget = _subPageBackTarget(currentPath);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _TrainingShell._handleBackNavigation(
          context,
          isSubPage: isSubPage,
          subPageBackTarget: subPageBackTarget,
        );
      },
      child: Scaffold(
        appBar: AppBar(
          leading: isSubPage
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => _TrainingShell._handleBackNavigation(
                    context,
                    isSubPage: isSubPage,
                    subPageBackTarget: subPageBackTarget,
                  ),
                )
              : null,
          automaticallyImplyLeading: false,
          title: Text(l10n.trainingModule),
          actions: const [AppBarMenu()],
        ),
        body: child,
        bottomNavigationBar: SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(
              AthlosSpacing.md,
              0,
              AthlosSpacing.md,
              AthlosSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: AthlosRadius.lgAll,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: AthlosSpacing.sm,
                  offset: const Offset(0, -AthlosSpacing.xxs),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: AthlosRadius.lgAll,
              child: NavigationBar(
                selectedIndex: _indexFromPath(currentPath),
                onDestinationSelected: (index) => _onTabTap(context, index),
                destinations: [
                  NavigationDestination(
                    icon: const Icon(Icons.dashboard_outlined),
                    selectedIcon: const Icon(Icons.dashboard),
                    label: l10n.tabDashboard,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.fitness_center_outlined),
                    selectedIcon: const Icon(Icons.fitness_center),
                    label: l10n.tabTraining,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.timeline_outlined),
                    selectedIcon: const Icon(Icons.timeline),
                    label: l10n.tabHistory,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const _primaryPaths = {
    RoutePaths.trainingHome,
    RoutePaths.trainingWorkouts,
    RoutePaths.trainingHistory,
  };

  static void _handleBackNavigation(
    BuildContext context, {
    required bool isSubPage,
    required String subPageBackTarget,
  }) {
    if (isSubPage) {
      if (context.canPop()) {
        context.pop();
        return;
      }
      context.go(subPageBackTarget);
      return;
    }
    context.go(RoutePaths.hub);
  }

  bool _isSubPage(String path) => !_primaryPaths.contains(path);

  String _subPageBackTarget(String path) {
    if (path.startsWith(RoutePaths.trainingPrograms)) {
      return RoutePaths.trainingWorkouts;
    }
    return RoutePaths.trainingHome;
  }

  int _indexFromPath(String path) {
    if (path.startsWith(RoutePaths.trainingWorkouts)) return 1;
    if (path.startsWith(RoutePaths.trainingPrograms)) return 1;
    if (path.startsWith(RoutePaths.trainingHistory)) return 2;
    return 0;
  }

  void _onTabTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(RoutePaths.trainingHome);
      case 1:
        context.go(RoutePaths.trainingWorkouts);
      case 2:
        context.go(RoutePaths.trainingHistory);
    }
  }
}

class _TrainingRootTabBackGuard extends StatelessWidget {
  final Widget child;

  const _TrainingRootTabBackGuard({required this.child});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go(RoutePaths.hub);
      },
      child: child,
    );
  }
}
