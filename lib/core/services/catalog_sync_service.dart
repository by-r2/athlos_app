import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/app_database.dart';
import '../providers/last_module_provider.dart';

part 'catalog_sync_service.g.dart';

const _catalogVersionKey = 'catalog_version';

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
      final remoteVersion = await _fetchRemoteVersion();
      if (remoteVersion == null) return;

      final localVersion = _prefs.getInt(_catalogVersionKey) ?? 0;
      if (remoteVersion <= localVersion) return;

      await _syncEquipments();
      await _syncExercises();
      await _syncTargetMuscles();
      await _syncExerciseEquipments();

      await _prefs.setInt(_catalogVersionKey, remoteVersion);
      debugPrint('[CatalogSync] Synced to version $remoteVersion');
    } on Exception catch (e) {
      debugPrint('[CatalogSync] Failed silently: $e');
    }
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

  Future<void> _syncEquipments() async {
    final rows = await _supabase.from('equipments').select();
    for (final row in rows) {
      final name = row['name'] as String;
      final existing = await ((_db.select(_db.equipments))
            ..where((e) => e.name.equals(name)))
          .getSingleOrNull();

      if (existing == null) {
        final category = row['category'] as String;
        await _db.customStatement(
          "INSERT INTO equipments (name, category, is_verified) "
          "VALUES ('${_esc(name)}', '$category', 1)",
        );
      }
    }
  }

  Future<void> _syncExercises() async {
    final rows = await _supabase.from('exercises').select();
    for (final row in rows) {
      final name = row['name'] as String;
      final existing = await ((_db.select(_db.exercises))
            ..where((e) => e.name.equals(name)))
          .getSingleOrNull();

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
          "INSERT INTO exercises (name, muscle_group, type, movement_pattern, description, is_verified) "
          "VALUES ('${_esc(name)}', '$muscleGroup', '$type', $mpSql, $descSql, 1)",
        );
      } else if (existing.isVerified) {
        await _db.customStatement(
          "UPDATE exercises SET movement_pattern = $mpSql, description = $descSql "
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

  Future<void> _syncExerciseEquipments() async {
    final rows = await _supabase.from('exercise_equipments').select(
        'exercise_id, equipment_id, exercises!inner(name), equipments!inner(name)');

    final localExercises = await _db.select(_db.exercises).get();
    final exNameToId = {for (final e in localExercises) e.name: e.id};

    final localEquipments = await _db.select(_db.equipments).get();
    final eqNameToId = {for (final e in localEquipments) e.name: e.id};

    for (final row in rows) {
      final exName = row['exercises']['name'] as String;
      final eqName = row['equipments']['name'] as String;
      final localExId = exNameToId[exName];
      final localEqId = eqNameToId[eqName];
      if (localExId == null || localEqId == null) continue;

      await _db.customStatement(
        "INSERT OR IGNORE INTO exercise_equipments "
        "(exercise_id, equipment_id) VALUES ($localExId, $localEqId)",
      );
    }
  }

  String _esc(String s) => s.replaceAll("'", "''");
}

@Riverpod(keepAlive: true)
CatalogSyncService catalogSyncService(Ref ref) {
  final supabase = Supabase.instance.client;
  final db = ref.watch(appDatabaseProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return CatalogSyncService(supabase, db, prefs);
}
