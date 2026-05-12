import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/providers/internet_connection_provider.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/services/supabase_config.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/auth_error_code.dart';
import '../providers/auth_notifier.dart';
import '../providers/auth_prompt_notifier.dart';
import '../widgets/athlos_auth_scaffold.dart';

class AuthEmailScreen extends ConsumerStatefulWidget {
  final bool isSignUp;

  const AuthEmailScreen.signIn({super.key}) : isSignUp = false;

  const AuthEmailScreen.signUp({super.key}) : isSignUp = true;

  @override
  ConsumerState<AuthEmailScreen> createState() => _AuthEmailScreenState();
}

class _AuthEmailScreenState extends ConsumerState<AuthEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(RoutePaths.authPrompt);
  }

  Future<void> _continueLocal() async {
    await ref.read(localAccessProvider.notifier).accept();
    if (!mounted) return;
    context.go(RoutePaths.splash);
  }

  String _authErrorMessage(Object error, AppLocalizations l10n) {
    if (error is AuthAppException) {
      return switch (error.message) {
        AuthErrorCode.invalidCredentials => l10n.authInvalidCredentials,
        AuthErrorCode.emailNotConfirmed => l10n.authEmailNotConfirmed,
        AuthErrorCode.accountAlreadyExists => l10n.authAccountAlreadyExists,
        _ => l10n.authGenericError,
      };
    }
    if (error is NetworkException) return l10n.authNetworkError;
    if (error is AppException) return l10n.authGenericError;
    return l10n.authGenericError;
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;

    if (!isSupabaseConfigured) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.authSupabaseNotConfigured)));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final authNotifier = ref.read(authProvider.notifier);
      if (widget.isSignUp) {
        await authNotifier.signUpWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
        );
      } else {
        await authNotifier.signInWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }
      if (!mounted) return;
      context.go(RoutePaths.splash);
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_authErrorMessage(error, l10n))));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = widget.isSignUp ? l10n.authSignUpTitle : l10n.authSignInTitle;
    final internetState = ref.watch(internetConnectionProvider);

    return internetState.when(
      loading: () => _buildCheckingConnection(l10n, title),
      error: (_, _) => _buildOfflineAuth(l10n),
      data: (hasInternet) {
        if (!hasInternet) return _buildOfflineAuth(l10n);
        return _buildEmailForm(l10n, title);
      },
    );
  }

  Widget _buildCheckingConnection(AppLocalizations l10n, String title) {
    return AthlosAuthScaffold(
      title: title,
      subtitle: l10n.appTitle,
      showBackButton: true,
      onBackPressed: _goBack,
      heroHeightFactor: 0.3,
      symbolSize: 108,
      child: AthlosAuthCheckingPanel(message: l10n.authCheckingSession),
    );
  }

  Widget _buildOfflineAuth(AppLocalizations l10n) {
    return AthlosAuthScaffold(
      title: l10n.appTitle,
      subtitle: l10n.authPromptSubtitle,
      showBackButton: true,
      onBackPressed: _goBack,
      heroHeightFactor: 0.34,
      symbolSize: 116,
      child: AthlosAuthOfflinePanel(
        message: l10n.authOfflineModeMessage,
        actionLabel: l10n.authContinueLocalAction,
        onContinue: _isSubmitting ? null : _continueLocal,
      ),
    );
  }

  Widget _buildEmailForm(AppLocalizations l10n, String title) {
    return AthlosAuthScaffold(
      title: title,
      subtitle: l10n.appTitle,
      showBackButton: true,
      onBackPressed: _goBack,
      heroHeightFactor: 0.31,
      symbolSize: 112,
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.isSignUp
                    ? l10n.authSignUpEmailSubtitle
                    : l10n.authSignInEmailSubtitle,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const Gap(AthlosSpacing.xl),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(labelText: l10n.authEmailLabel),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (!_looksLikeEmail(email)) return l10n.authInvalidEmail;
                  return null;
                },
              ),
              const Gap(AthlosSpacing.md),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(labelText: l10n.authPasswordLabel),
                obscureText: true,
                autofillHints: widget.isSignUp
                    ? const [AutofillHints.newPassword]
                    : const [AutofillHints.password],
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                ],
                textInputAction: TextInputAction.done,
                validator: (value) {
                  final password = value ?? '';
                  if (password.length < 6) return l10n.authPasswordMinHint;
                  return null;
                },
                onFieldSubmitted: (_) => _submit(),
              ),
              const Gap(AthlosSpacing.xl),
              FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        widget.isSignUp
                            ? l10n.authCreateAccountAction
                            : l10n.authSignInAction,
                      ),
              ),
              const Gap(AthlosSpacing.sm),
              TextButton(
                onPressed: _isSubmitting
                    ? null
                    : () => context.go(
                        widget.isSignUp
                            ? RoutePaths.authSignIn
                            : RoutePaths.authSignUp,
                      ),
                child: Text(
                  widget.isSignUp
                      ? l10n.authHaveAccountAction
                      : l10n.authNoAccountAction,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _looksLikeEmail(String email) {
    final atIndex = email.indexOf('@');
    final dotIndex = email.lastIndexOf('.');
    return atIndex > 0 && dotIndex > atIndex + 1 && dotIndex < email.length - 1;
  }
}
