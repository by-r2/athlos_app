import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/auth/presentation/providers/auth_notifier.dart';
import '../../../features/profile/presentation/providers/profile_notifier.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/app_entry_gate_provider.dart';
import '../../providers/session_bootstrap_provider.dart';
import '../../router/route_paths.dart';
import '../../theme/athlos_spacing.dart';
import '../../theme/athlos_text_theme.dart';

/// Displayed while the app resolves initial async state (e.g. hasProfile).
///
/// Navigation is handled by GoRouter redirect; this screen only reflects
/// [appEntryGateProvider] and offers a slow-startup escape hatch.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  static const _slowStartupDelay = Duration(seconds: 12);

  Timer? _slowStartupTimer;
  var _showSlowStartupHint = false;

  @override
  void initState() {
    super.initState();
    FlutterNativeSplash.remove();
    _slowStartupTimer = Timer(_slowStartupDelay, () {
      if (mounted) setState(() => _showSlowStartupHint = true);
    });
  }

  @override
  void dispose() {
    _slowStartupTimer?.cancel();
    super.dispose();
  }

  void _escapeSlowStartup() {
    ref.read(sessionBootstrapProvider.notifier).markBootstrapComplete();
    ref.invalidate(hasProfileProvider);
    ref.invalidate(profileProvider);

    if (ref.read(authProvider).value == null) {
      context.go(RoutePaths.authPrompt);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final gate = ref.watch(appEntryGateProvider);
    final blocksSplash = gate.blocksSplash;

    if (!blocksSplash && _showSlowStartupHint) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _showSlowStartupHint = false);
      });
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AthlosSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.appTitle,
                style: AthlosTextTheme.brandDisplay(colorScheme.primary),
              ),
              const SizedBox(height: AthlosSpacing.xl),
              if (blocksSplash) ...[
                SizedBox(
                  width: AthlosSpacing.lg,
                  height: AthlosSpacing.lg,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: colorScheme.primary,
                  ),
                ),
                if (_showSlowStartupHint) ...[
                  const SizedBox(height: AthlosSpacing.lg),
                  Text(
                    l10n.splashTakingLongMessage,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AthlosSpacing.md),
                  FilledButton(
                    onPressed: _escapeSlowStartup,
                    child: Text(
                      gate.hasAuthUser
                          ? l10n.splashContinueAction
                          : l10n.splashContinueToSignInAction,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
