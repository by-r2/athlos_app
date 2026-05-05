import 'package:athlos_app/core/database/app_database.dart';
import 'package:athlos_app/core/errors/result.dart';
import 'package:athlos_app/features/training/data/datasources/daos/exercise_dao.dart';
import 'package:athlos_app/features/training/data/repositories/exercise_repository_impl.dart';
import 'package:athlos_app/features/training/domain/entities/exercise.dart'
    as domain;
import 'package:athlos_app/features/training/domain/enums/exercise_type.dart';
import 'package:athlos_app/features/training/domain/enums/movement_pattern.dart';
import 'package:athlos_app/features/training/domain/enums/muscle_group.dart';
import 'package:athlos_app/features/training/domain/enums/muscle_region.dart';
import 'package:athlos_app/features/training/domain/enums/muscle_role.dart';
import 'package:athlos_app/features/training/domain/enums/target_muscle.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExerciseRepositoryImpl', () {
    late AppDatabase db;
    late ExerciseRepositoryImpl repository;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repository = ExerciseRepositoryImpl(ExerciseDao(db));
      await db.customSelect('SELECT 1').get();
    });

    tearDown(() async {
      await db.close();
    });

    test('create/getById com muscle foci', () async {
      final id = (await repository.create(
        const domain.Exercise(
          id: 0,
          name: 'Supino Teste',
          muscleGroup: MuscleGroup.chest,
          type: ExerciseType.strength,
          movementPattern: MovementPattern.push,
          isVerified: false,
        ),
        muscles: const [
          (
            muscle: TargetMuscle.pectoralisMajor,
            region: MuscleRegion.upper,
            role: MuscleRole.primary
          ),
        ],
      ))
          .getOrThrow();

      final loaded = (await repository.getById(id)).getOrThrow();
      expect(loaded, isNotNull);
      expect(loaded!.name, 'Supino Teste');
      expect(loaded.muscles, isNotEmpty);
      expect(loaded.muscles.first.muscle, TargetMuscle.pectoralisMajor);
    });

    test('findByName case-insensitive e getByMuscleGroup', () async {
      final id = (await repository.create(
        const domain.Exercise(
          id: 0,
          name: 'Rosca Teste',
          muscleGroup: MuscleGroup.biceps,
          type: ExerciseType.strength,
        ),
      ))
          .getOrThrow();

      final byName = (await repository.findByName('  ROSCA teste ')).getOrThrow();
      expect(byName, isNotNull);
      expect(byName!.id, id);

      final byGroup = (await repository.getByMuscleGroup(MuscleGroup.biceps))
          .getOrThrow();
      expect(byGroup.any((e) => e.id == id), isTrue);
    });

    test('variations add/remove', () async {
      final id1 = (await repository.create(
        const domain.Exercise(
          id: 0,
          name: 'Agachamento Teste',
          muscleGroup: MuscleGroup.quadriceps,
        ),
      ))
          .getOrThrow();
      final id2 = (await repository.create(
        const domain.Exercise(
          id: 0,
          name: 'Agachamento Hack Teste',
          muscleGroup: MuscleGroup.quadriceps,
        ),
      ))
          .getOrThrow();

      expect((await repository.addVariation(id1, id2)).isSuccess, isTrue);
      final variations = (await repository.getVariations(id1)).getOrThrow();
      expect(variations.any((e) => e.id == id2), isTrue);

      expect((await repository.removeVariation(id1, id2)).isSuccess, isTrue);
      final variationsAfter = (await repository.getVariations(id1)).getOrThrow();
      expect(variationsAfter.any((e) => e.id == id2), isFalse);
    });
  });
}
