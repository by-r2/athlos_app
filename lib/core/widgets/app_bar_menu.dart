import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../features/chiron/presentation/widgets/chiron_bottom_sheet.dart';
import '../../l10n/app_localizations.dart';
import '../router/route_paths.dart';
import '../services/gemini_config.dart';
import '../theme/athlos_bottom_sheet.dart';
import '../theme/athlos_component_sizes.dart';
import '../theme/athlos_radius.dart';
import '../theme/athlos_spacing.dart';
import '../theme/theme_mode_provider.dart';

/// Global app bar: Chiron (if configured) + **overflow menu as a bottom sheet**.
///
/// Thumb-friendly sheet with navigation rows and a Material 3 [SegmentedButton]
/// for theme — a common pattern in modern mobile apps vs a compact popup menu.
class AppBarMenu extends ConsumerWidget {
  const AppBarMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final materialLoc = MaterialLocalizations.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isGeminiConfigured)
          IconButton(
            icon: const Icon(Icons.auto_awesome_outlined),
            tooltip: l10n.chironTitle,
            onPressed: () => showChironSheet(context),
          ),
        IconButton(
          padding: EdgeInsets.zero,
          tooltip: materialLoc.showMenuTooltip,
          onPressed: () => _openAppMenuSheet(context),
          icon: const Icon(Icons.more_vert),
        ),
      ],
    );
  }
}

void _openAppMenuSheet(BuildContext context) {
  showAthlosModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => const SizedBox(
      width: double.infinity,
      child: _AppMenuSheetBody(),
    ),
  );
}

class _AppMenuSheetBody extends ConsumerWidget {
  const _AppMenuSheetBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final router = GoRouter.of(context);
    final mode = ref.watch(themeModeProvider);

    TextStyle? sectionTitle = textTheme.labelLarge?.copyWith(
      color: colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AthlosSpacing.md,
        AthlosSpacing.sm,
        AthlosSpacing.md,
        AthlosSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(l10n.appMenuNavigationSection, style: sectionTitle),
          ),
          const Gap(AthlosSpacing.sm),
          _MenuNavTile(
            icon: Icons.person_outline,
            title: l10n.profile,
            onTap: () {
              Navigator.pop(context);
              router.push(RoutePaths.profile);
            },
          ),
          _MenuNavTile(
            icon: Icons.home_outlined,
            title: l10n.backToHub,
            onTap: () {
              Navigator.pop(context);
              router.go(RoutePaths.hub);
            },
          ),
          const Gap(AthlosSpacing.xl),
          Semantics(
            header: true,
            child: Text(l10n.appMenuThemeSection, style: sectionTitle),
          ),
          const Gap(AthlosSpacing.sm),
          SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment<ThemeMode>(
                value: ThemeMode.light,
                label: _ThemeModeSegmentLabel(
                  icon: Icons.light_mode_outlined,
                  label: l10n.themeModeLight,
                ),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.dark,
                label: _ThemeModeSegmentLabel(
                  icon: Icons.dark_mode_outlined,
                  label: l10n.themeModeDark,
                ),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.system,
                label: _ThemeModeSegmentLabel(
                  icon: Icons.brightness_auto_outlined,
                  label: l10n.themeModeSystem,
                ),
              ),
            ],
            emptySelectionAllowed: false,
            selected: {mode},
            onSelectionChanged: (selection) {
              if (selection.isEmpty) return;
              ref
                  .read(themeModeProvider.notifier)
                  .setThemeMode(selection.first);
            },
          ),
        ],
      ),
    );
  }
}

/// Icon above label so three segments fit narrow widths without wrapping text.
class _ThemeModeSegmentLabel extends StatelessWidget {
  const _ThemeModeSegmentLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20),
        const Gap(AthlosSpacing.xxs),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            textAlign: TextAlign.center,
            style: textTheme.labelSmall,
          ),
        ),
      ],
    );
  }
}

class _MenuNavTile extends StatelessWidget {
  const _MenuNavTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AthlosSpacing.xs),
      child: Material(
        color: colorScheme.bottomSheetContainer,
        borderRadius: AthlosRadius.mdAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ListTile(
            minTileHeight: AthlosComponentSizes.listItemMinHeight,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AthlosSpacing.md,
              vertical: AthlosSpacing.xs,
            ),
            leading: _MenuIconBadge(colorScheme: colorScheme, icon: icon),
            title: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuIconBadge extends StatelessWidget {
  const _MenuIconBadge({required this.colorScheme, required this.icon});

  final ColorScheme colorScheme;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: AthlosRadius.mdAll,
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 22, color: colorScheme.onPrimaryContainer),
    );
  }
}
