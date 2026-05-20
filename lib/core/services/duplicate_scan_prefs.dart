import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/last_module_provider.dart';

part 'duplicate_scan_prefs.g.dart';

const _lastAnalyzedKey = 'duplicate_scan_last_analyzed_at';

/// Persists when duplicate detection last ran (device-local).
class DuplicateScanPrefs {
  const DuplicateScanPrefs(this._prefs);

  final SharedPreferences _prefs;

  DateTime? get lastAnalyzedAt => _parse(_prefs.getString(_lastAnalyzedKey));

  Future<void> recordAnalysis() =>
      _prefs.setString(_lastAnalyzedKey, DateTime.now().toUtc().toIso8601String());

  static DateTime? _parse(String? raw) =>
      raw == null ? null : DateTime.tryParse(raw)?.toUtc();
}

@Riverpod(keepAlive: true)
DuplicateScanPrefs duplicateScanPrefs(Ref ref) =>
    DuplicateScanPrefs(ref.watch(sharedPreferencesProvider));
