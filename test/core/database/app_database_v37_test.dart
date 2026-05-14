import 'package:athlos_app/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppDatabase v37 body metrics sync schema', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('body_metrics has remote sync metadata', () async {
      final columns = await db
          .customSelect("PRAGMA table_info('body_metrics')")
          .get();
      final names = columns.map((r) => r.read<String>('name')).toSet();

      expect(names.contains('remote_id'), isTrue);
      expect(names.contains('last_synced_at'), isTrue);
    });
  });
}
