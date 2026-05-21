import 'package:athlos_app/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppDatabase v40 UUID-first schema', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('user_profiles uses text id and is_dirty', () async {
      final columns = await db
          .customSelect("PRAGMA table_info('user_profiles')")
          .get();
      final names = columns.map((r) => r.read<String>('name')).toSet();

      expect(names.contains('id'), isTrue);
      expect(names.contains('is_dirty'), isTrue);
      expect(names.contains('remote_user_id'), isFalse);
      expect(names.contains('last_synced_at'), isFalse);
    });

    test('body_metrics uses text id, user_id, is_dirty', () async {
      final columns = await db
          .customSelect("PRAGMA table_info('body_metrics')")
          .get();
      final names = columns.map((r) => r.read<String>('name')).toSet();

      expect(names.contains('id'), isTrue);
      expect(names.contains('user_id'), isTrue);
      expect(names.contains('is_dirty'), isTrue);
      expect(names.contains('remote_id'), isFalse);
    });

    test('sync_records table was removed', () async {
      final tables = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='sync_records'",
          )
          .get();
      expect(tables, isEmpty);
    });

    test('workouts uses text id and user_id', () async {
      final columns = await db
          .customSelect("PRAGMA table_info('workouts')")
          .get();
      final names = columns.map((r) => r.read<String>('name')).toSet();

      expect(names.contains('id'), isTrue);
      expect(names.contains('user_id'), isTrue);
      expect(names.contains('is_dirty'), isTrue);
    });
  });
}
