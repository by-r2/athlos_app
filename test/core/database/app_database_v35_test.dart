import 'package:athlos_app/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppDatabase v35 snapshot and notes cleanup schema', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('execution_sets has snapshot and per-set mode override', () async {
      final columns = await db
          .customSelect("PRAGMA table_info('execution_sets')")
          .get();
      final names = columns.map((r) => r.read<String>('name')).toSet();

      expect(names.contains('body_weight_snapshot'), isTrue);
      expect(names.contains('load_mode_override'), isTrue);
    });

    test('execution_sets.notes and workout_executions.notes are removed', () async {
      final setColumns = await db
          .customSelect("PRAGMA table_info('execution_sets')")
          .get();
      final setNames = setColumns.map((r) => r.read<String>('name')).toSet();
      expect(setNames.contains('notes'), isFalse);

      final executionColumns = await db
          .customSelect("PRAGMA table_info('workout_executions')")
          .get();
      final executionNames =
          executionColumns.map((r) => r.read<String>('name')).toSet();
      expect(executionNames.contains('notes'), isFalse);
    });
  });
}
