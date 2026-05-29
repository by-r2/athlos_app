import 'package:athlos_app/features/training/domain/entities/workout_exercise.dart';
import 'package:athlos_app/features/training/presentation/helpers/superset_grouping.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutExercise _ex(String id, {int? groupId, int rest = 60, int sortOrder = 0}) =>
    WorkoutExercise(
      id: 'we-$id',
      workoutId: 'w1',
      exerciseId: id,
      sortOrder: sortOrder,
      sets: 3,
      minReps: 12,
      maxReps: 12,
      restSeconds: rest,
      groupId: groupId,
    );

void main() {
  group('applySupersetSelection', () {
    test('new group does not clear exercises in other supersets', () {
      const gid1 = 1;
      final exercises = [
        _ex('a', groupId: gid1),
        _ex('b', groupId: gid1),
        _ex('c'),
        _ex('d'),
      ];

      final result = applySupersetSelection(
        exercises,
        {'c', 'd'},
        editingGroupId: null,
      );

      final byId = {for (final e in result) e.exerciseId: e};
      expect(byId['a']!.groupId, gid1);
      expect(byId['b']!.groupId, gid1);
      final newGid = byId['c']!.groupId;
      expect(newGid, isNotNull);
      expect(byId['d']!.groupId, newGid);
      expect(newGid, isNot(gid1));
      expect(result.map((e) => e.exerciseId).toList(), ['a', 'b', 'c', 'd']);
    });

    test('links selected exercises when at least two marked', () {
      final exercises = [_ex('a'), _ex('b'), _ex('c')];

      final result = applySupersetSelection(exercises, {'a', 'c'});

      final byId = {for (final e in result) e.exerciseId: e};
      final gid = byId['a']!.groupId;
      expect(gid, isNotNull);
      expect(byId['c']!.groupId, gid);
      expect(byId['b']!.groupId, isNull);
      expect(result.map((e) => e.exerciseId).toList(), ['a', 'c', 'b']);
    });

    test('clears group when fewer than two marked in scope', () {
      const gid = 1;
      final exercises = [_ex('a', groupId: gid), _ex('b', groupId: gid)];

      final result = applySupersetSelection(
        exercises,
        {'a'},
        editingGroupId: gid,
      );

      expect(result[0].groupId, isNull);
      expect(result[1].groupId, isNull);
    });
  });

  group('reorderSupersetBlocksContiguously', () {
    test('pulls distant group members next to the first member', () {
      const gid = 1;
      final exercises = [
        _ex('a', groupId: gid, sortOrder: 0),
        _ex('b', sortOrder: 1),
        _ex('c', groupId: gid, sortOrder: 2),
        _ex('d', sortOrder: 3),
      ];

      final result = reorderSupersetBlocksContiguously(exercises);

      expect(result.map((e) => e.exerciseId).toList(), ['a', 'c', 'b', 'd']);
      expect(result[0].sortOrder, 0);
      expect(result[3].sortOrder, 3);
    });

    test('keeps two separate group blocks in list order', () {
      final exercises = [
        _ex('a', groupId: 1),
        _ex('b', groupId: 1),
        _ex('c', groupId: 2),
        _ex('d', groupId: 2),
      ];

      final result = reorderSupersetBlocksContiguously(exercises);

      expect(result.map((e) => e.exerciseId).toList(), ['a', 'b', 'c', 'd']);
    });
  });

  group('applySupersetSelection', () {
    test('joining end exercise to start group reorders contiguously', () {
      const gid = 1;
      final exercises = [
        _ex('a', groupId: gid),
        _ex('b'),
        _ex('c'),
        _ex('d'),
      ];

      final result = applySupersetSelection(
        exercises,
        {'a', 'd'},
        editingGroupId: gid,
      );

      expect(result.map((e) => e.exerciseId).toList(), ['a', 'd', 'b', 'c']);
      expect(result[0].groupId, gid);
      expect(result[1].groupId, gid);
      expect(result[2].groupId, isNull);
    });
  });

  group('reorderExercisesInList', () {
    test('moves a single exercise and reindexes sortOrder', () {
      final exercises = [
        _ex('a', sortOrder: 0),
        _ex('b', sortOrder: 1),
        _ex('c', sortOrder: 2),
      ];

      final result = reorderExercisesInList(exercises, 0, 2);

      expect(result.map((e) => e.exerciseId).toList(), ['b', 'a', 'c']);
      expect(result.map((e) => e.sortOrder).toList(), [0, 1, 2]);
    });

    test('moves a full superset block together', () {
      const gid = 1;
      final exercises = [
        _ex('a', groupId: gid, sortOrder: 0),
        _ex('b', groupId: gid, sortOrder: 1),
        _ex('c', sortOrder: 2),
        _ex('d', sortOrder: 3),
      ];

      final result = reorderExercisesInList(exercises, 0, 3);

      expect(result.map((e) => e.exerciseId).toList(), ['c', 'a', 'b', 'd']);
      expect(result[1].groupId, gid);
      expect(result[2].groupId, gid);
    });
  });

  group('unlinkExerciseFromSuperset', () {
    test('removes only the target exercise from its group', () {
      const gid = 1;
      final exercises = [
        _ex('a', groupId: gid),
        _ex('b', groupId: gid),
        _ex('c', groupId: 2),
        _ex('d', groupId: 2),
      ];

      final result = unlinkExerciseFromSuperset(exercises, 'a');

      expect(result[0].groupId, isNull);
      expect(result[1].groupId, isNull);
      expect(result[2].groupId, 2);
      expect(result[3].groupId, 2);
    });
  });
}
