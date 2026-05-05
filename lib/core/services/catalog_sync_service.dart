import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/app_database.dart';
import '../providers/last_module_provider.dart';

part 'catalog_sync_service.g.dart';

const _catalogVersionKey = 'catalog_version';
const _governanceRulesVersionKey = 'catalog_governance_rules_version';

/// Syncs the verified catalog from Supabase into the local Drift database.
///
/// Only touches `isVerified = true` items — user-created data is never modified.
/// Fails silently so the app works fully offline.
class CatalogSyncService {
  final SupabaseClient _supabase;
  final AppDatabase _db;
  final SharedPreferences _prefs;

  CatalogSyncService(this._supabase, this._db, this._prefs);

  Future<void> sync() async {
    try {
      await _pushPendingGovernanceEvents();

      final remoteVersion = await _fetchRemoteVersion();
      if (remoteVersion != null) {
        final localVersion = _prefs.getInt(_catalogVersionKey) ?? 0;
        if (remoteVersion > localVersion) {
          await _syncExercises();
          await _syncTargetMuscles();
          await _prefs.setInt(_catalogVersionKey, remoteVersion);
          debugPrint('[CatalogSync] Synced to version $remoteVersion');
        }
      }

      await _applyGovernanceRules();
    } on Exception catch (e) {
      debugPrint('[CatalogSync] Failed silently: $e');
    }
  }

  Future<void> _pushPendingGovernanceEvents() async {
    final rows = await _db.customSelect(
      "SELECT * FROM catalog_governance_events WHERE status IN ('pending', 'failed') ORDER BY id ASC LIMIT 50",
    ).get();
    for (final row in rows) {
      final data = row.data;
      final localId = data['id'] as int?;
      final eventUuid = data['event_uuid']?.toString();
      if (localId == null || eventUuid == null) continue;
      try {
        await _supabase.from('catalog_governance_events').upsert({
          'event_uuid': eventUuid,
          'event_type': data['event_type'],
          'entity_type': data['entity_type'],
          'local_entity_id': data['local_entity_id'],
          'catalog_remote_id': data['catalog_remote_id'],
          'payload_json': data['payload_json'],
          'source': 'mobile_client',
        }, onConflict: 'event_uuid');
        await _db.customUpdate(
          'UPDATE catalog_governance_events SET status = ?, updated_at = ?, last_error = NULL WHERE id = ?',
          variables: [
            const Variable<String>('sent'),
            Variable<DateTime>(DateTime.now()),
            Variable<int>(localId),
          ],
        );
      } on Exception catch (e) {
        await _db.customUpdate(
          'UPDATE catalog_governance_events SET status = ?, retry_count = retry_count + 1, updated_at = ?, last_error = ? WHERE id = ?',
          variables: [
            const Variable<String>('failed'),
            Variable<DateTime>(DateTime.now()),
            Variable<String>(e.toString()),
            Variable<int>(localId),
          ],
        );
      }
    }
  }

  Future<void> _applyGovernanceRules() async {
    final localVersion = _prefs.getInt(_governanceRulesVersionKey) ?? 0;
    final rules = await _supabase
        .from('catalog_governance_rules')
        .select()
        .gt('rule_version', localVersion)
        .order('rule_version', ascending: true);
    if (rules.isEmpty) return;

    var maxVersion = localVersion;
    for (final rule in rules) {
      final remoteRuleId = rule['id']?.toString();
      final version = (rule['rule_version'] as num?)?.toInt();
      if (remoteRuleId == null || version == null) continue;
      final alreadyApplied = await _db.customSelect(
        "SELECT id FROM catalog_governance_applied_rules WHERE remote_rule_id = '${_esc(remoteRuleId)}' LIMIT 1",
      ).getSingleOrNull();
      if (alreadyApplied != null) {
        if (version > maxVersion) maxVersion = version;
        continue;
      }

      final entityType = rule['entity_type']?.toString();
      final action = rule['action']?.toString();
      final winnerRemoteId = rule['winner_remote_id']?.toString();
      final loserRemoteId = rule['loser_remote_id']?.toString();
      final payload = _parsePayloadMap(rule['payload_json']);
      final notes = rule['notes']?.toString();

      await _applyGovernanceRule(
        remoteRuleId: remoteRuleId,
        ruleVersion: version,
        entityType: entityType,
        action: action,
        winnerRemoteId: winnerRemoteId,
        loserRemoteId: loserRemoteId,
        payload: payload,
        notes: notes,
      );
      if (version > maxVersion) maxVersion = version;
    }

    if (maxVersion > localVersion) {
      await _prefs.setInt(_governanceRulesVersionKey, maxVersion);
    }
  }

  Future<void> _applyGovernanceRule({
    required String remoteRuleId,
    required int ruleVersion,
    required String? entityType,
    required String? action,
    required String? winnerRemoteId,
    required String? loserRemoteId,
    required Map<String, dynamic> payload,
    required String? notes,
  }) async {
    await _db.transaction(() async {
      if (action == 'merge_verified' &&
          winnerRemoteId != null &&
          loserRemoteId != null &&
          entityType == 'exercise') {
        const tableName = 'exercises';
        final winnerId = await _findVerifiedIdByRemoteId(tableName, winnerRemoteId);
        final loserId = await _findVerifiedIdByRemoteId(tableName, loserRemoteId);
        if (winnerId != null && loserId != null && winnerId != loserId) {
          await _remapReferences(entityType: entityType!, winnerId: winnerId, loserId: loserId);
        }
      }

      await _db.customInsert(
        'INSERT INTO catalog_governance_applied_rules (remote_rule_id, rule_version, status, notes) VALUES (?, ?, ?, ?)',
        variables: [
          Variable<String>(remoteRuleId),
          Variable<int>(ruleVersion),
          const Variable<String>('applied'),
          Variable<String>(notes ?? payload['notes']?.toString() ?? ''),
        ],
      );
    });
  }

  Future<int?> _findVerifiedIdByRemoteId(String tableName, String remoteId) async {
    final rows = await _db.customSelect(
      "SELECT id FROM $tableName WHERE is_verified = 1 AND catalog_remote_id = '${_esc(remoteId)}' LIMIT 1",
    ).get();
    if (rows.isEmpty) return null;
    return rows.first.data['id'] as int?;
  }

  Future<void> _remapReferences({
    required String entityType,
    required int winnerId,
    required int loserId,
  }) async {
    await _db.customStatement(
      'DELETE FROM workout_exercises WHERE exercise_id = $loserId AND EXISTS (SELECT 1 FROM workout_exercises we2 WHERE we2.workout_id = workout_exercises.workout_id AND we2.exercise_id = $winnerId)',
    );
    await _db.customStatement(
      'UPDATE workout_exercises SET exercise_id = $winnerId WHERE exercise_id = $loserId',
    );
    await _db.customStatement(
      'UPDATE execution_sets SET exercise_id = $winnerId WHERE exercise_id = $loserId',
    );
    await _db.customStatement(
      'DELETE FROM exercise_variations WHERE exercise_id = $loserId AND EXISTS (SELECT 1 FROM exercise_variations ev2 WHERE ev2.exercise_id = $winnerId AND ev2.variation_id = exercise_variations.variation_id)',
    );
    await _db.customStatement(
      'UPDATE exercise_variations SET exercise_id = $winnerId WHERE exercise_id = $loserId',
    );
    await _db.customStatement(
      'DELETE FROM exercise_variations WHERE variation_id = $loserId AND EXISTS (SELECT 1 FROM exercise_variations ev2 WHERE ev2.exercise_id = exercise_variations.exercise_id AND ev2.variation_id = $winnerId)',
    );
    await _db.customStatement(
      'UPDATE exercise_variations SET variation_id = $winnerId WHERE variation_id = $loserId',
    );
    await _db.customStatement(
      'DELETE FROM exercise_target_muscles WHERE exercise_id = $loserId '
      'AND EXISTS (SELECT 1 FROM exercise_target_muscles k '
      'WHERE k.exercise_id = $winnerId '
      'AND k.target_muscle = exercise_target_muscles.target_muscle)',
    );
    await _db.customStatement(
      'UPDATE exercise_target_muscles SET exercise_id = $winnerId WHERE exercise_id = $loserId',
    );
  }

  Map<String, dynamic> _parsePayloadMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return raw.cast<String, dynamic>();
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) return decoded;
      } on FormatException {
        return const {};
      }
    }
    return const {};
  }

  Future<int?> _fetchRemoteVersion() async {
    final data = await _supabase
        .from('catalog_version')
        .select('version')
        .order('version', ascending: false)
        .limit(1);
    if (data.isEmpty) return null;
    return data.first['version'] as int;
  }

  Future<void> _syncExercises() async {
    final rows = await _supabase.from('exercises').select();
    final localExercises = await _db.select(_db.exercises).get();
    final byRemoteId = {
      for (final item in localExercises)
        if (item.catalogRemoteId != null) item.catalogRemoteId!: item,
    };
    final byNormalizedName = {
      for (final item in localExercises) _normalizeName(item.name): item,
    };

    for (final row in rows) {
      final remoteId = row['id'].toString();
      final name = row['name'] as String;
      final existingByRemote = byRemoteId[remoteId];
      final existingByName = byNormalizedName[_normalizeName(name)];
      final existing = existingByRemote ?? existingByName;

      final muscleGroup = row['muscle_group'] as String;
      final type = row['type'] as String;
      final movementPattern = row['movement_pattern'] as String?;
      final description = row['description'] as String?;
      final mpSql =
          movementPattern != null ? "'$movementPattern'" : 'NULL';
      final descSql =
          description != null ? "'${_esc(description)}'" : 'NULL';

      if (existing == null) {
        await _db.customStatement(
          "INSERT INTO exercises (catalog_remote_id, name, muscle_group, type, movement_pattern, description, is_verified) "
          "VALUES ('$remoteId', '${_esc(name)}', '$muscleGroup', '$type', $mpSql, $descSql, 1)",
        );
      } else if (existing.isVerified) {
        await _db.customStatement(
          "UPDATE exercises SET catalog_remote_id = '$remoteId', name = '${_esc(name)}', movement_pattern = $mpSql, description = $descSql "
          "WHERE id = ${existing.id}",
        );
      }
    }
  }

  Future<void> _syncTargetMuscles() async {
    final rows = await _supabase.from('exercise_target_muscles').select(
        'exercise_id, target_muscle, muscle_region, role, exercises!inner(name)');

    final localExercises = await _db.select(_db.exercises).get();
    final nameToId = {for (final e in localExercises) e.name: e.id};

    for (final row in rows) {
      final exerciseName = row['exercises']['name'] as String;
      final localId = nameToId[exerciseName];
      if (localId == null) continue;

      final targetMuscle = row['target_muscle'] as String;
      final muscleRegion = row['muscle_region'] as String?;
      final role = row['role'] as String? ?? 'primary';
      final regionSql =
          muscleRegion != null ? "'$muscleRegion'" : 'NULL';

      await _db.customStatement(
        "INSERT OR IGNORE INTO exercise_target_muscles "
        "(exercise_id, target_muscle, muscle_region, role) "
        "VALUES ($localId, '$targetMuscle', $regionSql, '$role')",
      );
    }
  }

  String _esc(String s) => s.replaceAll("'", "''");
  String _normalizeName(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

@Riverpod(keepAlive: true)
CatalogSyncService catalogSyncService(Ref ref) {
  final supabase = Supabase.instance.client;
  final db = ref.watch(appDatabaseProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return CatalogSyncService(supabase, db, prefs);
}
