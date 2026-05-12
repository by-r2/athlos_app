import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/providers/last_module_provider.dart';

part 'auth_prompt_notifier.g.dart';

const _authPromptKey = 'auth_prompt_completed_2026_auth_sync_mvp';
const _cloudMigrationSkipPrefix = 'cloud_profile_migration_skipped_';

@Riverpod(keepAlive: true)
class AuthPromptNotifier extends _$AuthPromptNotifier {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(_authPromptKey) ?? false;
  }

  Future<void> markCompleted() async {
    await ref.read(sharedPreferencesProvider).setBool(_authPromptKey, true);
    state = true;
  }
}

@riverpod
bool cloudProfileMigrationSkipped(Ref ref, String userId) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getBool('$_cloudMigrationSkipPrefix$userId') ?? false;
}

@riverpod
class CloudProfileMigrationPrompt extends _$CloudProfileMigrationPrompt {
  @override
  bool build(String userId) =>
      ref.watch(cloudProfileMigrationSkippedProvider(userId));

  Future<void> skip() async {
    await ref
        .read(sharedPreferencesProvider)
        .setBool('$_cloudMigrationSkipPrefix$userId', true);
    state = true;
  }

  Future<void> reset() async {
    await ref
        .read(sharedPreferencesProvider)
        .remove('$_cloudMigrationSkipPrefix$userId');
    state = false;
  }
}
