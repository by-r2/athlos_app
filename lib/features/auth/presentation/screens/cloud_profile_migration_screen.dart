import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../profile/presentation/providers/profile_notifier.dart';
import '../providers/auth_notifier.dart';
import '../providers/auth_prompt_notifier.dart';

class CloudProfileMigrationScreen extends ConsumerStatefulWidget {
  const CloudProfileMigrationScreen({super.key});

  @override
  ConsumerState<CloudProfileMigrationScreen> createState() =>
      _CloudProfileMigrationScreenState();
}

class _CloudProfileMigrationScreenState
    extends ConsumerState<CloudProfileMigrationScreen> {
  bool _isSyncing = false;

  Future<void> _sync() async {
    final l10n = AppLocalizations.of(context)!;
    final user = ref.read(authProvider).value;
    if (user == null) return;

    setState(() => _isSyncing = true);
    try {
      await ref.read(profileProvider.notifier).syncLocalProfileToCloud();
      await ref.read(authPromptProvider.notifier).markCompleted();
      await ref
          .read(cloudProfileMigrationPromptProvider(user.id).notifier)
          .reset();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.authMigrationSuccess)));
      context.go(RoutePaths.hub);
    } on Exception {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.authGenericError)));
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _skip() async {
    final user = ref.read(authProvider).value;
    if (user != null) {
      await ref
          .read(cloudProfileMigrationPromptProvider(user.id).notifier)
          .skip();
    }
    await ref.read(authPromptProvider.notifier).markCompleted();
    if (mounted) context.go(RoutePaths.hub);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AthlosSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(
                Icons.cloud_upload_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const Gap(AthlosSpacing.lg),
              Text(
                l10n.authMigrationTitle,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const Gap(AthlosSpacing.md),
              Text(
                l10n.authMigrationSubtitle,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              FilledButton(
                onPressed: _isSyncing ? null : _sync,
                child: _isSyncing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.authMigrationSyncAction),
              ),
              const Gap(AthlosSpacing.sm),
              TextButton(
                onPressed: _isSyncing ? null : _skip,
                child: Text(l10n.authMigrationSkipAction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
