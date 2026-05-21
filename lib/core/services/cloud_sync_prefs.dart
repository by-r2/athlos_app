import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/last_module_provider.dart';

part 'cloud_sync_prefs.g.dart';

const _lastSuccessKey = 'cloud_sync_last_success_at';
const _lastAttemptKey = 'cloud_sync_last_attempt_at';

/// Persists user-visible cloud sync timestamps (device-local).
class CloudSyncPrefs {
  const CloudSyncPrefs(this._prefs);

  final SharedPreferences _prefs;

  DateTime? get lastSuccessAt => _parse(_prefs.getString(_lastSuccessKey));

  DateTime? get lastAttemptAt => _parse(_prefs.getString(_lastAttemptKey));

  Future<void> recordAttempt() => _write(_lastAttemptKey, DateTime.now().toUtc());

  Future<void> recordSuccess() async {
    final now = DateTime.now().toUtc();
    await _write(_lastSuccessKey, now);
    await _write(_lastAttemptKey, now);
  }

  Future<void> _write(String key, DateTime value) =>
      _prefs.setString(key, value.toIso8601String());

  static DateTime? _parse(String? raw) =>
      raw == null ? null : DateTime.tryParse(raw)?.toUtc();
}

@Riverpod(keepAlive: true)
CloudSyncPrefs cloudSyncPrefs(Ref ref) =>
    CloudSyncPrefs(ref.watch(sharedPreferencesProvider));
