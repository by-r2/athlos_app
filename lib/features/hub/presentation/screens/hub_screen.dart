import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/last_module_provider.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/services/user_data_sync_coordinator.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../core/widgets/app_bar_menu.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../training/presentation/widgets/dangling_execution_prompt_listener.dart';
import '../widgets/module_card.dart';

/// Hub screen — the app's main entry point ("Olympus").
///
/// This screen demonstrates key conventions:
///
/// 1. **ConsumerWidget** — Riverpod widget that has access to `ref`
///    Use ConsumerWidget when you need to watch providers.
///    Use ConsumerStatefulWidget when you also need lifecycle (initState, etc.)
///
/// 2. **AppLocalizations** — all user-facing strings come from ARB files
///    `final l10n = AppLocalizations.of(context)!;`
///    Then use `l10n.keyName` to get the localized string.
///
/// 3. **Theme access** — colors and text styles from Theme, never hardcoded
///    `final colorScheme = Theme.of(context).colorScheme;`
///    `final textTheme = Theme.of(context).textTheme;`
///
/// 4. **Navigation** — use `context.go('/path')` for go_router navigation
///    Route paths come from `RoutePaths` constants.
///
/// 5. **Spacing** — use `Gap` (from gap package) or `SizedBox` between widgets
///    instead of wrapping everything in `Padding`.
///
/// 6. **Widget extraction** — break complex builds into smaller methods or
///    separate widget classes (like `ModuleCard`).
class HubScreen extends ConsumerStatefulWidget {
  const HubScreen({super.key});

  @override
  ConsumerState<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends ConsumerState<HubScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(userDataSyncCoordinatorProvider).maybeRunScheduledSync());
    });
  }

  @override
  Widget build(BuildContext context) {
    // --- How to get localized strings ---
    final l10n = AppLocalizations.of(context)!;

    // --- How to get theme data ---
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DanglingExecutionPromptListener(
      child: PopScope(
      canPop: false,
      child: Scaffold(
        // --- App bar with profile action ---
        appBar: AppBar(
          title: Text(l10n.appTitle),
          actions: [const AppBarMenu()],
        ),

        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AthlosSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Gap(AthlosSpacing.lg),

                // --- Header ---
                Text(
                  l10n.hubGreeting,
                  style: textTheme.headlineMedium?.copyWith(
                    color: colorScheme.primary,
                  ),
                ),
                const Gap(AthlosSpacing.xs),
                Text(
                  l10n.hubSubtitle,
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const Gap(AthlosSpacing.xl),

                // --- Module cards ---
                // Training — enabled, navigates to training shell
                ModuleCard(
                  title: l10n.trainingModule,
                  description: l10n.trainingModuleDescription,
                  icon: Icons.fitness_center,
                  onTap: () {
                    ref
                        .read(lastModuleProvider.notifier)
                        .save(RoutePaths.training);
                    context.go(RoutePaths.training);
                  },
                ),
                const Gap(AthlosSpacing.smd),

                // Diet — disabled for V1, shows "coming soon"
                ModuleCard(
                  title: l10n.dietModule,
                  description: l10n.dietModuleDescription,
                  icon: Icons.restaurant,
                  isEnabled: false,
                  disabledLabel: l10n.comingSoon,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }
}
