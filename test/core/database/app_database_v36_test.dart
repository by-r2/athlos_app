import 'package:athlos_app/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppDatabase v36 auth sync schema', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('user_profiles has remote sync metadata', () async {
      final columns = await db
          .customSelect("PRAGMA table_info('user_profiles')")
          .get();
      final names = columns.map((r) => r.read<String>('name')).toSet();

      expect(names.contains('remote_user_id'), isTrue);
      expect(names.contains('last_synced_at'), isTrue);
    });

    test('sync_records exists for gradual remote migration', () async {
      final columns = await db
          .customSelect("PRAGMA table_info('sync_records')")
          .get();
      final names = columns.map((r) => r.read<String>('name')).toSet();

      expect(names.contains('table_name'), isTrue);
      expect(names.contains('local_id'), isTrue);
      expect(names.contains('sync_id'), isTrue);
      expect(names.contains('remote_id'), isTrue);
      expect(names.contains('remote_user_id'), isTrue);
    });
  });
}
