import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:math' as math;
import 'dart:ui' show Locale;

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../database/app_database.dart';
import '../../database/exercise_migration_maps.dart';
import '../../localization/domain_label_resolver.dart';
import '../../localization/exercise_catalog_label_index.dart';
import '../../localization/exercise_label_normalization.dart';
import '../../domain/entities/local_backup_models.dart';
import '../../domain/repositories/local_backup_repository.dart';
import '../../errors/app_exception.dart';
import '../../errors/result.dart';
import '../../../l10n/app_localizations.dart';

const _backupFormatVersion = 2;
const _fuzzyThreshold = 0.84;
const _strongMatchThreshold = 0.96;
const _profileComparableKeys = <String>{
  'name',
  'height',
  'age',
  'goal',
  'body_aesthetic',
  'training_style',
  'experience_level',
  'gender',
  'training_frequency',
  'available_workout_minutes',
  'trains_at_gym',
  'injuries',
  'bio',
  'owned_equipment_names',
};

const _tableUserProfiles = 'user_profiles';
const _tableEquipments = 'equipments';
const _tableExercises = 'exercises';
const _tableExerciseEquipments = 'exercise_equipments';
const _tableExerciseTargetMuscles = 'exercise_target_muscles';
const _tableExerciseVariations = 'exercise_variations';
const _tableWorkouts = 'workouts';
const _tableWorkoutExercises = 'workout_exercises';
const _tableWorkoutExecutions = 'workout_executions';
const _tableExecutionSets = 'execution_sets';
const _tableExecutionSetSegments = 'execution_set_segments';
const _tableCycleSteps = 'cycle_steps';
const _tablePrograms = 'programs';
const _tableProgressionRules = 'progression_rules';
const _tableBodyMetrics = 'body_metrics';
const _tableUserEquipments = 'user_equipments';
const _tableCatalogGovernanceEvents = 'catalog_governance_events';
const _tableLocalDuplicateFeedback = 'local_duplicate_feedback';

const _tableCatalogReferences = 'catalogReferences';
const _catalogEquipments = 'equipments';
const _catalogExercises = 'exercises';

final AppLocalizations _ptBrL10n = lookupAppLocalizations(const Locale('pt'));
final DomainLabelResolver _domainLabelResolver = DomainLabelResolver(_ptBrL10n);

class LocalBackupRepositoryImpl implements LocalBackupRepository {
  final AppDatabase _db;

  LocalBackupRepositoryImpl(this._db);


  @override
  Future<Result<List<BackupPendingReview>>> scanRuntimeLocalDuplicates() async {
    try {
      final pending = <BackupPendingReview>[];
      pending.addAll(
        await _scanRuntimeDuplicatesForTable(
          tableName: _tableExercises,
          entityType: BackupConflictType.exercise,
          reviewPrefix: 'runtime_exercise',
        ),
      );
      return Success(pending);
    } on Exception catch (e) {
      return Failure(
        DatabaseException('Failed to scan runtime duplicates: $e'),
      );
    }
  }

  @override
  Future<Result<void>> resolveRuntimeDuplicate({
    required BackupConflictType entityType,
    required int leftEntityId,
    required int rightEntityId,
    required RuntimeDuplicateDecision decision,
    int? winnerId,
    Map<String, dynamic>? mergedAttributes,
  }) async {
    if (leftEntityId == rightEntityId) {
      return const Failure(ValidationException('Invalid duplicate pair.'));
    }

    final tableName = _runtimeConflictTable(entityType);
    if (tableName == null) {
      return const Failure(
        ValidationException('Entity type does not support runtime merge.'),
      );
    }

    try {
      final rows = await _db
          .customSelect(
            'SELECT id, name, is_verified FROM $tableName WHERE id IN (?, ?)',
            variables: [
              Variable<int>(leftEntityId),
              Variable<int>(rightEntityId),
            ],
          )
          .get();
      if (rows.length != 2) {
        return const Failure(NotFoundException('Duplicate pair not found.'));
      }

      final left = rows
          .firstWhere((r) => _asInt(r.data['id']) == leftEntityId)
          .data;
      final right = rows
          .firstWhere((r) => _asInt(r.data['id']) == rightEntityId)
          .data;

      final bothVerified =
          _asBool(left['is_verified']) && _asBool(right['is_verified']);

      final leftFingerprint = _buildDuplicateFingerprint(
        tableName: tableName,
        label: left['name']?.toString() ?? '',
      );
      final rightFingerprint = _buildDuplicateFingerprint(
        tableName: tableName,
        label: right['name']?.toString() ?? '',
      );

      if (decision == RuntimeDuplicateDecision.notDuplicate) {
        await _saveRuntimePairSuppression(
          entityType: entityType,
          leftFingerprint: leftFingerprint,
          rightFingerprint: rightFingerprint,
        );
        return const Success(null);
      }

      if (bothVerified) {
        return const Failure(
          ValidationException(
            'Cannot merge two verified catalog entries. '
            'Only a developer can modify the catalog.',
          ),
        );
      }

      final resolvedWinnerId =
          winnerId ?? _autoPickWinner(left, right, leftEntityId, rightEntityId);
      final loserId = resolvedWinnerId == leftEntityId
          ? rightEntityId
          : leftEntityId;

      await _db.transaction(() async {
        if (decision == RuntimeDuplicateDecision.mergeAttributes &&
            mergedAttributes != null) {
          await _applyMergedAttributes(
            tableName: tableName,
            entityId: resolvedWinnerId,
            attributes: mergedAttributes,
          );
          await _unifyJunctionTables(
            tableName: tableName,
            winnerId: resolvedWinnerId,
            loserId: loserId,
          );
        }

        await _mergeLocalLoserIntoWinner(
          tableName: tableName,
          loserId: loserId,
          winnerId: resolvedWinnerId,
        );
        await _deleteRuntimePairSuppression(
          entityType: entityType,
          leftFingerprint: leftFingerprint,
          rightFingerprint: rightFingerprint,
        );
      });

      return const Success(null);
    } on AppException catch (e) {
      return Failure(e);
    } on Exception catch (e) {
      return Failure(
        DatabaseException('Failed to resolve runtime duplicate: $e'),
      );
    }
  }

  int _autoPickWinner(
    Map<String, dynamic> left,
    Map<String, dynamic> right,
    int leftId,
    int rightId,
  ) {
    final leftVerified = _asBool(left['is_verified']);
    final rightVerified = _asBool(right['is_verified']);
    if (leftVerified && !rightVerified) return leftId;
    if (rightVerified && !leftVerified) return rightId;
    return leftId;
  }

  Future<void> _applyMergedAttributes({
    required String tableName,
    required int entityId,
    required Map<String, dynamic> attributes,
  }) async {
    if (attributes.isEmpty) return;
    final allowedColumns = _editableColumns(tableName);
    final setClauses = <String>[];
    final variables = <Variable<Object>>[];
    for (final entry in attributes.entries) {
      if (!allowedColumns.contains(entry.key)) continue;
      setClauses.add('"${entry.key}" = ?');
      variables.add(Variable<String>(entry.value?.toString() ?? ''));
    }
    if (setClauses.isEmpty) return;
    variables.add(Variable<int>(entityId));
    await _db.customUpdate(
      'UPDATE "$tableName" SET ${setClauses.join(', ')} WHERE id = ?',
      variables: variables,
    );
  }

  Set<String> _editableColumns(String tableName) {
    if (tableName == _tableExercises) {
      return const {
        'name',
        'description',
        'muscle_group',
        'type',
        'movement_pattern',
      };
    }
    return const {};
  }

  Future<void> _unifyJunctionTables({
    required String tableName,
    required int winnerId,
    required int loserId,
  }) async {
    if (tableName == _tableExercises) {
      await _db.customStatement(
        'INSERT OR IGNORE INTO "$_tableExerciseTargetMuscles" '
        '(exercise_id, target_muscle, muscle_region, role) '
        'SELECT $winnerId, target_muscle, muscle_region, role '
        'FROM "$_tableExerciseTargetMuscles" WHERE exercise_id = $loserId',
      );
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> loadEntityAttributes({
    required BackupConflictType entityType,
    required int entityId,
  }) async {
    final tableName = _runtimeConflictTable(entityType);
    if (tableName == null) {
      return const Failure(ValidationException('Entity type not supported.'));
    }
    try {
      final rows = await _db
          .customSelect(
            'SELECT * FROM "$tableName" WHERE id = ?',
            variables: [Variable<int>(entityId)],
          )
          .get();
      if (rows.isEmpty) {
        return const Failure(NotFoundException('Entity not found.'));
      }
      return Success(Map<String, dynamic>.from(rows.first.data));
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to load entity: $e'));
    }
  }

  Future<_CanonicalResolutionResult> _resolveCanonicalReferences({
    required _BackupParsedPayload payload,
    required BackupImportRequest request,
  }) async {
    final equipmentIdMap = <int, int>{};
    final exerciseIdMap = <int, int>{};
    var unresolvedCount = 0;

    final exerciseRefs =
        payload.catalogReferences[_catalogExercises] ?? const [];

    final verifiedExercises = await _fetchVerifiedRows(_tableExercises);

    for (final ref in exerciseRefs) {
      final resolved = await _resolveCatalogReference(
        ref: ref,
        tableName: _tableExercises,
        entityType: BackupConflictType.exercise,
        verifiedRows: verifiedExercises,
        request: request,
      );
      if (resolved == null) {
        unresolvedCount++;
        continue;
      }
      exerciseIdMap[ref.localId] = resolved;
    }

    return _CanonicalResolutionResult(
      equipmentIdMap: equipmentIdMap,
      exerciseIdMap: exerciseIdMap,
      unresolvedCount: unresolvedCount,
    );
  }

  Future<int?> _resolveCatalogReference({
    required BackupCatalogReference ref,
    required String tableName,
    required BackupConflictType entityType,
    required List<Map<String, dynamic>> verifiedRows,
    required BackupImportRequest request,
  }) async {
    if (ref.catalogRemoteId.isNotEmpty) {
      final byRemote = verifiedRows.firstWhere(
        (row) => row['catalog_remote_id']?.toString() == ref.catalogRemoteId,
        orElse: () => const {},
      );
      if (byRemote.isNotEmpty) return _asInt(byRemote['id']);
    }

    final List<Map<String, dynamic>> suggestions;
    if (tableName == _tableExercises) {
      final trimmed = ref.name.trim();
      final byDirect = _exerciseRowIdByExactName(verifiedRows, trimmed);
      if (byDirect != null) return byDirect;
      final byMigrated = _exerciseRowIdByExactName(
        verifiedRows,
        resolveImportedExerciseCatalogName(ref.name),
      );
      if (byMigrated != null) return byMigrated;
      suggestions = _topFuzzyBackedUpExerciseNameCandidates(
        ref.name,
        verifiedRows,
        limit: 1,
      );
    } else {
      suggestions = _topFuzzyCandidates(ref.name, verifiedRows, limit: 1);
    }

    final bestScore = suggestions.isEmpty
        ? -1.0
        : suggestions.first['score'] as double;

    if (suggestions.isNotEmpty && bestScore >= _strongMatchThreshold) {
      return _asInt(suggestions.first['id']);
    }

    final pendingId = 'missing_${entityType.name}_${ref.localId}';
    final resolution = request.pendingReviewResolutions[pendingId];

    if (resolution == BackupPendingReviewResolution.linkSuggested &&
        suggestions.isNotEmpty) {
      return _asInt(suggestions.first['id']);
    }

    if (resolution == BackupPendingReviewResolution.createCustom) {
      return _insertRow(
        tableName,
        ref.fallbackData,
        excludeKeys: const {'id', 'catalog_remote_id'},
      );
    }

    return null;
  }

  Future<_ImportCatalogResult> _importCustomCatalogRows({
    required List<Map<String, dynamic>> rows,
    required String tableName,
    required String conflictPrefix,
    required String pendingPrefix,
    required String nameField,
    required BackupConflictType entityType,
    required Map<int, int> idMap,
    required BackupImportRequest request,
  }) async {
    var createdCount = 0;
    var updatedCount = 0;
    var skippedCount = 0;
    var failedCount = 0;

    final existingRows = await _fetchTableRows(tableName);
    final localVerifiedCatalog = tableName == _tableExercises
        ? await _fetchVerifiedRows(tableName)
        : const <Map<String, dynamic>>[];
    final byNormalized = <String, Map<String, dynamic>>{};
    for (final existing in existingRows) {
      final existingName = existing[nameField] as String?;
      if (existingName == null || existingName.trim().isEmpty) continue;
      byNormalized[_normalizeName(existingName)] = existing;
    }

    for (final row in rows) {
      final oldId = _asInt(row['id']);

      if (tableName == _tableExercises && _asBool(row['is_verified'])) {
        if (oldId == null) {
          failedCount++;
          continue;
        }
        final linked =
            idMap[oldId] ??
            _linkVerifiedImportedExerciseToLocalCatalog(
              importedRow: row,
              localVerifiedCatalog: localVerifiedCatalog,
            );
        if (linked != null) {
          idMap[oldId] = linked;
          skippedCount++;
        } else {
          failedCount++;
        }
        continue;
      }

      final name = (row[nameField] as String?)?.trim();
      if (oldId == null || name == null || name.isEmpty) {
        failedCount++;
        continue;
      }

      final normalized = _normalizeName(name);
      final match = _findBestCatalogMatch(
        tableName: tableName,
        importedRow: row,
        importedName: name,
        existingRows: existingRows,
      );
      if (match != null) {
        final existing = match.row;
        final existingId = _asInt(existing['id']);
        if (existingId == null) {
          failedCount++;
          continue;
        }

        final importedIsVerified = _asBool(row['is_verified']);
        final existingIsVerified = _asBool(existing['is_verified']);

        if (importedIsVerified && existingIsVerified) {
          final sameRemoteId =
              row['catalog_remote_id']?.toString().isNotEmpty == true &&
              row['catalog_remote_id']?.toString() ==
                  existing['catalog_remote_id']?.toString();
          if (!sameRemoteId) {
            final pendingId = 'governance_${entityType.name}_$oldId';
            final resolution =
                request.pendingReviewResolutions[pendingId] ??
                BackupPendingReviewResolution.skip;
            if (resolution == BackupPendingReviewResolution.skip) {
              await _enqueueGovernanceEvent(
                eventUuid: 'import_conflict_${entityType.name}_$oldId',
                eventType: 'verified_vs_verified_conflict',
                entityType: entityType.name,
                localEntityId: existingId,
                catalogRemoteId: existing['catalog_remote_id']?.toString(),
                payload: {
                  'imported': row,
                  'existing': existing,
                  'reason':
                      'same_name_or_semantic_match_with_different_remote_id',
                },
              );
              failedCount++;
              continue;
            }
          }

          final mergedRow = _mergeRowPreservingPrecedence(
            existingRow: existing,
            importedRow: row,
            keepExistingValues: true,
          );
          await _updateRowById(
            tableName,
            existingId,
            mergedRow,
            excludeKeys: const {'id'},
          );
          idMap[oldId] = existingId;
          updatedCount++;
          continue;
        }

        if (importedIsVerified != existingIsVerified) {
          final pendingId = 'verified_confirm_${entityType.name}_$oldId';
          final resolution =
              request.pendingReviewResolutions[pendingId] ??
              BackupPendingReviewResolution.createCustom;
          if (resolution == BackupPendingReviewResolution.linkSuggested) {
            idMap[oldId] = existingId;
            skippedCount++;
            final duplicateCustomId = _findDuplicateCustomByName(
              rows: existingRows,
              normalizedName: normalized,
              winnerId: existingId,
            );
            if (duplicateCustomId != null) {
              await _mergeLocalLoserIntoWinner(
                tableName: tableName,
                loserId: duplicateCustomId,
                winnerId: existingId,
              );
              updatedCount++;
            }
            continue;
          }
          if (resolution == BackupPendingReviewResolution.skip) {
            skippedCount++;
            continue;
          }
          // `createCustom` keeps both items by inserting imported as non-verified.
          final uniqueName = _buildUniqueName(
            name,
            byNormalized.map(
              (key, value) => MapEntry(key, _asInt(value['id'])!),
            ),
          );
          final nextRow = Map<String, dynamic>.from(row)
            ..[nameField] = uniqueName
            ..['is_verified'] = 0
            ..remove('catalog_remote_id');
          final newId = await _insertRow(
            tableName,
            nextRow,
            excludeKeys: const {'id'},
          );
          idMap[oldId] = newId;
          byNormalized[_normalizeName(uniqueName)] = nextRow..['id'] = newId;
          existingRows.add(nextRow);
          createdCount++;
          continue;
        }

        // Both non-verified: auto-merge when confidence is high.
        if (match.isStrong) {
          final mergedRow = _mergeRowPreservingPrecedence(
            existingRow: existing,
            importedRow: row,
            keepExistingValues: true,
          );
          await _updateRowById(
            tableName,
            existingId,
            mergedRow,
            excludeKeys: const {'id'},
          );
          idMap[oldId] = existingId;
          updatedCount++;
          continue;
        }

        final pendingId = '${pendingPrefix}_$oldId';
        final pendingResolution =
            request.pendingReviewResolutions[pendingId] ??
            BackupPendingReviewResolution.createCustom;
        if (pendingResolution == BackupPendingReviewResolution.linkSuggested) {
          idMap[oldId] = existingId;
          skippedCount++;
          continue;
        }
        if (pendingResolution == BackupPendingReviewResolution.skip) {
          skippedCount++;
          continue;
        }
      } else {
        final fuzzy = tableName == _tableExercises
            ? _topFuzzyExerciseCandidates(
                name,
                existingRows,
                limit: 1,
                restrictVerifiedToCanonical:
                    _exerciseRestrictVerifiedCanonicalForImportLabel(name),
              )
            : _topFuzzyCandidates(name, existingRows, limit: 1);
        if (fuzzy.isNotEmpty && fuzzy.first['score'] >= _fuzzyThreshold) {
          final pendingId = '${pendingPrefix}_$oldId';
          final pendingResolution =
              request.pendingReviewResolutions[pendingId] ??
              BackupPendingReviewResolution.createCustom;
          if (pendingResolution ==
              BackupPendingReviewResolution.linkSuggested) {
            final suggestedId = _asInt(fuzzy.first['id']);
            if (suggestedId != null) {
              idMap[oldId] = suggestedId;
              skippedCount++;
              continue;
            }
          }
          if (pendingResolution == BackupPendingReviewResolution.skip) {
            skippedCount++;
            continue;
          }
        }
      }

      final newId = await _insertRow(tableName, row, excludeKeys: const {'id'});
      idMap[oldId] = newId;
      final insertedRow = Map<String, dynamic>.from(row)..['id'] = newId;
      existingRows.add(insertedRow);
      byNormalized[_normalizeName(name)] = insertedRow;
      createdCount++;
    }

    return _ImportCatalogResult(
      createdCount: createdCount,
      updatedCount: updatedCount,
      skippedCount: skippedCount,
      failedCount: failedCount,
    );
  }

  Future<List<BackupImportConflict>> _scanConflicts(
    Map<String, List<Map<String, dynamic>>> tables,
  ) async {
    final conflicts = <BackupImportConflict>[];

    final importedProfiles = tables[_tableUserProfiles] ?? const [];
    if (importedProfiles.isNotEmpty) {
      final existingProfiles = await _fetchTableRows(_tableUserProfiles);
      if (existingProfiles.isNotEmpty) {
        final imported = importedProfiles.first;
        final existing = existingProfiles.first;
        for (final key in _profileComparableKeys) {
          final importedValue = imported[key];
          final existingValue = existing[key];
          if (_areProfileFieldValuesEquivalent(
            key: key,
            importedValue: importedValue,
            existingValue: existingValue,
          )) {
            continue;
          }
          final importedEmpty = _isProfileValueEmpty(importedValue);
          final existingEmpty = _isProfileValueEmpty(existingValue);
          if (importedEmpty || existingEmpty) continue;
          conflicts.add(
            BackupImportConflict(
              conflictId: 'profile:$key',
              type: BackupConflictType.profile,
              existingLabel:
                  '${_profileFieldLabel(key)}: ${_formatProfileConflictValue(existingValue)}',
              importedLabel:
                  '${_profileFieldLabel(key)}: ${_formatProfileConflictValue(importedValue)}',
              allowedResolutions: const [
                BackupConflictResolution.keepExisting,
                BackupConflictResolution.overwriteExisting,
              ],
            ),
          );
        }
      }
    }

    conflicts.addAll(
      await _scanNamedConflicts(
        importedRows: tables[_tableWorkouts] ?? const [],
        tableName: _tableWorkouts,
        type: BackupConflictType.workout,
        idPrefix: 'workout',
      ),
    );

    return conflicts;
  }

  bool _areProfileFieldValuesEquivalent({
    required String key,
    required dynamic importedValue,
    required dynamic existingValue,
  }) {
    final left = _normalizeProfileFieldValue(key, importedValue);
    final right = _normalizeProfileFieldValue(key, existingValue);
    return left == right;
  }

  bool _isProfileValueEmpty(dynamic value) =>
      _normalizeProfileValue(value) == null;

  Object? _normalizeProfileFieldValue(String key, dynamic value) {
    if (key == 'trains_at_gym') {
      // In practice, null and false both represent "not enabled" in profile flow.
      if (value == null) return '0';
      final asBool = _asBool(value);
      return asBool ? '1' : '0';
    }
    if (key == 'name' || key == 'injuries' || key == 'bio') {
      if (value == null) return null;
      final normalized = value.toString().trim();
      if (normalized.isEmpty) return null;
      return _normalizeName(normalized);
    }
    return _normalizeProfileValue(value);
  }

  Object? _normalizeProfileValue(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final normalized = value.trim();
      return normalized.isEmpty ? null : normalized;
    }
    if (value is bool) return value ? '1' : '0';
    if (value is DateTime) return value.toIso8601String();
    if (value is num) {
      if (value % 1 == 0) return value.toInt().toString();
      return value.toDouble().toString();
    }
    return value.toString();
  }

  String _profileFieldLabel(String key) {
    switch (key) {
      case 'name':
        return 'Nome';
      case 'weight':
        return 'Peso';
      case 'height':
        return 'Altura';
      case 'age':
        return 'Idade';
      case 'goal':
        return 'Objetivo';
      case 'body_aesthetic':
        return 'Estetica';
      case 'training_style':
        return 'Estilo de treino';
      case 'experience_level':
        return 'Nivel de experiencia';
      case 'gender':
        return 'Genero';
      case 'training_frequency':
        return 'Frequencia de treino';
      case 'available_workout_minutes':
        return 'Minutos disponiveis';
      case 'trains_at_gym':
        return 'Treina em academia';
      case 'injuries':
        return 'Lesoes';
      case 'bio':
        return 'Bio';
      case 'owned_equipment_names':
        return 'Equipamento proprio';
      default:
        return key;
    }
  }

  String _formatProfileConflictValue(dynamic value) {
    if (value == null) return '-';
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? '-' : trimmed;
    }
    if (value is bool) return value ? 'true' : 'false';
    return value.toString();
  }

  Future<List<BackupImportConflict>> _scanNamedConflicts({
    required List<Map<String, dynamic>> importedRows,
    required String tableName,
    required BackupConflictType type,
    required String idPrefix,
  }) async {
    final conflicts = <BackupImportConflict>[];
    final existingRows = await _fetchTableRows(tableName);
    final existingByName = <String, Map<String, dynamic>>{};
    for (final existing in existingRows) {
      final existingName = (existing['name'] as String?)?.trim();
      if (existingName == null || existingName.isEmpty) continue;
      existingByName[_normalizeName(existingName)] = existing;
    }
    for (final row in importedRows) {
      final id = _asInt(row['id']);
      final name = (row['name'] as String?)?.trim();
      if (id == null || name == null || name.isEmpty) continue;
      final existing = existingByName[_normalizeName(name)];
      if (existing == null) continue;

      if (tableName == _tableWorkouts &&
          _workoutsAreEquivalent(imported: row, existing: existing)) {
        continue;
      }

      conflicts.add(
        BackupImportConflict(
          conflictId: '$idPrefix:$id',
          type: type,
          existingLabel: (existing['name'] as String?) ?? name,
          importedLabel: name,
          allowedResolutions: const [
            BackupConflictResolution.keepExisting,
            BackupConflictResolution.overwriteExisting,
            BackupConflictResolution.keepBoth,
          ],
        ),
      );
    }
    return conflicts;
  }

  bool _workoutsAreEquivalent({
    required Map<String, dynamic> imported,
    required Map<String, dynamic> existing,
  }) {
    final keys = <String>{'name', 'description', 'is_archived', 'sort_order'};
    for (final key in keys) {
      final left = _normalizeProfileValue(imported[key]);
      final right = _normalizeProfileValue(existing[key]);
      if (left != right) return false;
    }
    return true;
  }

  Future<List<BackupPendingReview>> _scanPendingReviews(
    _BackupParsedPayload payload,
  ) async {
    final pending = <BackupPendingReview>[];
    final verifiedExercises = await _fetchVerifiedRows(_tableExercises);

    final exerciseRefs =
        payload.catalogReferences[_catalogExercises] ?? const [];
    for (final ref in exerciseRefs) {
      if (ref.catalogRemoteId.isNotEmpty) {
        final byRemote = verifiedExercises.any(
          (row) => row['catalog_remote_id']?.toString() == ref.catalogRemoteId,
        );
        if (byRemote) continue;
      }

      if (_verifiedExercisesContainBackedUpLabel(verifiedExercises, ref.name)) {
        continue;
      }

      final suggestion = _topFuzzyBackedUpExerciseNameCandidates(
        ref.name,
        verifiedExercises,
        limit: 1,
      );
      final score = suggestion.isEmpty
          ? -1.0
          : suggestion.first['score'] as double;
      if (suggestion.isNotEmpty && score >= _strongMatchThreshold) {
        continue;
      }
      pending.add(
        BackupPendingReview(
          reviewId: 'missing_exercise_${ref.localId}',
          type: BackupPendingReviewType.missingCanonicalReference,
          decisionScope: BackupConflictDecisionScope.userLocal,
          detectedFrom: BackupConflictDetectedFrom.importPreview,
          entityType: BackupConflictType.exercise,
          importedLabel: ref.name,
          suggestedLabel: suggestion.isNotEmpty
              ? suggestion.first['name'] as String?
              : null,
          similarityScore: suggestion.isNotEmpty
              ? suggestion.first['score'] as double
              : null,
        ),
      );
    }

    pending.addAll(
      await _scanCatalogImportReviews(
        tableName: _tableExercises,
        importedRows: payload.tables[_tableExercises] ?? const [],
        entityType: BackupConflictType.exercise,
        fuzzyPrefix: 'fuzzy_exercise',
      ),
    );
    pending.addAll(
      await _scanWorkoutFuzzyReviews(
        importedRows: payload.tables[_tableWorkouts] ?? const [],
      ),
    );

    return pending;
  }

  Future<List<BackupPendingReview>> _scanCatalogImportReviews({
    required String tableName,
    required List<Map<String, dynamic>> importedRows,
    required BackupConflictType entityType,
    required String fuzzyPrefix,
  }) async {
    final pending = <BackupPendingReview>[];
    final localRows = await _fetchTableRows(tableName);
    for (final row in importedRows) {
      final oldId = _asInt(row['id']);
      final name = (row['name'] as String?)?.trim();
      if (oldId == null || name == null || name.isEmpty) continue;

      if (tableName == _tableExercises && _asBool(row['is_verified'])) {
        continue;
      }

      final match = _findBestCatalogMatch(
        tableName: tableName,
        importedRow: row,
        importedName: name,
        existingRows: localRows,
      );
      if (match == null) {
        final suggestion = tableName == _tableExercises
            ? _topFuzzyBackedUpExerciseNameCandidates(name, localRows, limit: 1)
            : _topFuzzyCandidates(name, localRows, limit: 1);
        final best = suggestion.isEmpty
            ? -1.0
            : suggestion.first['score'] as double;
        if (suggestion.isEmpty) continue;
        if (best < _fuzzyThreshold) continue;
        pending.add(
          BackupPendingReview(
            reviewId: '${fuzzyPrefix}_$oldId',
            type: BackupPendingReviewType.fuzzyMatchCandidate,
            decisionScope: BackupConflictDecisionScope.userLocal,
            detectedFrom: BackupConflictDetectedFrom.importPreview,
            entityType: entityType,
            importedLabel: name,
            suggestedLabel: suggestion.first['name'] as String?,
            similarityScore: best,
          ),
        );
        continue;
      }

      final existing = match.row;
      final existingName = existing['name']?.toString();
      final importedIsVerified = _asBool(row['is_verified']);
      final existingIsVerified = _asBool(existing['is_verified']);

      if (importedIsVerified != existingIsVerified) {
        pending.add(
          BackupPendingReview(
            reviewId: 'verified_confirm_${entityType.name}_$oldId',
            type: BackupPendingReviewType.verifiedVsCustomConfirmation,
            decisionScope: BackupConflictDecisionScope.userLocal,
            detectedFrom: BackupConflictDetectedFrom.importPreview,
            entityType: entityType,
            importedLabel: name,
            existingLabel: existingName,
            suggestedLabel: existingName,
            similarityScore: match.score,
          ),
        );
        continue;
      }

      if (importedIsVerified && existingIsVerified) {
        final importedRemoteId = row['catalog_remote_id']?.toString();
        final existingRemoteId = existing['catalog_remote_id']?.toString();
        if (importedRemoteId != null &&
            existingRemoteId != null &&
            importedRemoteId != existingRemoteId) {
          pending.add(
            BackupPendingReview(
              reviewId: 'governance_${entityType.name}_$oldId',
              type: BackupPendingReviewType.governanceConflict,
              decisionScope: BackupConflictDecisionScope.catalogGovernance,
              detectedFrom: BackupConflictDetectedFrom.importPreview,
              entityType: entityType,
              importedLabel: name,
              existingLabel: existingName,
              suggestedLabel: existingName,
              similarityScore: match.score,
            ),
          );
        }
        continue;
      }

      if (!match.isStrong) {
        pending.add(
          BackupPendingReview(
            reviewId: '${fuzzyPrefix}_$oldId',
            type: BackupPendingReviewType.fuzzyMatchCandidate,
            decisionScope: BackupConflictDecisionScope.userLocal,
            detectedFrom: BackupConflictDetectedFrom.importPreview,
            entityType: entityType,
            importedLabel: name,
            existingLabel: existingName,
            suggestedLabel: existingName,
            similarityScore: match.score,
          ),
        );
      }
    }
    return pending;
  }

  Future<List<BackupPendingReview>> _scanWorkoutFuzzyReviews({
    required List<Map<String, dynamic>> importedRows,
  }) async {
    final pending = <BackupPendingReview>[];
    final localRows = await _fetchTableRows(_tableWorkouts);
    final localByNormalized = {
      for (final row in localRows)
        if ((row['name'] as String?)?.trim().isNotEmpty ?? false)
          _normalizeName(row['name'] as String): row,
    };
    for (final row in importedRows) {
      final oldId = _asInt(row['id']);
      final name = (row['name'] as String?)?.trim();
      if (oldId == null || name == null || name.isEmpty) continue;
      if (localByNormalized.containsKey(_normalizeName(name))) continue;

      final suggestion = _topFuzzyCandidates(name, localRows, limit: 1);
      if (suggestion.isEmpty) continue;
      final best = suggestion.first['score'] as double;
      if (best < _fuzzyThreshold) continue;
      pending.add(
        BackupPendingReview(
          reviewId: 'fuzzy_workout_$oldId',
          type: BackupPendingReviewType.fuzzyMatchCandidate,
          decisionScope: BackupConflictDecisionScope.userLocal,
          detectedFrom: BackupConflictDetectedFrom.importPreview,
          entityType: BackupConflictType.workout,
          importedLabel: name,
          suggestedLabel: suggestion.first['name'] as String?,
          similarityScore: best,
        ),
      );
    }
    return pending;
  }

  Future<List<BackupPendingReview>> _scanRuntimeDuplicatesForTable({
    required String tableName,
    required BackupConflictType entityType,
    required String reviewPrefix,
  }) async {
    final rows = await _fetchTableRows(tableName);
    final candidates = rows
        .map(
          (row) => _toRuntimeDuplicateCandidate(tableName: tableName, row: row),
        )
        .whereType<_RuntimeDuplicateCandidate>()
        .toList();

    final reviews = <BackupPendingReview>[];
    final seenPairs = <String>{};

    for (var i = 0; i < candidates.length; i++) {
      final current = candidates[i];

      _RuntimeDuplicateCandidate? bestMatch;
      double bestScore = 0;

      for (var j = 0; j < candidates.length; j++) {
        if (i == j) continue;
        final other = candidates[j];
        if (current.isVerified && other.isVerified) continue;
        final score = _runtimeDuplicateScore(current, other);
        if (score > bestScore) {
          bestScore = score;
          bestMatch = other;
        }
      }

      if (bestMatch == null || bestScore < _fuzzyThreshold) continue;
      if (!_canBeRuntimeDuplicate(current, bestMatch)) continue;

      final minId = math.min(current.id, bestMatch.id);
      final maxId = math.max(current.id, bestMatch.id);
      final pairKey = '$tableName:$minId:$maxId';
      if (!seenPairs.add(pairKey)) continue;

      final leftFingerprint = _buildDuplicateFingerprint(
        tableName: tableName,
        label: current.rawName,
      );
      final rightFingerprint = _buildDuplicateFingerprint(
        tableName: tableName,
        label: bestMatch.rawName,
      );
      final suppressed = await _isRuntimePairSuppressed(
        entityType: entityType,
        leftFingerprint: leftFingerprint,
        rightFingerprint: rightFingerprint,
      );
      if (suppressed) continue;

      reviews.add(
        BackupPendingReview(
          reviewId: '${reviewPrefix}_${minId}_$maxId',
          type: BackupPendingReviewType.fuzzyMatchCandidate,
          decisionScope: BackupConflictDecisionScope.userLocal,
          detectedFrom: BackupConflictDetectedFrom.runtimeScan,
          entityType: entityType,
          importedLabel: current.rawName,
          existingLabel: bestMatch.rawName,
          suggestedLabel: bestMatch.rawName,
          similarityScore: bestScore,
          leftEntityId: current.id,
          rightEntityId: bestMatch.id,
          isLeftVerified: current.isVerified,
          isRightVerified: bestMatch.isVerified,
        ),
      );
    }

    return reviews;
  }

  _RuntimeDuplicateCandidate? _toRuntimeDuplicateCandidate({
    required String tableName,
    required Map<String, dynamic> row,
  }) {
    final id = _asInt(row['id']);
    final rawName = (row['name'] as String?)?.trim();
    if (id == null || rawName == null || rawName.isEmpty) return null;

    final normalizedName = _normalizeComparableName(rawName);
    final normalizedFromCanonical = _normalizeComparableName(
      _canonicalComparableName(tableName: tableName, candidate: rawName),
    );
    final canonicalKey = _canonicalKeyFor(
      tableName: tableName,
      candidate: rawName,
    );
    final tokens = <String>{
      ..._tokenize(normalizedName),
      ..._tokenize(normalizedFromCanonical),
    };

    return _RuntimeDuplicateCandidate(
      id: id,
      rawName: rawName,
      normalizedName: normalizedName,
      normalizedFromCanonical: normalizedFromCanonical,
      canonicalKey: canonicalKey,
      tokens: tokens,
      isVerified: _asBool(row['is_verified']),
    );
  }

  String _canonicalComparableName({
    required String tableName,
    required String candidate,
  }) {
    final canonical = _canonicalKeyFor(
      tableName: tableName,
      candidate: candidate,
    );
    return _splitCamelCase(canonical);
  }

  String _canonicalKeyFor({
    required String tableName,
    required String candidate,
  }) {
    if (tableName == _tableExercises) {
      return _domainLabelResolver.toCanonicalName(
        kind: DomainLabelKind.exercise,
        candidate: candidate,
      );
    }
    return candidate;
  }

  double _runtimeDuplicateScore(
    _RuntimeDuplicateCandidate current,
    _RuntimeDuplicateCandidate other,
  ) {
    if (current.canonicalKey == other.canonicalKey &&
        (current.canonicalKey != current.rawName ||
            other.canonicalKey != other.rawName)) {
      // If both labels map to the same known canonical key, treat as a strong match.
      return 1;
    }

    final scoreByRaw = _similarity(
      current.normalizedName,
      other.normalizedName,
    );
    final scoreByCanonical = _similarity(
      current.normalizedFromCanonical,
      other.normalizedFromCanonical,
    );
    return math.max(scoreByRaw, scoreByCanonical);
  }

  bool _canBeRuntimeDuplicate(
    _RuntimeDuplicateCandidate current,
    _RuntimeDuplicateCandidate other,
  ) {
    if (current.canonicalKey == other.canonicalKey &&
        (current.canonicalKey != current.rawName ||
            other.canonicalKey != other.rawName)) {
      return true;
    }

    final overlap = _tokenOverlapRatio(current.tokens, other.tokens);
    return overlap >= 0.75;
  }

  double _tokenOverlapRatio(Set<String> left, Set<String> right) {
    if (left.isEmpty || right.isEmpty) return 0;
    final intersection = left.intersection(right).length;
    final maxSize = math.max(left.length, right.length);
    return intersection / maxSize;
  }

  Set<String> _tokenize(String value) {
    if (value.isEmpty) return const {};
    return value
        .split(RegExp(r'[^a-z0-9]+'))
        .where((token) => token.isNotEmpty)
        .toSet();
  }

  String _normalizeComparableName(String value) {
    return _normalizeName(_splitCamelCase(value));
  }

  String _splitCamelCase(String value) {
    return value
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (m) => '${m[1]} ${m[2]}',
        )
        .replaceAll('_', ' ')
        .trim();
  }

  String? _runtimeConflictTable(BackupConflictType entityType) {
    return switch (entityType) {
      BackupConflictType.exercise => _tableExercises,
      BackupConflictType.equipment ||
      BackupConflictType.profile ||
      BackupConflictType.workout => null,
    };
  }

  String _buildDuplicateFingerprint({
    required String tableName,
    required String label,
  }) {
    final canonical = _canonicalKeyFor(tableName: tableName, candidate: label);
    return _normalizeComparableName(canonical);
  }

  Future<bool> _isRuntimePairSuppressed({
    required BackupConflictType entityType,
    required String leftFingerprint,
    required String rightFingerprint,
  }) async {
    final ordered = _orderedFingerprints(leftFingerprint, rightFingerprint);
    final rows = await _db
        .customSelect(
          '''
          SELECT id
          FROM $_tableLocalDuplicateFeedback
          WHERE entity_type = ?
            AND left_fingerprint = ?
            AND right_fingerprint = ?
            AND decision = 'not_duplicate'
          LIMIT 1
          ''',
          variables: [
            Variable<String>(entityType.name),
            Variable<String>(ordered.$1),
            Variable<String>(ordered.$2),
          ],
        )
        .get();
    return rows.isNotEmpty;
  }

  Future<void> _saveRuntimePairSuppression({
    required BackupConflictType entityType,
    required String leftFingerprint,
    required String rightFingerprint,
  }) async {
    final ordered = _orderedFingerprints(leftFingerprint, rightFingerprint);
    await _insertRow(_tableLocalDuplicateFeedback, {
      'entity_type': entityType.name,
      'left_fingerprint': ordered.$1,
      'right_fingerprint': ordered.$2,
      'decision': 'not_duplicate',
    }, orIgnore: true);
  }

  Future<void> _deleteRuntimePairSuppression({
    required BackupConflictType entityType,
    required String leftFingerprint,
    required String rightFingerprint,
  }) async {
    final ordered = _orderedFingerprints(leftFingerprint, rightFingerprint);
    await _db.customUpdate(
      '''
      DELETE FROM $_tableLocalDuplicateFeedback
      WHERE entity_type = ?
        AND left_fingerprint = ?
        AND right_fingerprint = ?
      ''',
      variables: [
        Variable<String>(entityType.name),
        Variable<String>(ordered.$1),
        Variable<String>(ordered.$2),
      ],
    );
  }

  (String, String) _orderedFingerprints(String left, String right) {
    return left.compareTo(right) <= 0 ? (left, right) : (right, left);
  }

  _BackupParsedPayload _parsePayload(String jsonContent) {
    dynamic parsed;
    try {
      parsed = jsonDecode(jsonContent);
    } on FormatException {
      throw const ValidationException('Invalid JSON file.');
    }

    if (parsed is! Map<String, dynamic>) {
      throw const ValidationException('Invalid backup format.');
    }

    final backupFormatVersion = _asInt(parsed['backupFormatVersion']);
    if (backupFormatVersion != _backupFormatVersion) {
      throw const ValidationException('Unsupported backup format version.');
    }

    final schemaVersion = _asInt(parsed['databaseSchemaVersion']);
    if (schemaVersion == null || schemaVersion > _db.schemaVersion) {
      throw ValidationException(
        'Backup schema version ($schemaVersion) is incompatible with current app schema (${_db.schemaVersion}).',
      );
    }

    final tablesNode = parsed['tables'];
    if (tablesNode is! Map<String, dynamic>) {
      throw const ValidationException(
        'Backup payload does not contain tables.',
      );
    }

    final tableNames = <String>[
      _tableUserProfiles,
      _tableEquipments,
      _tableExercises,
      _tableExerciseEquipments,
      _tableExerciseTargetMuscles,
      _tableExerciseVariations,
      _tableWorkouts,
      _tableWorkoutExercises,
      _tableWorkoutExecutions,
      _tableExecutionSets,
      _tableExecutionSetSegments,
      _tableCycleSteps,
      _tablePrograms,
      _tableProgressionRules,
      _tableBodyMetrics,
      _tableUserEquipments,
    ];

    final tables = <String, List<Map<String, dynamic>>>{};
    var totalRecords = 0;
    for (final tableName in tableNames) {
      final rows = _readRowsList(tablesNode[tableName]);
      tables[tableName] = rows;
      totalRecords += rows.length;
    }

    final refsNode = parsed[_tableCatalogReferences];
    final catalogRefs = <String, List<BackupCatalogReference>>{
      _catalogEquipments: const [],
      _catalogExercises: const [],
    };
    if (refsNode is Map<String, dynamic>) {
      catalogRefs[_catalogEquipments] = _readCatalogRefs(
        refsNode[_catalogEquipments],
      );
      catalogRefs[_catalogExercises] = _readCatalogRefs(
        refsNode[_catalogExercises],
      );
    }

    return _BackupParsedPayload(
      databaseSchemaVersion: schemaVersion,
      tables: tables,
      catalogReferences: catalogRefs,
      totalRecords: totalRecords,
    );
  }

  _BackupParsedPayload _applyLegacyExerciseImportTransforms(
    _BackupParsedPayload payload,
  ) {
    final sourceExercises = payload.tables[_tableExercises] ?? const [];
    final migratedExercises = sourceExercises
        .map(_copyExerciseRowApplyingLegacyNamingMigration)
        .toList();

    final workoutExecutions =
        (payload.tables[_tableWorkoutExecutions] ?? const [])
            .map((row) => Map<String, dynamic>.from(row)..remove('notes'))
            .toList();
    final executionSets = (payload.tables[_tableExecutionSets] ?? const [])
        .map(
          (row) => Map<String, dynamic>.from(row)
            ..remove('notes')
            ..putIfAbsent('body_weight_snapshot', () => null)
            ..putIfAbsent('load_mode_override', () => null),
        )
        .toList();

    final nextTables =
        Map<String, List<Map<String, dynamic>>>.from(payload.tables)
          ..[_tableExercises] = migratedExercises
          ..[_tableWorkoutExecutions] = workoutExecutions
          ..[_tableExecutionSets] = executionSets;

    final migratedRefs =
        (payload.catalogReferences[_catalogExercises] ?? const [])
            .map(_migrateExerciseCatalogReferenceIdentity)
            .toList();

    return _BackupParsedPayload(
      databaseSchemaVersion: payload.databaseSchemaVersion,
      tables: nextTables,
      catalogReferences: {
        ...payload.catalogReferences,
        _catalogExercises: migratedRefs,
      },
      totalRecords: payload.totalRecords,
    );
  }

  Map<String, dynamic> _copyExerciseRowApplyingLegacyNamingMigration(
    Map<String, dynamic> row,
  ) {
    final copy = Map<String, dynamic>.from(row);
    final raw = copy['name']?.toString();
    if (raw != null && raw.trim().isNotEmpty) {
      copy['name'] = resolveImportedExerciseCatalogName(raw);
    }
    // v34+ schema compatibility: translate legacy boolean `is_bodyweight`
    // into enum `default_load_mode` and drop the old column so INSERTs don't
    // fail on unknown field / missing NOT NULL enum.
    if (!copy.containsKey('default_load_mode')) {
      final isBodyweight = _asBool(copy['is_bodyweight']);
      copy['default_load_mode'] = isBodyweight ? 'bodyweight' : 'weighted';
    }
    copy.putIfAbsent('bodyweight_load_factor', () => null);
    copy.remove('is_bodyweight');
    return copy;
  }

  BackupCatalogReference _migrateExerciseCatalogReferenceIdentity(
    BackupCatalogReference ref,
  ) {
    final newName = resolveImportedExerciseCatalogName(ref.name);
    final fb = Map<String, dynamic>.from(ref.fallbackData);
    final fn = fb['name']?.toString();
    if (fn != null && fn.trim().isNotEmpty) {
      fb['name'] = resolveImportedExerciseCatalogName(fn);
    }
    if (!fb.containsKey('default_load_mode')) {
      final isBodyweight = _asBool(fb['is_bodyweight']);
      fb['default_load_mode'] = isBodyweight ? 'bodyweight' : 'weighted';
    }
    fb.putIfAbsent('bodyweight_load_factor', () => null);
    fb.remove('is_bodyweight');
    return BackupCatalogReference(
      localId: ref.localId,
      catalogRemoteId: ref.catalogRemoteId,
      name: newName,
      fallbackData: fb,
    );
  }

  /// Canonical exercises (`is_verified` in backup JSON) link to seeded rows only.
  /// Only `is_verified == false` rows may INSERT into the exercise catalog.
  int? _linkVerifiedImportedExerciseToLocalCatalog({
    required Map<String, dynamic> importedRow,
    required List<Map<String, dynamic>> localVerifiedCatalog,
  }) {
    final remote = importedRow['catalog_remote_id']?.toString() ?? '';
    if (remote.isNotEmpty) {
      final hit = localVerifiedCatalog.firstWhere(
        (r) => r['catalog_remote_id']?.toString() == remote,
        orElse: () => const {},
      );
      if (hit.isNotEmpty) return _asInt(hit['id']);
    }
    final name = (importedRow['name'] as String?)?.trim();
    if (name != null && name.isNotEmpty) {
      final byExact = _exerciseRowIdByExactName(localVerifiedCatalog, name);
      if (byExact != null) return byExact;

      final fuzzy = _topFuzzyBackedUpExerciseNameCandidates(
        name,
        localVerifiedCatalog,
      );
      if (fuzzy.isNotEmpty &&
          (fuzzy.first['score'] as double) >= _strongMatchThreshold) {
        return _asInt(fuzzy.first['id']);
      }
    }
    return null;
  }

  List<Map<String, dynamic>> _readRowsList(dynamic node) {
    if (node is! List) return const [];
    final rows = <Map<String, dynamic>>[];
    for (final item in node) {
      if (item is Map<String, dynamic>) {
        rows.add(Map<String, dynamic>.from(item));
      } else if (item is Map) {
        rows.add(Map<String, dynamic>.from(item.cast<String, dynamic>()));
      }
    }
    return rows;
  }

  List<BackupCatalogReference> _readCatalogRefs(dynamic node) {
    if (node is! List) return const [];
    final refs = <BackupCatalogReference>[];
    for (final item in node) {
      if (item is! Map) continue;
      final map = item.cast<String, dynamic>();
      final localId = _asInt(map['localId']);
      final remoteId = map['catalogRemoteId']?.toString() ?? '';
      final name = map['name']?.toString();
      if (localId == null || name == null) continue;
      refs.add(
        BackupCatalogReference(
          localId: localId,
          catalogRemoteId: remoteId,
          name: name,
          fallbackData: Map<String, dynamic>.from(
            (map['fallbackData'] as Map?)?.cast<String, dynamic>() ?? const {},
          ),
        ),
      );
    }
    return refs;
  }

  Future<List<Map<String, dynamic>>> _fetchRowsForCustomExercises(
    String tableName,
    Set<int> customExerciseIds,
  ) async {
    if (customExerciseIds.isEmpty) return const [];
    final ids = customExerciseIds.join(', ');
    final rows = await _db
        .customSelect('SELECT * FROM $tableName WHERE exercise_id IN ($ids)')
        .get();
    return rows.map((row) => Map<String, dynamic>.from(row.data)).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchCustomVariations(
    Set<int> customExerciseIds,
  ) async {
    if (customExerciseIds.isEmpty) return const [];
    final ids = customExerciseIds.join(', ');
    final rows = await _db
        .customSelect(
          'SELECT * FROM $_tableExerciseVariations WHERE exercise_id IN ($ids) OR variation_id IN ($ids)',
        )
        .get();
    return rows.map((row) => Map<String, dynamic>.from(row.data)).toList();
  }

  List<String> _decodeOwnedEquipmentNames(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      return raw
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded
              .map((e) => e.toString().trim())
              .where((s) => s.isNotEmpty)
              .toList();
        }
      } on FormatException {
        return [];
      }
    }
    return [];
  }

  Future<void> _mergeLegacyImportedEquipment(
    _BackupParsedPayload payload,
  ) async {
    final userRowsRaw = payload.tables[_tableUserEquipments];
    final userRows = userRowsRaw == null
        ? const <Map<String, dynamic>>[]
        : (userRowsRaw as List).whereType<Map<String, dynamic>>().toList();
    if (userRows.isEmpty) return;

    final existingProfiles = await _fetchTableRows(_tableUserProfiles);
    if (existingProfiles.isEmpty) return;

    final row = Map<String, dynamic>.from(existingProfiles.first);
    final profileId = _asInt(row['id']);
    if (profileId == null) return;

    final equipRowsRaw = payload.tables[_tableEquipments];
    final equipRows = equipRowsRaw == null
        ? const <Map<String, dynamic>>[]
        : (equipRowsRaw as List).whereType<Map<String, dynamic>>().toList();

    final idToName = <int, String>{};
    for (final r in equipRows) {
      final id = _asInt(r['id']);
      final name = r['name']?.toString().trim();
      if (id != null && name != null && name.isNotEmpty) idToName[id] = name;
    }
    for (final ref
        in payload.catalogReferences[_catalogEquipments] ?? const []) {
      idToName.putIfAbsent(ref.localId, () => ref.name);
    }

    final owned = List<String>.from(
      _decodeOwnedEquipmentNames(row['owned_equipment_names']),
    );
    final seen = owned.map((e) => e.toLowerCase()).toSet();

    for (final ur in userRows) {
      final eid = _asInt(ur['equipment_id']);
      if (eid == null) continue;
      final rawName = idToName[eid];
      if (rawName == null || rawName.isEmpty) continue;
      final normalized = _domainLabelResolver.toCanonicalName(
        kind: DomainLabelKind.equipment,
        candidate: rawName,
      );
      if (normalized.isEmpty) continue;
      final key = normalized.toLowerCase();
      if (seen.contains(key)) continue;
      seen.add(key);
      owned.add(normalized);
    }

    row['owned_equipment_names'] = jsonEncode(owned);
    await _updateRowById(
      _tableUserProfiles,
      profileId,
      row,
      excludeKeys: const {'id', 'created_at', 'updated_at', 'weight'},
    );
  }

  Future<List<Map<String, dynamic>>> _fetchVerifiedRows(
    String tableName,
  ) async {
    final rows = await _db
        .customSelect('SELECT * FROM $tableName WHERE is_verified = 1')
        .get();
    return rows.map((row) => Map<String, dynamic>.from(row.data)).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchTableRows(String tableName) async {
    final rows = await _db.customSelect('SELECT * FROM $tableName').get();
    return rows.map((row) => Map<String, dynamic>.from(row.data)).toList();
  }

  Future<int?> _findVerifiedExerciseIdByLocalId(int localId) async {
    final rows = await _db
        .customSelect(
          'SELECT id FROM $_tableExercises WHERE id = ? AND is_verified = 1 LIMIT 1',
          variables: [Variable<int>(localId)],
        )
        .get();
    if (rows.isEmpty) return null;
    return _asInt(rows.first.data['id']);
  }

  Future<Map<String, int>> _fetchNamedIds(String tableName) async {
    final rows = await _db
        .customSelect('SELECT id, name FROM $tableName')
        .get();
    final namedIds = <String, int>{};
    for (final row in rows) {
      final id = _asInt(row.data['id']);
      final name = row.data['name'] as String?;
      if (id == null || name == null || name.trim().isEmpty) continue;
      namedIds[_normalizeName(name)] = id;
    }
    return namedIds;
  }

  Map<String, dynamic> _toJsonMap(Map<String, dynamic> row) {
    return row.map((key, value) => MapEntry(key, _toJsonValue(value)));
  }

  Map<String, dynamic>? _toExerciseCatalogRef(Map<String, dynamic> row) {
    final id = _asInt(row['id']);
    final name = row['name'] as String?;
    if (id == null || name == null) return null;
    return {
      'localId': id,
      'catalogRemoteId': row['catalog_remote_id']?.toString() ?? '',
      'name': name,
      'fallbackData': {
        'name': name,
        'muscle_group': row['muscle_group'],
        'type': row['type'],
        'movement_pattern': row['movement_pattern'],
        'description': row['description'],
        'is_verified': 0,
        'default_load_mode':
            row['default_load_mode'] ??
            (_asBool(row['is_bodyweight']) ? 'bodyweight' : 'weighted'),
        'bodyweight_load_factor': row['bodyweight_load_factor'],
        'is_isometric': row['is_isometric'] ?? 0,
      },
    };
  }

  dynamic _toJsonValue(dynamic value) {
    if (value is DateTime) return value.toIso8601String();
    return value;
  }

  Future<int> _insertRow(
    String tableName,
    Map<String, dynamic> row, {
    Set<String> excludeKeys = const {},
    bool orIgnore = false,
    bool orReplace = false,
  }) async {
    final filtered = Map<String, dynamic>.from(row)
      ..removeWhere((key, _) => excludeKeys.contains(key));
    if (filtered.isEmpty) {
      throw const ValidationException('Cannot insert empty row.');
    }

    final columns = <String>[];
    final placeholders = <String>[];
    final variables = <Variable<Object>>[];
    for (final entry in filtered.entries) {
      columns.add(_quoteIdentifier(entry.key));
      if (entry.value == null) {
        placeholders.add('NULL');
      } else {
        placeholders.add('?');
        variables.add(_toVariable(entry.value));
      }
    }

    final mode = orIgnore
        ? 'INSERT OR IGNORE'
        : (orReplace ? 'INSERT OR REPLACE' : 'INSERT');
    final sql =
        '$mode INTO ${_quoteIdentifier(tableName)} (${columns.join(', ')}) VALUES (${placeholders.join(', ')})';
    return _db.customInsert(sql, variables: variables);
  }

  Future<void> _updateRowById(
    String tableName,
    int id,
    Map<String, dynamic> row, {
    Set<String> excludeKeys = const {},
  }) async {
    final filtered = Map<String, dynamic>.from(row)
      ..removeWhere((key, _) => key == 'id' || excludeKeys.contains(key));
    if (filtered.isEmpty) return;

    final setters = <String>[];
    final variables = <Variable<Object>>[];
    for (final entry in filtered.entries) {
      if (entry.value == null) {
        setters.add('${_quoteIdentifier(entry.key)} = NULL');
      } else {
        setters.add('${_quoteIdentifier(entry.key)} = ?');
        variables.add(_toVariable(entry.value));
      }
    }
    variables.add(Variable<int>(id));
    final sql =
        'UPDATE ${_quoteIdentifier(tableName)} SET ${setters.join(', ')} WHERE ${_quoteIdentifier('id')} = ?';
    await _db.customUpdate(sql, variables: variables);
  }

  String _quoteIdentifier(String identifier) {
    final escaped = identifier.replaceAll('"', '""');
    return '"$escaped"';
  }

  _CatalogMatch? _findBestCatalogMatch({
    required String tableName,
    required Map<String, dynamic> importedRow,
    required String importedName,
    required List<Map<String, dynamic>> existingRows,
  }) {
    final String? exerciseImportIndexedCanon = tableName == _tableExercises
        ? exerciseCatalogLabelIndex.tryResolveCanonicalStrict(
            importedName.trim(),
          )
        : null;

    if (tableName == _tableExercises) {
      final resolvedImported = resolveImportedExerciseCatalogName(
        importedName,
      ).trim();
      final indexedCanonical = exerciseImportIndexedCanon;

      for (final existingRow in existingRows) {
        final existingName = (existingRow['name'] as String?)?.trim();
        if (existingName == null || existingName.isEmpty) continue;
        final nameMatchesImported =
            existingName == resolvedImported ||
            (indexedCanonical != null && existingName == indexedCanonical);
        if (!nameMatchesImported) continue;
        if (!_isSemanticallyCompatible(
          tableName: tableName,
          importedRow: importedRow,
          existingRow: existingRow,
        )) {
          continue;
        }
        return _CatalogMatch(row: existingRow, score: 1, isStrong: true);
      }
    }

    final importedNormalized = _normalizeName(importedName);
    _CatalogMatch? best;
    for (final existingRow in existingRows) {
      final existingName = (existingRow['name'] as String?)?.trim();
      if (existingName == null || existingName.isEmpty) continue;
      if (!_isSemanticallyCompatible(
        tableName: tableName,
        importedRow: importedRow,
        existingRow: existingRow,
      )) {
        continue;
      }

      // PT labels like "Cadeira Adutora" vs "Cadeira Abdutora" fuzzy-match with
      // high Levenshtein score but map to different canonicals (hipAdduction vs
      // hipAbduction). Never pair those verified rows via string fuzzy alone.
      if (tableName == _tableExercises &&
          exerciseImportIndexedCanon != null &&
          _asBool(existingRow['is_verified'])) {
        if (existingName != exerciseImportIndexedCanon) continue;
      }

      final existingNormalized = _normalizeName(existingName);

      final containsMatch =
          importedNormalized.contains(existingNormalized) ||
          existingNormalized.contains(importedNormalized);

      final double score;
      if (tableName == _tableExercises &&
          _asBool(existingRow['is_verified']) &&
          exerciseCatalogLabelIndex.isKnownCanonicalKey(existingName)) {
        final synonymScore = exerciseCatalogLabelIndex.maxFuzzySimilarity(
          importedName,
          existingName,
        );
        final legacyScore = containsMatch
            ? 0.98
            : _similarity(importedNormalized, existingNormalized);
        score = math.max(synonymScore, legacyScore);
      } else {
        score = containsMatch
            ? 0.98
            : _similarity(importedNormalized, existingNormalized);
      }
      if (score < _fuzzyThreshold) continue;

      final isStrong = score >= _strongMatchThreshold || containsMatch;
      final candidate = _CatalogMatch(
        row: existingRow,
        score: score,
        isStrong: isStrong,
      );
      if (best == null || candidate.score > best.score) {
        best = candidate;
      }
    }
    return best;
  }

  bool _isSemanticallyCompatible({
    required String tableName,
    required Map<String, dynamic> importedRow,
    required Map<String, dynamic> existingRow,
  }) {
    if (tableName == _tableExercises) {
      final keys = ['muscle_group', 'type', 'movement_pattern'];
      for (final key in keys) {
        final imported = importedRow[key]?.toString();
        final existing = existingRow[key]?.toString();
        if (imported == null || imported.isEmpty) continue;
        if (existing == null || existing.isEmpty) continue;
        if (imported != existing) return false;
      }
    }
    return true;
  }

  Map<String, dynamic> _mergeRowPreservingPrecedence({
    required Map<String, dynamic> existingRow,
    required Map<String, dynamic> importedRow,
    required bool keepExistingValues,
  }) {
    final merged = Map<String, dynamic>.from(existingRow);
    for (final entry in importedRow.entries) {
      final key = entry.key;
      if (key == 'id') continue;
      if (entry.value == null) continue;
      final current = merged[key];
      if (current == null || (current is String && current.trim().isEmpty)) {
        merged[key] = entry.value;
        continue;
      }
      if (!keepExistingValues) {
        merged[key] = entry.value;
      }
    }
    return merged;
  }

  int? _findDuplicateCustomByName({
    required List<Map<String, dynamic>> rows,
    required String normalizedName,
    required int winnerId,
  }) {
    for (final row in rows) {
      final id = _asInt(row['id']);
      final name = (row['name'] as String?)?.trim();
      if (id == null || id == winnerId || name == null || name.isEmpty) {
        continue;
      }
      if (_asBool(row['is_verified'])) continue;
      if (_normalizeName(name) == normalizedName) return id;
    }
    return null;
  }

  Future<void> _mergeLocalLoserIntoWinner({
    required String tableName,
    required int loserId,
    required int winnerId,
  }) async {
    if (loserId == winnerId) return;
    final loserRows = await _db
        .customSelect('SELECT is_verified FROM $tableName WHERE id = $loserId')
        .get();
    if (loserRows.isEmpty) return;
    final loserIsVerified = _asBool(loserRows.first.data['is_verified']);
    if (loserIsVerified) {
      // Safety rule: verified entries are never auto-deleted.
      return;
    }

    if (tableName == _tableExercises) {
      await _db.customStatement(
        'DELETE FROM $_tableWorkoutExercises WHERE exercise_id = $loserId AND EXISTS (SELECT 1 FROM $_tableWorkoutExercises we2 WHERE we2.workout_id = $_tableWorkoutExercises.workout_id AND we2.exercise_id = $winnerId)',
      );
      await _db.customUpdate(
        'UPDATE $_tableWorkoutExercises SET exercise_id = ? WHERE exercise_id = ?',
        variables: [Variable<int>(winnerId), Variable<int>(loserId)],
      );
      await _db.customUpdate(
        'UPDATE $_tableExecutionSets SET exercise_id = ? WHERE exercise_id = ?',
        variables: [Variable<int>(winnerId), Variable<int>(loserId)],
      );
      await _db.customStatement(
        'DELETE FROM $_tableExerciseVariations WHERE exercise_id = $loserId AND EXISTS (SELECT 1 FROM $_tableExerciseVariations ev2 WHERE ev2.exercise_id = $winnerId AND ev2.variation_id = $_tableExerciseVariations.variation_id)',
      );
      await _db.customUpdate(
        'UPDATE $_tableExerciseVariations SET exercise_id = ? WHERE exercise_id = ?',
        variables: [Variable<int>(winnerId), Variable<int>(loserId)],
      );
      await _db.customStatement(
        'DELETE FROM $_tableExerciseVariations WHERE variation_id = $loserId AND EXISTS (SELECT 1 FROM $_tableExerciseVariations ev2 WHERE ev2.exercise_id = $_tableExerciseVariations.exercise_id AND ev2.variation_id = $winnerId)',
      );
      await _db.customUpdate(
        'UPDATE $_tableExerciseVariations SET variation_id = ? WHERE variation_id = ?',
        variables: [Variable<int>(winnerId), Variable<int>(loserId)],
      );
      await _db.customUpdate(
        'UPDATE $_tableExerciseTargetMuscles SET exercise_id = ? WHERE exercise_id = ?',
        variables: [Variable<int>(winnerId), Variable<int>(loserId)],
      );
    }

    await _db.customUpdate(
      'DELETE FROM $tableName WHERE id = ?',
      variables: [Variable<int>(loserId)],
    );
  }

  Future<void> _enqueueGovernanceEvent({
    required String eventUuid,
    required String eventType,
    required String entityType,
    int? localEntityId,
    String? catalogRemoteId,
    required Map<String, dynamic> payload,
  }) async {
    await _insertRow(_tableCatalogGovernanceEvents, {
      'event_uuid': eventUuid,
      'event_type': eventType,
      'entity_type': entityType,
      'local_entity_id': localEntityId,
      'catalog_remote_id': catalogRemoteId,
      'payload_json': jsonEncode(payload),
      'status': 'pending',
    }, orIgnore: true);
  }

  /// `exercises.id` when [exerciseRows] contain a verified row whose `name` equals [exerciseName].
  int? _exerciseRowIdByExactName(
    List<Map<String, dynamic>> exerciseRows,
    String exerciseName,
  ) {
    final row = exerciseRows.firstWhere(
      (r) => (r['name'] as String?) == exerciseName,
      orElse: () => const {},
    );
    if (row.isEmpty) return null;
    return _asInt(row['id']);
  }

  /// Whether local verified catalog already represents this backup exercise label,
  /// using v30 rename + merge aliases ([resolveImportedExerciseCatalogName]).
  bool _verifiedExercisesContainBackedUpLabel(
    List<Map<String, dynamic>> verifiedRows,
    String backupExerciseLabel,
  ) {
    final trimmed = backupExerciseLabel.trim();
    final migrated = resolveImportedExerciseCatalogName(backupExerciseLabel);
    return _exerciseRowIdByExactName(verifiedRows, trimmed) != null ||
        _exerciseRowIdByExactName(verifiedRows, migrated) != null;
  }

  /// Best fuzzy candidates comparing both the legacy backup string and its
  /// migration-resolved canonical key (same ordering as SQLite migration v30).
  /// When both legacy and migrated labels resolve to catalog canonicals,
  /// returns the canonical only if they agree (avoids over-filtering renames).
  String? _exerciseRestrictVerifiedCanonicalForImportLabel(String label) {
    final migrated = resolveImportedExerciseCatalogName(label).trim();
    final a = exerciseCatalogLabelIndex.tryResolveCanonicalStrict(label.trim());
    final b = exerciseCatalogLabelIndex.tryResolveCanonicalStrict(migrated);
    if (a != null && b != null && a != b) return null;
    return a ?? b;
  }

  List<Map<String, dynamic>> _topFuzzyBackedUpExerciseNameCandidates(
    String backupExerciseLabel,
    List<Map<String, dynamic>> exerciseRows, {
    int limit = 1,
  }) {
    final migrated = resolveImportedExerciseCatalogName(backupExerciseLabel);
    final restrict = _exerciseRestrictVerifiedCanonicalForImportLabel(
      backupExerciseLabel,
    );
    var best = _topFuzzyExerciseCandidates(
      migrated,
      exerciseRows,
      limit: limit,
      restrictVerifiedToCanonical: restrict,
    );
    final migratedScore = best.isEmpty ? -1.0 : best.first['score'] as double;
    final legacy = _topFuzzyExerciseCandidates(
      backupExerciseLabel,
      exerciseRows,
      limit: limit,
      restrictVerifiedToCanonical: restrict,
    );
    if (legacy.isEmpty) return best;
    final legacyScore = legacy.first['score'] as double;
    if (legacyScore > migratedScore) return legacy;
    return best;
  }

  List<Map<String, dynamic>> _topFuzzyExerciseCandidates(
    String inputName,
    List<Map<String, dynamic>> rows, {
    int limit = 3,
    String? restrictVerifiedToCanonical,
  }) {
    final scored = <Map<String, dynamic>>[];
    for (final row in rows) {
      final rowName = row['name'] as String?;
      final id = _asInt(row['id']);
      if (rowName == null || id == null) continue;

      if (restrictVerifiedToCanonical != null &&
          _asBool(row['is_verified']) &&
          exerciseCatalogLabelIndex.isKnownCanonicalKey(rowName) &&
          rowName != restrictVerifiedToCanonical) {
        continue;
      }

      final double score;
      if (_asBool(row['is_verified']) &&
          exerciseCatalogLabelIndex.isKnownCanonicalKey(rowName)) {
        score = exerciseCatalogLabelIndex.maxFuzzySimilarity(
          inputName,
          rowName,
        );
      } else {
        score = _similarity(
          ExerciseLabelNormalizer.normalizeComparable(inputName),
          ExerciseLabelNormalizer.normalizeComparable(rowName),
        );
      }

      scored.add({'id': id, 'name': rowName, 'score': score});
    }
    scored.sort(
      (a, b) => (b['score'] as double).compareTo(a['score'] as double),
    );
    return scored.take(limit).toList();
  }

  List<Map<String, dynamic>> _topFuzzyCandidates(
    String inputName,
    List<Map<String, dynamic>> rows, {
    int limit = 3,
  }) {
    final normalizedInput = _normalizeName(inputName);
    final scored = <Map<String, dynamic>>[];
    for (final row in rows) {
      final name = row['name'] as String?;
      final id = _asInt(row['id']);
      if (name == null || id == null) continue;
      final score = _similarity(normalizedInput, _normalizeName(name));
      scored.add({'id': id, 'name': name, 'score': score});
    }
    scored.sort(
      (a, b) => (b['score'] as double).compareTo(a['score'] as double),
    );
    return scored.take(limit).toList();
  }

  double _similarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0;
    if (a == b) return 1;
    final distance = _levenshtein(a, b);
    final maxLen = math.max(a.length, b.length);
    return 1 - (distance / maxLen);
  }

  int _levenshtein(String a, String b) {
    final m = a.length;
    final n = b.length;
    final matrix = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));
    for (var i = 0; i <= m; i++) {
      matrix[i][0] = i;
    }
    for (var j = 0; j <= n; j++) {
      matrix[0][j] = j;
    }
    for (var i = 1; i <= m; i++) {
      for (var j = 1; j <= n; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[i][j] = math.min(
          math.min(matrix[i - 1][j] + 1, matrix[i][j - 1] + 1),
          matrix[i - 1][j - 1] + cost,
        );
      }
    }
    return matrix[m][n];
  }

  bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is num) return value.toInt() == 1;
    if (value is String) return value == '1' || value.toLowerCase() == 'true';
    return false;
  }

  int? _importDefaultProgramId;

  /// Returns (or creates) a default program to use when imported data
  /// has no program_id. Caches the result for the duration of the import.
  Future<int> _ensureDefaultProgramForImport(Map<int, int> programIdMap) async {
    if (_importDefaultProgramId != null) return _importDefaultProgramId!;
    final id = await _insertRow(
      _tablePrograms,
      {
        'name': 'Programa Importado',
        'focus': 'custom',
        'duration_mode': 'sessions',
        'duration_value': 24,
        'is_active': 1,
        'is_in_deload': 0,
      },
      excludeKeys: const {'id'},
    );
    _importDefaultProgramId = id;
    programIdMap[-1] = id;
    return id;
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  Variable<Object> _toVariable(dynamic value) {
    if (value is bool) return Variable<bool>(value) as Variable<Object>;
    if (value is int) return Variable<int>(value) as Variable<Object>;
    if (value is double) return Variable<double>(value) as Variable<Object>;
    if (value is num) {
      if (value % 1 == 0) {
        return Variable<int>(value.toInt()) as Variable<Object>;
      }
      return Variable<double>(value.toDouble()) as Variable<Object>;
    }
    if (value is DateTime) return Variable<DateTime>(value) as Variable<Object>;
    return Variable<String>(value.toString()) as Variable<Object>;
  }

  String _normalizeName(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  String _buildUniqueName(String baseName, Map<String, int> existingByName) {
    var index = 1;
    var candidate = '$baseName (importado)';
    while (existingByName.containsKey(_normalizeName(candidate))) {
      index++;
      candidate = '$baseName (importado $index)';
    }
    return candidate;
  }
}

class _RuntimeDuplicateCandidate {
  final int id;
  final String rawName;
  final String normalizedName;
  final String normalizedFromCanonical;
  final String canonicalKey;
  final Set<String> tokens;
  final bool isVerified;

  const _RuntimeDuplicateCandidate({
    required this.id,
    required this.rawName,
    required this.normalizedName,
    required this.normalizedFromCanonical,
    required this.canonicalKey,
    required this.tokens,
    required this.isVerified,
  });
}

class _BackupParsedPayload {
  final int databaseSchemaVersion;
  final Map<String, List<Map<String, dynamic>>> tables;
  final Map<String, List<BackupCatalogReference>> catalogReferences;
  final int totalRecords;

  const _BackupParsedPayload({
    required this.databaseSchemaVersion,
    required this.tables,
    required this.catalogReferences,
    required this.totalRecords,
  });
}

class _ImportCatalogResult {
  final int createdCount;
  final int updatedCount;
  final int skippedCount;
  final int failedCount;

  const _ImportCatalogResult({
    required this.createdCount,
    required this.updatedCount,
    required this.skippedCount,
    required this.failedCount,
  });
}

class _CanonicalResolutionResult {
  final Map<int, int> equipmentIdMap;
  final Map<int, int> exerciseIdMap;
  final int unresolvedCount;

  const _CanonicalResolutionResult({
    required this.equipmentIdMap,
    required this.exerciseIdMap,
    required this.unresolvedCount,
  });
}

class _CatalogMatch {
  final Map<String, dynamic> row;
  final double score;
  final bool isStrong;

  const _CatalogMatch({
    required this.row,
    required this.score,
    required this.isStrong,
  });
}
