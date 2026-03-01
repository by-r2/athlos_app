import 'package:drift/drift.dart';

import '../../../../../core/database/app_database.dart';
import '../../../../training/domain/enums/muscle_group.dart';
import '../../../../training/domain/enums/muscle_region.dart';
import '../../../../training/domain/enums/muscle_role.dart';
import '../../../../training/domain/enums/target_muscle.dart';
import '../tables/equipments_table.dart';
import '../tables/exercise_equipments_table.dart';
import '../tables/exercise_target_muscles_table.dart';
import '../tables/exercise_variations_table.dart';
import '../tables/exercises_table.dart';

part 'exercise_dao.g.dart';

@DriftAccessor(
  tables: [
    Exercises,
    ExerciseEquipments,
    ExerciseVariations,
    ExerciseTargetMuscles,
    Equipments,
  ],
)
class ExerciseDao extends DatabaseAccessor<AppDatabase>
    with _$ExerciseDaoMixin {
  ExerciseDao(super.db);

  Future<List<Exercise>> getAll() => select(exercises).get();

  Future<Exercise?> getById(int id) =>
      (select(exercises)..where((e) => e.id.equals(id))).getSingleOrNull();

  /// Case-insensitive name lookup. Returns the first matching exercise id, or null.
  Future<int?> findIdByName(String name) async {
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    final all = await select(exercises).get();
    for (final row in all) {
      if (row.name.trim().toLowerCase() == normalized) return row.id;
    }
    return null;
  }

  Future<List<Exercise>> getByMuscleGroup(MuscleGroup group) =>
      (select(exercises)..where((e) => e.muscleGroup.equalsValue(group))).get();

  Future<int> create(ExercisesCompanion entry) =>
      into(exercises).insert(entry);

  Future<void> updateById(int id, ExercisesCompanion entry) =>
      (update(exercises)..where((e) => e.id.equals(id))).write(entry);

  Future<void> deleteById(int id) =>
      (delete(exercises)..where((e) => e.id.equals(id))).go();

  // --- Equipment relations ---

  Future<List<int>> getEquipmentIds(int exerciseId) async {
    final rows = await (select(exerciseEquipments)
          ..where((e) => e.exerciseId.equals(exerciseId)))
        .get();
    return rows.map((r) => r.equipmentId).toList();
  }

  /// Returns all exercise→equipment mappings as a map.
  Future<Map<int, List<int>>> getAllEquipmentMappings() async {
    final rows = await select(exerciseEquipments).get();
    final map = <int, List<int>>{};
    for (final row in rows) {
      map.putIfAbsent(row.exerciseId, () => []).add(row.equipmentId);
    }
    return map;
  }

  Future<void> setEquipments(int exerciseId, List<int> equipmentIds) async {
    await (delete(exerciseEquipments)
          ..where((e) => e.exerciseId.equals(exerciseId)))
        .go();
    for (final eqId in equipmentIds) {
      await into(exerciseEquipments).insert(
        ExerciseEquipmentsCompanion(
          exerciseId: Value(exerciseId),
          equipmentId: Value(eqId),
        ),
      );
    }
  }

  // --- Muscle targeting relations ---

  Future<List<ExerciseTargetMuscle>> getMuscleFoci(int exerciseId) =>
      (select(exerciseTargetMuscles)
            ..where((e) => e.exerciseId.equals(exerciseId)))
          .get();

  Future<void> setMuscleFoci(
    int exerciseId,
    List<({TargetMuscle muscle, MuscleRegion? region, MuscleRole role})> foci,
  ) async {
    await (delete(exerciseTargetMuscles)
          ..where((e) => e.exerciseId.equals(exerciseId)))
        .go();
    for (final focus in foci) {
      await into(exerciseTargetMuscles).insert(
        ExerciseTargetMusclesCompanion(
          exerciseId: Value(exerciseId),
          targetMuscle: Value(focus.muscle),
          muscleRegion: Value(focus.region),
          role: Value(focus.role),
        ),
      );
    }
  }

  // --- Variation relations ---

  Future<List<Exercise>> getVariations(int exerciseId) {
    final query = select(exercises).join([
      innerJoin(
        exerciseVariations,
        exerciseVariations.variationId.equalsExp(exercises.id),
      ),
    ])
      ..where(exerciseVariations.exerciseId.equals(exerciseId));
    return query.map((row) => row.readTable(exercises)).get();
  }

  Future<void> addVariation(int exerciseId, int variationId) =>
      into(exerciseVariations).insert(
        ExerciseVariationsCompanion(
          exerciseId: Value(exerciseId),
          variationId: Value(variationId),
        ),
      );

  Future<void> removeVariation(int exerciseId, int variationId) =>
      (delete(exerciseVariations)
            ..where((e) =>
                e.exerciseId.equals(exerciseId) &
                e.variationId.equals(variationId)))
          .go();
}
