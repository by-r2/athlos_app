import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/providers/last_module_provider.dart';

part 'auth_prompt_notifier.g.dart';

const _localAccessAcceptedKey = 'local_access_accepted_v1';

@Riverpod(keepAlive: true)
class LocalAccess extends _$LocalAccess {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(_localAccessAcceptedKey) ?? false;
  }

  Future<void> accept() async {
    await ref
        .read(sharedPreferencesProvider)
        .setBool(_localAccessAcceptedKey, true);
    state = true;
  }

  Future<void> reset() async {
    await ref.read(sharedPreferencesProvider).remove(_localAccessAcceptedKey);
    state = false;
  }
}
