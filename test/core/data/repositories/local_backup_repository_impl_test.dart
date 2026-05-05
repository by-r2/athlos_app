import 'dart:convert';

import 'package:athlos_app/core/data/repositories/local_backup_repository_impl.dart';
import 'package:athlos_app/core/database/app_database.dart';
import 'package:athlos_app/core/domain/entities/local_backup_models.dart';
import 'package:athlos_app/core/errors/app_exception.dart';
import 'package:athlos_app/core/errors/result.dart';
import 'package:athlos_app/features/training/data/datasources/exercise_seeder.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalBackupRepositoryImpl', () {
    late AppDatabase db;
    late LocalBackupRepositoryImpl repository;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repository = LocalBackupRepositoryImpl(db);
      await db.customSelect('SELECT 1').get();
    });

    tearDown(() async {
      await db.close();
    });

    test('previewImport gera conflito de perfil por campo diferente', () async {
      await db.customInsert(
        'INSERT INTO "user_profiles" ("name", "height", "age", "trains_at_gym") VALUES (?, ?, ?, ?)',
        variables: [
          const Variable<String>('Rafa'),
          const Variable<double>(181.0),
          const Variable<int>(24),
          const Variable<bool>(false),
        ],
      );

      final jsonContent = jsonEncode(
        _payloadWithTables({
          'user_profiles': [
            {
              'id': 1,
              'name': 'Rafa',
              'weight': 72.0,
              'height': 185.0,
              'age': 24,
              'trains_at_gym': null,
            },
          ],
        }),
      );

      final result = await repository.previewImport(jsonContent);
      final preview = result.getOrThrow();
      final profileConflictIds = preview.conflicts
          .where((c) => c.type == BackupConflictType.profile)
          .map((c) => c.conflictId)
          .toList();

      expect(profileConflictIds, contains('profile:height'));
      expect(profileConflictIds, isNot(contains('profile:name')));
      expect(profileConflictIds, isNot(contains('profile:trains_at_gym')));
    });

    test(
      'previewImport retorna ValidationException para JSON invalido',
      () async {
        final result = await repository.previewImport('{invalid');
        expect(result.isFailure, isTrue);
        final failure = result as Failure<BackupImportPreview>;
        expect(failure.exception, isA<ValidationException>());
      },
    );

    test(
      'importBackup retorna ValidationException para versao invalida',
      () async {
        final payload = _payloadWithTables(const {});
        payload['backupFormatVersion'] = 999;

        final result = await repository.importBackup(
          BackupImportRequest(
            jsonContent: jsonEncode(payload),
            conflictResolutions: const {},
          ),
        );

        expect(result.isFailure, isTrue);
        final failure = result as Failure<BackupImportReport>;
        expect(failure.exception, isA<ValidationException>());
      },
    );

    test('previewImport nao gera conflito com equivalencia de formato', () async {
      await db.customInsert(
        'INSERT INTO "user_profiles" ("name", "height", "age", "trains_at_gym") VALUES (?, ?, ?, ?)',
        variables: [
          const Variable<String>('Rafa'),
          const Variable<double>(181.0),
          const Variable<int>(24),
          const Variable<bool>(false),
        ],
      );

      final jsonContent = jsonEncode(
        _payloadWithTables({
          'user_profiles': [
            {
              'id': 1,
              'name': ' RAFA ',
              'weight': 72,
              'height': 181,
              'age': 24,
              'trains_at_gym': null,
            },
          ],
        }),
      );

      final result = await repository.previewImport(jsonContent);
      final preview = result.getOrThrow();

      expect(
        preview.conflicts.where((c) => c.type == BackupConflictType.profile),
        isEmpty,
      );
    });

    test('exportBackup inclui equipamentos e user_equipments vazios na carga',
        () async {
      await db.customInsert(
        'INSERT INTO "user_profiles" ("name", "owned_equipment_names") VALUES (?, ?)',
        variables: [
          const Variable<String>('U'),
          Variable<String>(jsonEncode(['haltere'])),
        ],
      );

      final exportResult = await repository.exportBackup();
      final exportData = exportResult.getOrThrow();
      final parsed = jsonDecode(exportData.jsonContent) as Map<String, dynamic>;
      final tables = parsed['tables'] as Map<String, dynamic>;

      expect(tables['equipments'], isEmpty);
      expect(tables['exercise_equipments'], isEmpty);
      expect(tables['user_equipments'], isEmpty);

      final profiles = (tables['user_profiles'] as List).cast<Map>();
      expect(profiles, isNotEmpty);
      expect(profiles.first['owned_equipment_names'], contains('haltere'));
    });

    test(
      'importBackup merge de backup legado: user_equipments vira owned_equipment_names',
      () async {
      await db.customInsert(
        'INSERT INTO "user_profiles" ("name", "owned_equipment_names") VALUES (?, ?)',
        variables: [
          const Variable<String>('U'),
          const Variable<String>('[]'),
        ],
      );

      final jsonContent = jsonEncode(
        _payloadWithTables({
          'equipments': [
            {
              'id': 1,
              'name': 'barbell',
              'category': 'freeWeights',
              'is_verified': 1,
            },
          ],
          'user_equipments': [
            {'equipment_id': 1},
          ],
        }),
      );

      final result = await repository.importBackup(
        BackupImportRequest(
          jsonContent: jsonContent,
          conflictResolutions: const {},
        ),
      );

      expect(result.isSuccess, isTrue);

      final rows = await db
          .customSelect('SELECT owned_equipment_names FROM user_profiles')
          .get();
      final raw = rows.first.data['owned_equipment_names'] as String?;
      expect(raw, isNotNull);
      final decoded = (jsonDecode(raw!) as List).cast<String>();
      expect(decoded, contains('barbell'));
    });

    test(
      'previewImport omitido missing_canonical quando nome backup e pre-v30',
      () async {
        await seedExercises(db);
        final payload = _payloadWithTables(const {});
        payload['catalogReferences'] = {
          'equipments': <dynamic>[],
          'exercises': [
            {
              'localId': 42,
              'catalogRemoteId': '',
              'name': 'flatBarbellBenchPress',
              'fallbackData': const <String, dynamic>{},
            },
          ],
        };

        final result = await repository.previewImport(jsonEncode(payload));
        final preview = result.getOrThrow();

        expect(
          preview.pendingReviews.where(
            (r) => r.type == BackupPendingReviewType.missingCanonicalReference,
          ),
          isEmpty,
        );
      },
    );

    test(
      'importBackup resolve catalogRefs pre-v30 para exercicio seeded (sem dados perdidos nos links)',
      () async {
        await seedExercises(db);

        final benchRows = await db
            .customSelect(
              'SELECT id FROM exercises WHERE name = ? LIMIT 1',
              variables: [const Variable<String>('benchPress')],
            )
            .get();
        final benchPressId = benchRows.first.data['id'] as int;

        final payload = _payloadWithTables({
          'workouts': [
            {
              'id': 10,
              'name': 'Test backup workout',
              'description': null,
              'sort_order': 0,
              'is_archived': 0,
            },
          ],
          'workout_exercises': [
            {
              'workout_id': 10,
              'exercise_id': 501,
              'order': 1,
              'sets': 3,
              'min_reps': 8,
              'max_reps': 8,
              'is_amrap': 0,
              'rest': 90,
              'duration': null,
              'group_id': null,
              'is_unilateral': 0,
              'notes': null,
            },
          ],
        });
        payload['catalogReferences'] = {
          'equipments': <dynamic>[],
          'exercises': [
            {
              'localId': 501,
              'catalogRemoteId': '',
              'name': 'flatBarbellBenchPress',
              'fallbackData': const <String, dynamic>{},
            },
          ],
        };

        final result = await repository.importBackup(
          BackupImportRequest(
            jsonContent: jsonEncode(payload),
            conflictResolutions: const {},
          ),
        );
        expect(result.isSuccess, isTrue);

        final importReport = result.getOrThrow();
        expect(importReport.failedCount, 0);

        final junction = await db
            .customSelect(
              'SELECT exercise_id FROM workout_exercises '
              'WHERE workout_id IS NOT NULL',
            )
            .get();

        expect(
          junction.map((r) => r.data['exercise_id']).toSet(),
          contains(benchPressId),
        );
      },
    );

    test(
      'importBackup merge pre-v30: ezBarCurl alinha para bicepsCurl seeded',
      () async {
        await seedExercises(db);

        final idRows = await db
            .customSelect(
              'SELECT id FROM exercises WHERE name = ? LIMIT 1',
              variables: [const Variable<String>('bicepsCurl')],
            )
            .get();
        final bicepsId = idRows.first.data['id'] as int;

        final payload = _payloadWithTables({
          'workouts': [
            {
              'id': 2,
              'name': 'Arms day',
              'description': null,
              'sort_order': 0,
              'is_archived': 0,
            },
          ],
          'workout_exercises': [
            {
              'workout_id': 2,
              'exercise_id': 88,
              'order': 1,
              'sets': 4,
              'min_reps': 10,
              'max_reps': 12,
              'is_amrap': 0,
              'rest': 60,
              'duration': null,
              'group_id': null,
              'is_unilateral': 0,
              'notes': null,
            },
          ],
        });
        payload['catalogReferences'] = {
          'equipments': <dynamic>[],
          'exercises': [
            {
              'localId': 88,
              'catalogRemoteId': '',
              'name': 'ezBarCurl',
              'fallbackData': const <String, dynamic>{},
            },
          ],
        };

        final result = await repository.importBackup(
          BackupImportRequest(
            jsonContent: jsonEncode(payload),
            conflictResolutions: const {},
          ),
        );
        expect(result.isSuccess, isTrue);
        expect(result.getOrThrow().failedCount, 0);

        final junction = await db
            .customSelect('SELECT exercise_id FROM workout_exercises')
            .get();
        expect(
          junction.map((r) => r.data['exercise_id']).toSet(),
          contains(bicepsId),
        );
      },
    );

    test(
      'importBackup schema 29: exercicio verified na tabela só liga ao seed; sem INSERT nome legado',
      () async {
        await seedExercises(db);

        final benchRows = await db
            .customSelect(
              'SELECT id FROM exercises WHERE name = ? LIMIT 1',
              variables: [const Variable<String>('benchPress')],
            )
            .get();
        final benchPressId = benchRows.first.data['id'] as int;

        final countBeforeRows =
            await db.customSelect('SELECT COUNT(*) AS c FROM exercises').get();
        final countBefore = countBeforeRows.first.data['c'] as int;

        final payload = _payloadWithTables(
          {
            'exercises': [
              {
                'id': 77,
                'catalog_remote_id': '',
                'name': 'flatBarbellBenchPress',
                'muscle_group': 'chest',
                'type': 'strength',
                'movement_pattern': 'push',
                'description': null,
                'is_verified': 1,
                'is_bodyweight': 0,
                'is_isometric': 0,
              },
            ],
            'workouts': [
              {
                'id': 3,
                'name': 'Treino legado',
                'description': null,
                'sort_order': 0,
                'is_archived': 0,
              },
            ],
            'workout_exercises': [
              {
                'workout_id': 3,
                'exercise_id': 77,
                'order': 1,
                'sets': 3,
                'min_reps': 8,
                'max_reps': 10,
                'is_amrap': 0,
                'rest': 120,
                'duration': null,
                'group_id': null,
                'is_unilateral': 0,
                'notes': null,
              },
            ],
          },
          databaseSchemaVersion: 29,
        );

        final result = await repository.importBackup(
          BackupImportRequest(
            jsonContent: jsonEncode(payload),
            conflictResolutions: const {},
          ),
        );
        expect(result.isSuccess, isTrue);
        expect(result.getOrThrow().failedCount, 0);

        final countAfterRows =
            await db.customSelect('SELECT COUNT(*) AS c FROM exercises').get();
        expect(countAfterRows.first.data['c'], countBefore);

        final ghostNameRows = await db
            .customSelect(
              "SELECT COUNT(*) AS c FROM exercises WHERE name = 'flatBarbellBenchPress'",
            )
            .get();
        expect(ghostNameRows.first.data['c'], 0);

        final junction = await db
            .customSelect(
              'SELECT exercise_id FROM workout_exercises ORDER BY workout_id DESC LIMIT 1',
            )
            .get();
        expect(junction.first.data['exercise_id'], benchPressId);
      },
    );

    test(
      'importBackup schema 30+custom:user exercise isVerified false ainda pode ser inserido',
      () async {
        await seedExercises(db);

        final payload = _payloadWithTables(
          {
            'exercises': [
              {
                'id': 900,
                'catalog_remote_id': '',
                'name': 'meuExercicioCustomizado',
                'muscle_group': 'chest',
                'type': 'strength',
                'movement_pattern': 'push',
                'description': null,
                'is_verified': 0,
                'is_bodyweight': 0,
                'is_isometric': 0,
              },
            ],
          },
          databaseSchemaVersion: 30,
        );

        final result = await repository.importBackup(
          BackupImportRequest(
            jsonContent: jsonEncode(payload),
            conflictResolutions: const {},
          ),
        );
        expect(result.isSuccess, isTrue);

        final customRows = await db
            .customSelect(
              "SELECT COUNT(*) AS c FROM exercises WHERE name = 'meuExercicioCustomizado'",
            )
            .get();
        expect(customRows.first.data['c'], 1);
      },
    );
  });
}

Map<String, dynamic> _payloadWithTables(
  Map<String, List<Map<String, dynamic>>> tablesOverride, {
  int databaseSchemaVersion = 30,
}) {
  final tables = <String, List<Map<String, dynamic>>>{
    'user_profiles': [],
    'equipments': [],
    'exercises': [],
    'exercise_equipments': [],
    'exercise_target_muscles': [],
    'exercise_variations': [],
    'workouts': [],
    'workout_exercises': [],
    'workout_executions': [],
    'execution_sets': [],
    'execution_set_segments': [],
    'cycle_steps': [],
    'programs': [],
    'progression_rules': [],
    'body_metrics': [],
    'user_equipments': [],
  };
  tables.addAll(tablesOverride);

  return {
    'backupFormatVersion': 2,
    'databaseSchemaVersion': databaseSchemaVersion,
    'mode': 'user_only',
    'exportedAt': DateTime.now().toIso8601String(),
    'tables': tables,
    'catalogReferences': {'equipments': [], 'exercises': []},
  };
}
