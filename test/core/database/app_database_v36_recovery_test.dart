import 'package:athlos_app/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// Simulates a device stuck after a partial v36 migration (column added, version
/// not bumped) so upgrades can finish without duplicate-column errors.
void main() {
  group('AppDatabase v36 recovery', () {
    test('completes upgrade when remote_user_id already exists at v35', () async {
      final sqlite = sqlite3.openInMemory();
      sqlite.execute('''
        CREATE TABLE user_profiles (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          name TEXT,
          remote_user_id TEXT
        )
      ''');
      sqlite.execute('''
        CREATE TABLE body_metrics (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          profile_id INTEGER NOT NULL,
          recorded_at INTEGER NOT NULL,
          weight REAL
        )
      ''');
      sqlite.execute('PRAGMA user_version = 35');

      final executor = NativeDatabase.opened(sqlite);
      final db = AppDatabase.forTesting(executor, enableDevSeed: false);
      addTearDown(db.close);

      await db.customSelect('SELECT 1').get();

      final versionRow = await db
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(versionRow.data['user_version'], 39);

      final profileColumns = await db
          .customSelect("PRAGMA table_info('user_profiles')")
          .get();
      final profileNames =
          profileColumns.map((row) => row.read<String>('name')).toSet();
      expect(profileNames.contains('remote_user_id'), isTrue);
      expect(profileNames.contains('last_synced_at'), isTrue);
      expect(profileNames.contains('local_updated_at'), isTrue);

      final syncTable = await db
          .customSelect(
            "SELECT name FROM sqlite_master "
            "WHERE type = 'table' AND name = 'sync_records'",
          )
          .getSingleOrNull();
      expect(syncTable, isNot(null));
    });
  });
}
