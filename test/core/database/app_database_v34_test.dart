import 'package:athlos_app/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppDatabase v34 load mode schema', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('exercises table has new load mode columns', () async {
      final columns = await db
          .customSelect("PRAGMA table_info('exercises')")
          .get();
      final names = columns.map((r) => r.read<String>('name')).toSet();

      expect(names.contains('default_load_mode'), isTrue);
      expect(names.contains('bodyweight_load_factor'), isTrue);
      expect(names.contains('is_bodyweight'), isFalse);
    });

    test('workout_exercises table has load_mode_override', () async {
      final columns = await db
          .customSelect("PRAGMA table_info('workout_exercises')")
          .get();
      final names = columns.map((r) => r.read<String>('name')).toSet();

      expect(names.contains('load_mode_override'), isTrue);
    });

    test('seed sets default_load_mode and literature load factors', () async {
      final pushUp = await db
          .customSelect(
            "SELECT default_load_mode, bodyweight_load_factor FROM exercises "
            "WHERE name = 'pushUp' LIMIT 1",
          )
          .getSingle();
      expect(pushUp.read<String>('default_load_mode'), 'bodyweight');
      expect(
        pushUp.read<double?>('bodyweight_load_factor'),
        closeTo(0.64, 0.001),
      );

      final pullUp = await db
          .customSelect(
            "SELECT default_load_mode, bodyweight_load_factor FROM exercises "
            "WHERE name = 'pullUp' LIMIT 1",
          )
          .getSingle();
      expect(pullUp.read<String>('default_load_mode'), 'bodyweight');
      expect(
        pullUp.read<double?>('bodyweight_load_factor'),
        closeTo(1.00, 0.001),
      );

      final benchPress = await db
          .customSelect(
            "SELECT default_load_mode, bodyweight_load_factor FROM exercises "
            "WHERE name = 'benchPress' LIMIT 1",
          )
          .getSingle();
      expect(benchPress.read<String>('default_load_mode'), 'weighted');
      expect(benchPress.read<double?>('bodyweight_load_factor'), isNull);
    });
  });
}
