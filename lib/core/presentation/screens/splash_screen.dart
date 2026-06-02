import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/auth/presentation/providers/auth_notifier.dart';
import '../../../features/profile/presentation/providers/profile_notifier.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/session_bootstrap_provider.dart';
import '../../router/route_paths.dart';
import '../../theme/athlos_spacing.dart';
import '../../theme/athlos_text_theme.dart';

/// Displayed while the app resolves initial async state (e.g. hasProfile).
///
/// No navigation logic here — GoRouter redirect handles routing
/// once the profile check resolves.
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

  void _openSignIn() {
    ref.read(sessionBootstrapProvider.notifier).markBootstrapComplete();
    ref.invalidate(hasProfileProvider);
    ref.invalidate(profileProvider);
    context.go(RoutePaths.authPrompt);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final authAsync = ref.watch(authProvider);
    final hasProfileAsync = ref.watch(hasProfileProvider);
    final isBootstrapping = ref.watch(sessionBootstrapProvider);

    final isStillResolving =
        authAsync.isLoading ||
        (authAsync.value != null &&
            (hasProfileAsync.isLoading || !isBootstrapping));

    if (!isStillResolving && _showSlowStartupHint) {
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
                'Athlos',
                style: AthlosTextTheme.brandDisplay(colorScheme.primary),
              ),
              const SizedBox(height: AthlosSpacing.xl),
              if (isStillResolving) ...[
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
                    onPressed: _openSignIn,
                    child: Text(l10n.splashContinueToSignInAction),
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
