import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/providers/internet_connection_provider.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/services/supabase_config.dart';
import '../../../../core/theme/athlos_durations.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../core/widgets/feedback/athlos_chat_bubble.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/auth_error_code.dart';
import '../providers/auth_notifier.dart';
import '../widgets/athlos_auth_scaffold.dart';

class AuthEmailScreen extends ConsumerStatefulWidget {
  final bool isSignUp;

  const AuthEmailScreen.signIn({super.key}) : isSignUp = false;

  const AuthEmailScreen.signUp({super.key}) : isSignUp = true;

  @override
  ConsumerState<AuthEmailScreen> createState() => _AuthEmailScreenState();
}

enum _SignUpStep { email, password, ready }

class _AuthChatEntry {
  final String text;
  final bool isUser;
  final _SignUpStep? inputStep;

  const _AuthChatEntry({
    required this.text,
    required this.isUser,
    this.inputStep,
  });

  _AuthChatEntry copyWith({
    String? text,
    bool? isUser,
    _SignUpStep? inputStep,
  }) {
    return _AuthChatEntry(
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      inputStep: inputStep ?? this.inputStep,
    );
  }
}

class _AuthEmailScreenState extends ConsumerState<AuthEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _chatScrollController = ScrollController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _chatController = TextEditingController();
  final _chatEntries = <_AuthChatEntry>[];

  _SignUpStep _signUpStep = _SignUpStep.email;
  int? _editingIndex;
  _SignUpStep? _editingStep;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.isSignUp) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startSignUpChat());
    }
  }

  @override
  void dispose() {
    _chatScrollController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(RoutePaths.authPrompt);
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

  Future<void> _submitSignIn() async {
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
      await ref
          .read(authProvider.notifier)
          .signInWithEmail(
            email: _emailController.text,
            password: _passwordController.text,
          );
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

  void _startSignUpChat() {
    final l10n = AppLocalizations.of(context)!;
    if (_chatEntries.isNotEmpty) return;
    _addAssistantMessage(l10n.authSignUpChatGreeting);
    Future.delayed(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      _addAssistantMessage(l10n.authSignUpChatAskEmail);
    });
  }

  void _addAssistantMessage(String text) {
    setState(() => _chatEntries.add(_AuthChatEntry(text: text, isUser: false)));
    _scrollSignUpChatToBottom();
  }

  void _addUserMessage(String text, {_SignUpStep? answeredStep}) {
    setState(
      () => _chatEntries.add(
        _AuthChatEntry(text: text, isUser: true, inputStep: answeredStep),
      ),
    );
    _scrollSignUpChatToBottom();
  }

  void _scrollSignUpChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_chatScrollController.hasClients) return;
      _chatScrollController.animateTo(
        _chatScrollController.position.maxScrollExtent,
        duration: AthlosDurations.normal,
        curve: Curves.easeOut,
      );
    });
  }

  bool _tryApplyEditedSignUpAnswer({
    required _SignUpStep step,
    required String text,
    required VoidCallback applyValue,
  }) {
    final editingIndex = _editingIndex;
    if (editingIndex == null || _editingStep != step) return false;

    setState(() {
      applyValue();
      _chatEntries[editingIndex] = _chatEntries[editingIndex].copyWith(
        text: text,
      );
      _editingIndex = null;
      _editingStep = null;
    });
    _chatController.clear();
    _scrollSignUpChatToBottom();
    return true;
  }

  void _startEditingSignUpAnswer(int entryIndex) {
    if (_isSubmitting || entryIndex < 0 || entryIndex >= _chatEntries.length) {
      return;
    }
    final entry = _chatEntries[entryIndex];
    if (!entry.isUser || entry.inputStep == null) return;

    setState(() {
      _editingIndex = entryIndex;
      _editingStep = entry.inputStep;
      _chatController.text = switch (_editingStep!) {
        _SignUpStep.email => _emailController.text,
        _SignUpStep.password => _passwordController.text,
        _SignUpStep.ready => '',
      };
    });
    _scrollSignUpChatToBottom();
  }

  _SignUpStep? get _activeSignUpInputStep {
    if (_editingStep != null) return _editingStep;
    return _signUpStep == _SignUpStep.ready ? null : _signUpStep;
  }

  void _handleSignUpChatInput(String value) {
    final l10n = AppLocalizations.of(context)!;
    final text = value.trim();
    final activeStep = _activeSignUpInputStep;
    if (text.isEmpty || _isSubmitting || activeStep == null) return;

    if (activeStep == _SignUpStep.email) {
      if (_editingStep == null) {
        _addUserMessage(text, answeredStep: _SignUpStep.email);
      }
      _chatController.clear();
      if (!_looksLikeEmail(text)) {
        _addAssistantMessage(l10n.authInvalidEmail);
        return;
      }
      if (_tryApplyEditedSignUpAnswer(
        step: _SignUpStep.email,
        text: text,
        applyValue: () => _emailController.text = text,
      )) {
        return;
      }
      _emailController.text = text;
      setState(() => _signUpStep = _SignUpStep.password);
      Future.delayed(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        _addAssistantMessage(l10n.authSignUpChatAskPassword);
      });
      return;
    }

    if (_editingStep == null) {
      _addUserMessage(
        l10n.authPasswordHiddenMessage,
        answeredStep: _SignUpStep.password,
      );
    }
    _chatController.clear();
    if (text.length < 6) {
      _addAssistantMessage(l10n.authPasswordMinHint);
      return;
    }
    if (_tryApplyEditedSignUpAnswer(
      step: _SignUpStep.password,
      text: l10n.authPasswordHiddenMessage,
      applyValue: () => _passwordController.text = text,
    )) {
      return;
    }

    _passwordController.text = text;
    setState(() => _signUpStep = _SignUpStep.ready);
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _addAssistantMessage(l10n.authSignUpChatReady);
    });
  }

  Future<void> _submitSignUpFromChat() async {
    final l10n = AppLocalizations.of(context)!;

    if (!isSupabaseConfigured) {
      _addAssistantMessage(l10n.authSupabaseNotConfigured);
      return;
    }

    setState(() => _isSubmitting = true);
    _addAssistantMessage(l10n.authSignUpChatCreating);
    try {
      await ref
          .read(authProvider.notifier)
          .signUpWithEmail(
            email: _emailController.text,
            password: _passwordController.text,
          );
      if (!mounted) return;
      _addAssistantMessage(l10n.authSignUpChatSuccess);
      Future.delayed(const Duration(milliseconds: 700), () {
        if (!mounted) return;
        context.go(RoutePaths.splash);
      });
    } on Object catch (error) {
      if (!mounted) return;
      if (error is AuthAppException &&
          error.message == AuthErrorCode.emailNotConfirmed) {
        if (!mounted) return;
        _addAssistantMessage(l10n.authSignUpChatGoToLogin);
        Future.delayed(const Duration(milliseconds: 900), () {
          if (!mounted) return;
          context.go(RoutePaths.authSignIn);
        });
        return;
      }
      _addAssistantMessage(_authErrorMessage(error, l10n));
      setState(() {
        _signUpStep = _SignUpStep.password;
        _editingIndex = null;
        _editingStep = null;
      });
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
        if (widget.isSignUp) return _buildSignUpChat(l10n, title);
        return _buildSignInForm(l10n, title);
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
      child: AthlosAuthOfflinePanel(message: l10n.authRequiresInternetMessage),
    );
  }

  Widget _buildSignInForm(AppLocalizations l10n, String title) {
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
                l10n.authSignInEmailSubtitle,
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
                autofillHints: const [AutofillHints.password],
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                ],
                textInputAction: TextInputAction.done,
                validator: (value) {
                  final password = value ?? '';
                  if (password.length < 6) return l10n.authPasswordMinHint;
                  return null;
                },
                onFieldSubmitted: (_) => _submitSignIn(),
              ),
              const Gap(AthlosSpacing.xl),
              FilledButton(
                onPressed: _isSubmitting ? null : _submitSignIn,
                child: _isSubmitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.authSignInAction),
              ),
              const Gap(AthlosSpacing.sm),
              TextButton(
                onPressed: _isSubmitting
                    ? null
                    : () => context.go(RoutePaths.authSignUp),
                child: Text(l10n.authNoAccountAction),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignUpChat(AppLocalizations l10n, String title) {
    final activeStep = _activeSignUpInputStep;
    return AthlosAuthScaffold(
      title: title,
      subtitle: l10n.appTitle,
      showBackButton: true,
      onBackPressed: _goBack,
      heroHeightFactor: 0.25,
      symbolSize: 88,
      panelPadding: EdgeInsets.zero,
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _chatScrollController,
              padding: const EdgeInsets.fromLTRB(
                AthlosSpacing.md,
                AthlosSpacing.xl,
                AthlosSpacing.md,
                AthlosSpacing.sm,
              ),
              itemCount: _chatEntries.length,
              itemBuilder: (context, index) {
                final entry = _chatEntries[index];
                return AthlosChatBubble(
                  key: ValueKey(index),
                  text: entry.text,
                  isUser: entry.isUser,
                  isEditing: _editingIndex == index,
                  onTap:
                      entry.isUser &&
                          entry.inputStep != null &&
                          !_isSubmitting &&
                          (_editingIndex == null || _editingIndex == index)
                      ? () => _startEditingSignUpAnswer(index)
                      : null,
                );
              },
            ),
          ),
          _SignUpInputBar(
            step: activeStep,
            controller: _chatController,
            isSubmitting: _isSubmitting,
            onSubmitted: _handleSignUpChatInput,
            onCreateAccount: _submitSignUpFromChat,
            onGoToSignIn: () => context.go(RoutePaths.authSignIn),
          ),
        ],
      ),
    );
  }

  bool _looksLikeEmail(String email) {
    final atIndex = email.indexOf('@');
    final dotIndex = email.lastIndexOf('.');
    return atIndex > 0 && dotIndex > atIndex + 1 && dotIndex < email.length - 1;
  }
}

class _SignUpInputBar extends StatelessWidget {
  const _SignUpInputBar({
    required this.step,
    required this.controller,
    required this.isSubmitting,
    required this.onSubmitted,
    required this.onCreateAccount,
    required this.onGoToSignIn,
  });

  final _SignUpStep? step;
  final TextEditingController controller;
  final bool isSubmitting;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onCreateAccount;
  final VoidCallback onGoToSignIn;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AthlosSpacing.md,
            AthlosSpacing.sm,
            AthlosSpacing.md,
            AthlosSpacing.md,
          ),
          child: step == null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilledButton(
                      onPressed: isSubmitting ? null : onCreateAccount,
                      child: isSubmitting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.authCreateAccountAction),
                    ),
                    const Gap(AthlosSpacing.sm),
                    TextButton(
                      onPressed: isSubmitting ? null : onGoToSignIn,
                      child: Text(l10n.authHaveAccountAction),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        enabled: !isSubmitting,
                        obscureText: step == _SignUpStep.password,
                        keyboardType: step == _SignUpStep.email
                            ? TextInputType.emailAddress
                            : TextInputType.visiblePassword,
                        textInputAction: TextInputAction.send,
                        autofillHints: step == _SignUpStep.email
                            ? const [AutofillHints.email]
                            : const [AutofillHints.newPassword],
                        inputFormatters: step == _SignUpStep.password
                            ? [FilteringTextInputFormatter.deny(RegExp(r'\s'))]
                            : null,
                        decoration: InputDecoration(
                          labelText: step == _SignUpStep.email
                              ? l10n.authEmailLabel
                              : l10n.authPasswordLabel,
                        ),
                        onSubmitted: onSubmitted,
                      ),
                    ),
                    const Gap(AthlosSpacing.sm),
                    IconButton.filledTonal(
                      onPressed: isSubmitting
                          ? null
                          : () => onSubmitted(controller.text),
                      style: IconButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onSurface,
                      ),
                      icon: const Icon(Icons.send, size: 20),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
