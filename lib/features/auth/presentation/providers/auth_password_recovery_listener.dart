import 'dart:async';

import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../../core/errors/result.dart';
import '../../../../core/services/supabase_config.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/repositories/auth_providers.dart';

part 'auth_password_recovery_listener.g.dart';

/// Shows a dialog to set a new password when the user opens the recovery deep link.
@Riverpod(keepAlive: true)
void authPasswordRecoveryListener(Ref ref) {
  if (!isSupabaseConfigured) return;

  final subscription = supabase.Supabase.instance.client.auth.onAuthStateChange
      .listen(
    (data) {
      if (data.event != supabase.AuthChangeEvent.passwordRecovery) return;

      final context =
          ref.read(passwordRecoveryNavigatorKeyProvider).currentContext;
      if (context == null || !context.mounted) return;

      unawaited(
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => _SetNewPasswordDialog(authRef: ref),
        ),
      );
    },
    onError: (Object error, StackTrace stackTrace) {
      debugPrint('[Auth] deep link error: $error');
      _showRecoveryLinkError(ref, error);
    },
  );

  ref.onDispose(subscription.cancel);
}

void _showRecoveryLinkError(Ref ref, Object error) {
  final context = ref.read(passwordRecoveryNavigatorKeyProvider).currentContext;
  if (context == null || !context.mounted) return;

  final l10n = AppLocalizations.of(context)!;
  final message = error is supabase.AuthException &&
          (error.code == 'access_denied' ||
              error.statusCode == 'otp_expired' ||
              error.message.toLowerCase().contains('expired') ||
              error.message.toLowerCase().contains('invalid'))
      ? l10n.authRecoveryLinkExpired
      : l10n.authGenericError;

  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// Navigator key owned by [appRouter] for auth recovery dialogs.
@Riverpod(keepAlive: true)
GlobalKey<NavigatorState> passwordRecoveryNavigatorKey(Ref ref) =>
    GlobalKey<NavigatorState>();

class _SetNewPasswordDialog extends StatefulWidget {
  const _SetNewPasswordDialog({required this.authRef});

  final Ref authRef;

  @override
  State<_SetNewPasswordDialog> createState() => _SetNewPasswordDialogState();
}

class _SetNewPasswordDialogState extends State<_SetNewPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final result = await widget.authRef
          .read(authRepositoryProvider)
          .updatePassword(newPassword: _passwordController.text);
      result.getOrThrow();
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.authPasswordResetSuccess)),
      );
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.authPasswordResetError)),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(l10n.authPasswordResetTitle),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.authPasswordResetDescription),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(labelText: l10n.authPasswordLabel),
              validator: (value) {
                if ((value ?? '').length < 6) return l10n.authPasswordMinHint;
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmController,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: l10n.authPasswordConfirmLabel,
              ),
              validator: (value) {
                if (value != _passwordController.text) {
                  return l10n.authPasswordConfirmMismatch;
                }
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.authPasswordResetSaveAction),
          ),
        ),
      ],
    );
  }
}
