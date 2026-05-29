import 'package:athlos_app/core/database/app_database.dart';
import 'package:athlos_app/features/training/data/datasources/daos/workout_execution_dao.dart';
import 'package:athlos_app/features/training/domain/enums/session_kind.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('getLastFinishedForCycle', () {
    late AppDatabase db;
    late WorkoutExecutionDao dao;
    const userId = 'user-1';
    const programId = 'prog-1';
    const workoutA = 'workout-a';
    const workoutB = 'workout-b';
    const workoutAdHoc = 'workout-adhoc';

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      dao = WorkoutExecutionDao(db);

      for (final id in [workoutA, workoutB, workoutAdHoc]) {
        await db.into(db.workouts).insert(
          WorkoutsCompanion.insert(
            id: id,
            userId: userId,
            name: id,
            isDraft: Value(id == workoutAdHoc),
          ),
        );
      }

      await dao.create(
        WorkoutExecutionsCompanion.insert(
          id: 'exec-planned',
          userId: userId,
          workoutId: workoutA,
          programId: programId,
          sessionKind: const Value(SessionKind.planned),
          startedAt: Value(DateTime(2026, 1, 1, 10)),
          finishedAt: Value(DateTime(2026, 1, 1, 11)),
        ),
      );

      await dao.create(
        WorkoutExecutionsCompanion.insert(
          id: 'exec-adhoc',
          userId: userId,
          workoutId: workoutAdHoc,
          programId: programId,
          sessionKind: const Value(SessionKind.adHoc),
          startedAt: Value(DateTime(2026, 1, 2, 10)),
          finishedAt: Value(DateTime(2026, 1, 2, 11)),
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('returns last planned finish in cycle, not newer ad-hoc', () async {
      final last = await dao.getLastFinishedForCycle(
        userId: userId,
        programId: programId,
        cycleWorkoutIds: [workoutA, workoutB],
      );
      expect(last?.workoutId, workoutA);
    });

    test('getLastFinished returns ad-hoc when it is most recent globally', () async {
      final last = await dao.getLastFinished(userId);
      expect(last?.workoutId, workoutAdHoc);
    });
  });
}
