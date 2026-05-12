import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/internet_connection_provider.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/services/supabase_config.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../core/widgets/feedback/athlos_chat_bubble.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../profile/presentation/providers/profile_notifier.dart';
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

  Future<void> _continueLocal() async {
    await ref.read(authPromptProvider.notifier).markCompleted();
    if (!mounted) return;

    final hasProfile = ref.read(hasProfileProvider).value ?? false;
    context.go(hasProfile ? RoutePaths.hub : RoutePaths.profileSetup);
  }

  _SignUpStep? get _activeSignUpInputStep =>
      _editingStep ??
      switch (_signUpStep) {
        _SignUpStep.email => _SignUpStep.email,
        _SignUpStep.password => _SignUpStep.password,
        _SignUpStep.ready => null,
      };

  void _scrollSignUpChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_chatScrollController.hasClients) return;
      _chatScrollController.animateTo(
        _chatScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _addChatMessage(
    String text, {
    required bool isUser,
    _SignUpStep? inputStep,
  }) {
    setState(() {
      _chatEntries.add(
        _AuthChatEntry(text: text, isUser: isUser, inputStep: inputStep),
      );
    });
    _scrollSignUpChatToBottom();
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
  }

  void _startSignUpChat() {
    final l10n = AppLocalizations.of(context)!;
    if (_chatEntries.isNotEmpty) return;
    _addChatMessage(l10n.authSignUpChatGreeting, isUser: false);
    _addChatMessage(l10n.authSignUpChatAskEmail, isUser: false);
  }

  Future<void> _submitEmailForm() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;

    if (!isSupabaseConfigured) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.authSupabaseNotConfigured)));
      return;
    }

    final authNotifier = ref.read(authProvider.notifier);
    final authPromptNotifier = ref.read(authPromptProvider.notifier);

    setState(() => _isSubmitting = true);
    try {
      await authNotifier.signInWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;
      await authPromptNotifier.markCompleted();
      if (!mounted) return;
      context.go(RoutePaths.hub);
    } on Exception {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.authGenericError)));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _handleChatInput(String value) {
    final l10n = AppLocalizations.of(context)!;
    final text = value.trim();
    if (text.isEmpty || _isSubmitting) return;
    final activeStep = _activeSignUpInputStep;
    if (activeStep == null) return;

    if (activeStep == _SignUpStep.email) {
      if (!text.contains('@')) {
        if (_editingStep == null) {
          _addChatMessage(text, isUser: true);
        }
        _addChatMessage(l10n.authSignUpChatInvalidEmail, isUser: false);
        _chatController.clear();
        return;
      }

      if (_tryApplyEditedSignUpAnswer(
        step: _SignUpStep.email,
        text: text,
        applyValue: () => _emailController.text = text,
      )) {
        return;
      }

      setState(() {
        _emailController.text = text;
        _signUpStep = _SignUpStep.password;
      });
      _addChatMessage(text, isUser: true, inputStep: _SignUpStep.email);
      _addChatMessage(l10n.authSignUpChatAskPassword, isUser: false);
      _chatController.clear();
      return;
    }

    if (activeStep == _SignUpStep.password) {
      if (text.length < 6) {
        if (_editingStep == null) {
          _addChatMessage('••••••', isUser: true);
        }
        _addChatMessage(l10n.authSignUpChatInvalidPassword, isUser: false);
        _chatController.clear();
        return;
      }

      if (_tryApplyEditedSignUpAnswer(
        step: _SignUpStep.password,
        text: '••••••',
        applyValue: () => _passwordController.text = text,
      )) {
        return;
      }

      setState(() {
        _passwordController.text = text;
        _signUpStep = _SignUpStep.ready;
      });
      _addChatMessage('••••••', isUser: true, inputStep: _SignUpStep.password);
      _addChatMessage(l10n.authSignUpChatReady, isUser: false);
      _chatController.clear();
    }
  }

  Future<void> _createAccountFromChat() async {
    final l10n = AppLocalizations.of(context)!;

    if (!isSupabaseConfigured) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.authSupabaseNotConfigured)));
      return;
    }

    final authNotifier = ref.read(authProvider.notifier);
    final authPromptNotifier = ref.read(authPromptProvider.notifier);

    setState(() => _isSubmitting = true);
    try {
      await authNotifier.signUpWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;
      await authPromptNotifier.markCompleted();
      if (!mounted) return;
      context.go(RoutePaths.hub);
    } on Exception {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.authGenericError)));
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
        if (widget.isSignUp) return _buildSignUpChat(context, l10n, title);
        return _buildSignInForm(context, l10n, title);
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
      child: const AthlosAuthCheckingPanel(),
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

  Widget _buildSignInForm(
    BuildContext context,
    AppLocalizations l10n,
    String title,
  ) {
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
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(labelText: l10n.authEmailLabel),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (!email.contains('@')) return l10n.authEmailLabel;
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
                validator: (value) {
                  final password = value ?? '';
                  if (password.length < 6) return l10n.authPasswordMinHint;
                  return null;
                },
                onFieldSubmitted: (_) => _submitEmailForm(),
              ),
              const Gap(AthlosSpacing.xl),
              FilledButton(
                onPressed: _isSubmitting ? null : _submitEmailForm,
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
                    : () => context.push(RoutePaths.authSignUp),
                child: Text(l10n.authNoAccountAction),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignUpChat(
    BuildContext context,
    AppLocalizations l10n,
    String title,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
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
                AthlosSpacing.md,
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
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AthlosSpacing.md),
              child: _signUpStep == _SignUpStep.ready && _editingStep == null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton(
                          onPressed: _isSubmitting
                              ? null
                              : _createAccountFromChat,
                          child: _isSubmitting
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(l10n.authCreateAccountAction),
                        ),
                        const Gap(AthlosSpacing.sm),
                        TextButton(
                          onPressed: _isSubmitting
                              ? null
                              : () => context.go(RoutePaths.authSignIn),
                          child: Text(l10n.authHaveAccountAction),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _chatController,
                            enabled: !_isSubmitting,
                            obscureText: activeStep == _SignUpStep.password,
                            keyboardType: activeStep == _SignUpStep.email
                                ? TextInputType.emailAddress
                                : TextInputType.visiblePassword,
                            textInputAction: TextInputAction.send,
                            decoration: InputDecoration(
                              labelText: activeStep == _SignUpStep.email
                                  ? l10n.authEmailLabel
                                  : l10n.authPasswordLabel,
                            ),
                            onSubmitted: _handleChatInput,
                          ),
                        ),
                        const Gap(AthlosSpacing.sm),
                        IconButton.filledTonal(
                          onPressed: _isSubmitting
                              ? null
                              : () => _handleChatInput(_chatController.text),
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
        ],
      ),
    );
  }
}
