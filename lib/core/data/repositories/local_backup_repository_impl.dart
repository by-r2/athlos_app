import 'dart:math' as math;
import 'dart:ui' show Locale;

import 'package:drift/drift.dart';

import '../../database/app_database.dart';
import '../../database/exercise_canonical_merge.dart';
import '../../localization/domain_label_resolver.dart';
import '../../domain/entities/local_backup_models.dart';
import '../../domain/repositories/local_backup_repository.dart';
import '../../errors/app_exception.dart';
import '../../errors/result.dart';
import '../../../l10n/app_localizations.dart';

const _fuzzyThreshold = 0.84;
const _tableExercises = 'exercises';
const _tableExerciseTargetMuscles = 'exercise_target_muscles';
const _tableLocalDuplicateFeedback = 'local_duplicate_feedback';

final AppLocalizations _ptBrL10n = lookupAppLocalizations(const Locale('pt'));
final DomainLabelResolver _domainLabelResolver = DomainLabelResolver(_ptBrL10n);

class LocalBackupRepositoryImpl implements LocalBackupRepository {
  final AppDatabase _db;

  LocalBackupRepositoryImpl(this._db);

  @override
  Future<Result<List<BackupPendingReview>>> scanRuntimeLocalDuplicates() async {
    try {
      final pending = await _scanRuntimeDuplicatesForTable(
        tableName: _tableExercises,
        entityType: BackupConflictType.exercise,
        reviewPrefix: 'runtime_exercise',
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
    required String leftEntityId,
    required String rightEntityId,
    required RuntimeDuplicateDecision decision,
    String? winnerId,
    Map<String, dynamic>? mergedAttributes,
  }) async {
    if (leftEntityId == rightEntityId) {
      return const Failure(ValidationException('Invalid duplicate pair.'));
    }

    const tableName = _tableExercises;

    try {
      final rows = await _db
          .customSelect(
            'SELECT id, name, is_verified FROM $tableName WHERE id IN (?, ?)',
            variables: [
              Variable<String>(leftEntityId),
              Variable<String>(rightEntityId),
            ],
          )
          .get();
      if (rows.length != 2) {
        return const Failure(NotFoundException('Duplicate pair not found.'));
      }

      final left = rows
          .firstWhere((r) => r.data['id']?.toString() == leftEntityId)
          .data;
      final right = rows
          .firstWhere((r) => r.data['id']?.toString() == rightEntityId)
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

      final resolvedWinnerId = winnerId ??
          _autoPickWinner(left, right, leftEntityId, rightEntityId);
      final loserId =
          resolvedWinnerId == leftEntityId ? rightEntityId : leftEntityId;
      final loserRow = resolvedWinnerId == leftEntityId ? right : left;

      if (_asBool(loserRow['is_verified'])) {
        return const Failure(
          ValidationException(
            'Cannot remove a verified catalog entry. '
            'Keep the catalog item and delete the custom copy instead.',
          ),
        );
      }

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

  String _autoPickWinner(
    Map<String, dynamic> left,
    Map<String, dynamic> right,
    String leftId,
    String rightId,
  ) {
    final leftVerified = _asBool(left['is_verified']);
    final rightVerified = _asBool(right['is_verified']);
    if (leftVerified && !rightVerified) return leftId;
    if (rightVerified && !leftVerified) return rightId;
    return leftId;
  }

  Future<void> _applyMergedAttributes({
    required String tableName,
    required String entityId,
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
    variables.add(Variable<String>(entityId));
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
    required String winnerId,
    required String loserId,
  }) async {
    if (tableName == _tableExercises) {
      await _db.customStatement(
        'INSERT OR IGNORE INTO "$_tableExerciseTargetMuscles" '
        "(exercise_id, target_muscle, muscle_region, role) "
        "SELECT '$winnerId', target_muscle, muscle_region, role "
        'FROM "$_tableExerciseTargetMuscles" WHERE exercise_id = ?',
      );
      await _db.customUpdate(
        'UPDATE "$_tableExerciseTargetMuscles" SET exercise_id = ? '
        'WHERE exercise_id = ?',
        variables: [Variable<String>(winnerId), Variable<String>(loserId)],
      );
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> loadEntityAttributes({
    required BackupConflictType entityType,
    required String entityId,
  }) async {
    const tableName = _tableExercises;
    try {
      final rows = await _db
          .customSelect(
            'SELECT * FROM "$tableName" WHERE id = ?',
            variables: [Variable<String>(entityId)],
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

  // --- Runtime duplicate scanning ---

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

      final ids = [current.id, bestMatch.id]..sort();
      final pairKey = '$tableName:${ids[0]}:${ids[1]}';
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
          reviewId: '${reviewPrefix}_${ids[0]}_${ids[1]}',
          type: BackupPendingReviewType.fuzzyMatchCandidate,
          entityType: entityType,
          importedLabel: current.rawName,
          existingLabel: bestMatch.rawName,
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
    final id = row['id']?.toString();
    final rawName = (row['name'] as String?)?.trim();
    if (id == null || id.isEmpty || rawName == null || rawName.isEmpty) {
      return null;
    }

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

  String _normalizeComparableName(String value) =>
      _normalizeName(_splitCamelCase(value));

  String _splitCamelCase(String value) {
    return value
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (m) => '${m[1]} ${m[2]}',
        )
        .replaceAll('_', ' ')
        .trim();
  }

  String _buildDuplicateFingerprint({
    required String tableName,
    required String label,
  }) {
    final canonical = _canonicalKeyFor(tableName: tableName, candidate: label);
    return _normalizeComparableName(canonical);
  }

  // --- Suppression persistence ---

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
    });
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

  // --- Merge ---

  Future<void> _mergeLocalLoserIntoWinner({
    required String tableName,
    required String loserId,
    required String winnerId,
  }) async {
    if (loserId == winnerId) return;

    if (tableName == _tableExercises) {
      await mergeExerciseLoserIntoWinner(
        _db,
        winnerId: winnerId,
        loserId: loserId,
      );
      return;
    }

    await _db.customStatement(
      "DELETE FROM \"$tableName\" WHERE id = '$loserId'",
    );
  }

  // --- DB helpers ---

  Future<List<Map<String, dynamic>>> _fetchTableRows(String tableName) async {
    final rows = await _db
        .customSelect('SELECT * FROM "$tableName" WHERE deleted_at IS NULL')
        .get();
    return rows.map((row) => Map<String, dynamic>.from(row.data)).toList();
  }

  Future<int> _insertRow(
    String tableName,
    Map<String, dynamic> row,
  ) async {
    final columns = <String>[];
    final placeholders = <String>[];
    final variables = <Variable<Object>>[];
    for (final entry in row.entries) {
      columns.add(_quoteIdentifier(entry.key));
      if (entry.value == null) {
        placeholders.add('NULL');
      } else {
        placeholders.add('?');
        variables.add(_toVariable(entry.value));
      }
    }

    final sql =
        'INSERT OR IGNORE INTO ${_quoteIdentifier(tableName)} (${columns.join(', ')}) VALUES (${placeholders.join(', ')})';
    return _db.customInsert(sql, variables: variables);
  }

  String _quoteIdentifier(String identifier) {
    final escaped = identifier.replaceAll('"', '""');
    return '"$escaped"';
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

  // --- String utilities ---

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

  String _normalizeName(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

class _RuntimeDuplicateCandidate {
  final String id;
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
