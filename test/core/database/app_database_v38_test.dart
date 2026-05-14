import 'package:athlos_app/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppDatabase v38 user-owned sync schema', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('user_profiles and body_metrics expose local_updated_at', () async {
      final profileColumns = await db
          .customSelect("PRAGMA table_info('user_profiles')")
          .get();
      final profileNames =
          profileColumns.map((row) => row.read<String>('name')).toSet();
      expect(profileNames.contains('local_updated_at'), isTrue);

      final metricColumns = await db
          .customSelect("PRAGMA table_info('body_metrics')")
          .get();
      final metricNames =
          metricColumns.map((row) => row.read<String>('name')).toSet();
      expect(metricNames.contains('local_updated_at'), isTrue);
    });

    test('sync_records exposes last_pushed_at and remote index', () async {
      final columns = await db
          .customSelect("PRAGMA table_info('sync_records')")
          .get();
      final names = columns.map((row) => row.read<String>('name')).toSet();
      expect(names.contains('last_pushed_at'), isTrue);

      final indexes = await db
          .customSelect("PRAGMA index_list('sync_records')")
          .get();
      final indexNames =
          indexes.map((row) => row.read<String>('name')).toList();
      expect(
        indexNames.any((name) => name.contains('remote_id')),
        isTrue,
      );
    });
  });
}
