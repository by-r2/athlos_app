import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sync_adapter.dart';
import 'sync_issue_prefs.dart';

/// Single-pass sync engine: push dirty → push tombstones → pull newer.
///
/// Each table gets one pass. No retry loops, no FK resolution —
/// all FKs are stable UUIDs generated client-side.
class SyncEngineV2 {
  SyncEngineV2({
    required List<SyncAdapter<dynamic>> adapters,
    required SharedPreferences prefs,
    SyncIssuePrefs? issuePrefs,
  })  : _adapters = adapters,
        _prefs = prefs,
        _issuePrefs = issuePrefs;

  final List<SyncAdapter<dynamic>> _adapters;
  final SharedPreferences _prefs;
  final SyncIssuePrefs? _issuePrefs;

  Future<void> synchronize() async {
    for (final adapter in _adapters) {
      await _syncTable(adapter);
    }
  }

  Future<void> synchronizeTable(String tableName) async {
    final adapter = _adapters
        .cast<SyncAdapter<dynamic>?>()
        .firstWhere((a) => a?.tableName == tableName, orElse: () => null);
    if (adapter == null) return;
    await _syncTable(adapter);
  }

  Future<void> _syncTable<T>(SyncAdapter<T> adapter) async {
    try {
      final dirty = await adapter.loadDirty();
      if (dirty.isNotEmpty) {
        await adapter.pushToRemote(dirty);
        await adapter.markClean(dirty.map(adapter.getId).toList());
      }

      final tombstones = await adapter.loadDirtyTombstones();
      if (tombstones.isNotEmpty) {
        await adapter.pushDeletes(tombstones);
        await adapter.hardDelete(tombstones.map(adapter.getId).toList());
      }

      final lastPullAt = _getLastPullAt(adapter.tableName);
      final remoteRows = await adapter.pullFromRemote(lastPullAt);
      if (remoteRows.isNotEmpty) {
        await adapter.applyRemoteRows(remoteRows);
      }

      await _setLastPullAt(adapter.tableName, DateTime.now());
      try {
        await _issuePrefs?.clearTable(adapter.tableName);
      } on Exception {
        // ignore
      }
    } on Exception catch (e) {
      debugPrint('[SyncV2] ${adapter.tableName} failed: $e');
      // Best-effort issue recording (must never crash sync).
      try {
        await _issuePrefs?.add(tableName: adapter.tableName, message: '$e');
      } on Exception {
        // ignore
      }
    }
  }

  DateTime _getLastPullAt(String tableName) {
    final ms = _prefs.getInt('sync_last_pull_$tableName');
    if (ms == null) return DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> _setLastPullAt(String tableName, DateTime time) async {
    await _prefs.setInt(
      'sync_last_pull_$tableName',
      time.millisecondsSinceEpoch,
    );
  }
}
