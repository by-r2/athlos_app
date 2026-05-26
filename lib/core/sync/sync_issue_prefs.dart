import 'package:shared_preferences/shared_preferences.dart';

import '../utils/uuid.dart';
import 'sync_issue.dart';

const _issuesKey = 'sync_v2_issues';

/// Lightweight device-local storage for sync failures so we can show them
/// in a "sync issues center" UI.
class SyncIssuePrefs {
  const SyncIssuePrefs(this._prefs);

  final SharedPreferences _prefs;

  List<SyncIssue> getAll() {
    final raw = _prefs.getString(_issuesKey);
    if (raw == null || raw.trim().isEmpty) return const <SyncIssue>[];
    try {
      return SyncIssue.decodeList(raw);
    } on Exception {
      return const <SyncIssue>[];
    }
  }

  Future<void> add({
    required String tableName,
    required String message,
    int maxItems = 50,
  }) async {
    final now = DateTime.now().toUtc();
    final issues = getAll();
    final next = <SyncIssue>[
      SyncIssue(
        id: generateUuidV4(),
        occurredAtUtc: now,
        tableName: tableName,
        message: message,
      ),
      ...issues,
    ];
    await _prefs.setString(
      _issuesKey,
      SyncIssue.encodeList(next.take(maxItems).toList()),
    );
  }

  Future<void> clearAll() async {
    await _prefs.remove(_issuesKey);
  }

  Future<void> clearTable(String tableName) async {
    final issues = getAll();
    final filtered = issues.where((e) => e.tableName != tableName).toList();
    await _prefs.setString(_issuesKey, SyncIssue.encodeList(filtered));
  }
}

