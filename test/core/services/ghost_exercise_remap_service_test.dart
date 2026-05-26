import 'package:athlos_app/core/database/app_database.dart';
import 'package:athlos_app/core/services/ghost_exercise_remap_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GhostExerciseRemapService', () {
    late AppDatabase db;
    late GhostExerciseRemapService service;

    const userA = 'user-a';
    const userB = 'user-b';
    const ghostId = 'ghost-exercise-id';
    const targetId = 'target-exercise-id';
    const workoutId = 'workout-1';
    const weId = 'we-1';

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      service = GhostExerciseRemapService(db);

      await db.customInsert(
        "INSERT INTO exercises (id, name, muscle_group, type, is_verified, created_by) "
        "VALUES ('$ghostId', 'ghostCanon', 'chest', 'strength', 0, '$userA')",
      );
      await db.customInsert(
        "INSERT INTO exercises (id, name, muscle_group, type, is_verified, created_by) "
        "VALUES ('$targetId', 'benchPress', 'chest', 'strength', 1, '')",
      );
      await db.customInsert(
        "INSERT INTO workouts (id, user_id, name, sort_order, is_archived) "
        "VALUES ('$workoutId', '$userA', 'W', 0, 0)",
      );
      await db.customInsert(
        "INSERT INTO workout_exercises (id, user_id, workout_id, exercise_id, sort_order, sets, rest_seconds) "
        "VALUES ('$weId', '$userA', '$workoutId', '$ghostId', 0, 3, 60)",
      );
      await db.customInsert(
        "INSERT INTO workout_exercises (id, user_id, workout_id, exercise_id, sort_order, sets, rest_seconds) "
        "VALUES ('we-b', '$userB', '$workoutId', '$ghostId', 0, 3, 60)",
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('preview counts only rows for the given user', () async {
      final preview = await service.previewForUser(
        userId: userA,
        ghostExerciseId: ghostId,
      );
      expect(preview.workoutExercises, 1);
      expect(preview.executionSets, 0);
    });

    test('remap updates only the requesting user rows', () async {
      await service.remapForUser(
        userId: userA,
        ghostExerciseId: ghostId,
        targetExerciseId: targetId,
      );

      final userARow = await db.customSelect(
        "SELECT exercise_id FROM workout_exercises WHERE id = '$weId'",
      ).getSingle();
      expect(userARow.data['exercise_id'], targetId);

      final userBRow = await db.customSelect(
        "SELECT exercise_id FROM workout_exercises WHERE id = 'we-b'",
      ).getSingle();
      expect(userBRow.data['exercise_id'], ghostId);
    });

    test('lookupExerciseRow returns stored name even when deleted', () async {
      await db.customUpdate(
        "UPDATE exercises SET deleted_at = datetime('now') WHERE id = '$ghostId'",
      );
      final row = await service.lookupExerciseRow(ghostId);
      expect(row?.name, 'ghostCanon');
      expect(row?.isDeleted, isTrue);
    });
  });
}
