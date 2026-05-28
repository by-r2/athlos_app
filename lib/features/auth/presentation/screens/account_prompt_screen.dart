import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/feedback/athlos_messenger.dart';

import '../../../../core/constants/athlos_assets.dart';
import '../../../../core/providers/internet_connection_provider.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/services/supabase_config.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/enums/social_auth_provider.dart';
import '../providers/auth_notifier.dart';
import '../widgets/athlos_auth_scaffold.dart';

class AccountPromptScreen extends ConsumerWidget {
  const AccountPromptScreen({super.key});

  Future<void> _signInWithGoogle(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;

    if (!isSupabaseConfigured) {
      context.showAthlosErrorSnack(l10n.authSupabaseNotConfigured);
      return;
    }

    try {
      await ref
          .read(authProvider.notifier)
          .signInWithSocialProvider(SocialAuthProvider.google);
      if (!context.mounted) return;
      context.showAthlosSnack(l10n.authGoogleStarted);
    } on Exception {
      if (!context.mounted) return;
      context.showAthlosErrorSnack(l10n.authGenericError);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.watch(authProvider);
    final internetState = ref.watch(internetConnectionProvider);
    final isBusy = authState.isLoading;

    return internetState.when(
      loading: () => _authScaffold(
        l10n,
        child: AthlosAuthCheckingPanel(message: l10n.authCheckingSession),
      ),
      error: (_, _) => _authScaffold(
        l10n,
        child: AthlosAuthOfflinePanel(message: l10n.authRequiresInternetMessage),
      ),
      data: (hasInternet) {
        if (!hasInternet) {
          return _authScaffold(
            l10n,
            child: AthlosAuthOfflinePanel(
              message: l10n.authRequiresInternetMessage,
            ),
          );
        }

        return _authScaffold(
          l10n,
          child: _AuthChoicePanel(
            message: l10n.authPromptMessage,
            signInLabel: l10n.authSignInAction,
            createAccountLabel: l10n.authCreateAccountAction,
            googleTooltip: l10n.authSignInWithGoogleAction,
            isBusy: isBusy,
            onSignIn: () => context.push(RoutePaths.authSignIn),
            onCreateAccount: () => context.push(RoutePaths.authSignUp),
            onGoogle: isGoogleSignInEnabled
                ? () => _signInWithGoogle(context, ref)
                : null,
          ),
        );
      },
    );
  }

  Widget _authScaffold(
    AppLocalizations l10n, {
    required Widget child,
  }) {
    return AthlosAuthScaffold(
      title: l10n.appTitle,
      tagline: l10n.authPromptTagline,
      brandTitle: true,
      preset: AthlosAuthHeroPreset.welcome,
      child: child,
    );
  }
}

class _AuthChoicePanel extends StatelessWidget {
  const _AuthChoicePanel({
    required this.message,
    required this.signInLabel,
    required this.createAccountLabel,
    required this.googleTooltip,
    required this.isBusy,
    required this.onSignIn,
    required this.onCreateAccount,
    this.onGoogle,
  });

  final String message;
  final String signInLabel;
  final String createAccountLabel;
  final String googleTooltip;
  final bool isBusy;
  final VoidCallback onSignIn;
  final VoidCallback onCreateAccount;
  final VoidCallback? onGoogle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          message,
          style: textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const Gap(AthlosSpacing.lg),
        FilledButton(
          onPressed: isBusy ? null : onSignIn,
          child: Text(signInLabel),
        ),
        const Gap(AthlosSpacing.smd),
        OutlinedButton(
          onPressed: isBusy ? null : onCreateAccount,
          child: Text(createAccountLabel),
        ),
        if (onGoogle != null) ...[
          const Gap(AthlosSpacing.md),
          Center(
            child: Tooltip(
              message: googleTooltip,
              child: IconButton(
                onPressed: isBusy ? null : onGoogle,
                style: IconButton.styleFrom(
                  fixedSize: const Size(56, 56),
                  backgroundColor: Colors.transparent,
                  foregroundColor: colorScheme.onSurface,
                  disabledBackgroundColor: Colors.transparent,
                ),
                icon: SvgPicture.asset(
                  AthlosAssets.googleLogo,
                  width: 24,
                  height: 24,
                  semanticsLabel: googleTooltip,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
