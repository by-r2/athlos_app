import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../core/theme/theme_mode_provider.dart';
import '../../../../l10n/app_localizations.dart';
import 'equipment_screen.dart';
import 'training_exercises_screen.dart';
import 'training_home_screen.dart';
import 'training_workouts_screen.dart';
import 'training_history_screen.dart';

/// Training module shell with bottom navigation bar.
///
/// 3 tabs: Home, Workouts, History.
/// Catalogs (Exercises, Equipment) are accessible from the Home tab.
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
        builder: (context, state) => const TrainingHomeScreen(),
      ),
      GoRoute(
        path: RoutePaths.trainingWorkouts,
        builder: (context, state) => const TrainingWorkoutsScreen(),
      ),
      GoRoute(
        path: RoutePaths.trainingHistory,
        builder: (context, state) => const TrainingHistoryScreen(),
      ),
      GoRoute(
        path: RoutePaths.trainingExercises,
        builder: (context, state) => const TrainingExercisesScreen(),
      ),
      GoRoute(
        path: RoutePaths.trainingEquipment,
        builder: (context, state) => const EquipmentScreen(),
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

    return Scaffold(
      appBar: AppBar(
        leading: isSubPage
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go(RoutePaths.trainingHome),
              )
            : null,
        automaticallyImplyLeading: false,
        title: Text(l10n.trainingModule),
        actions: [
          IconButton(
            icon: Icon(ref.watch(themeModeProvider.notifier).icon),
            onPressed: () {
              try {
                ref.read(themeModeProvider.notifier).toggle();
              } on Exception catch (_) {
                // Best-effort; theme change persists in memory regardless
              }
            },
          ),
          if (!isSubPage)
            IconButton(
              icon: const Icon(Icons.home_outlined),
              tooltip: l10n.backToHub,
              onPressed: () => context.go(RoutePaths.hub),
            ),
        ],
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
                blurRadius: 8,
                offset: const Offset(0, -2),
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
                  label: l10n.tabHome,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.fitness_center_outlined),
                  selectedIcon: const Icon(Icons.fitness_center),
                  label: l10n.tabWorkouts,
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
    );
  }

  static const _primaryPaths = {
    RoutePaths.trainingHome,
    RoutePaths.trainingWorkouts,
    RoutePaths.trainingHistory,
  };

  bool _isSubPage(String path) => !_primaryPaths.contains(path);

  int _indexFromPath(String path) {
    if (path.startsWith(RoutePaths.trainingWorkouts)) return 1;
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
