import 'package:drift/drift.dart';

import '../../../../../core/database/app_database.dart';
import '../../../../../core/localization/exercise_catalog_label_index.dart';
import '../../../../../core/localization/exercise_label_normalization.dart';
import '../../../../training/domain/exercise_name_match.dart';
import '../../../../training/domain/enums/muscle_group.dart';
import '../../../../training/domain/enums/muscle_region.dart';
import '../../../../training/domain/enums/muscle_role.dart';
import '../../../../training/domain/enums/target_muscle.dart';
import '../tables/exercise_target_muscles_table.dart';
import '../tables/exercise_variations_table.dart';
import '../tables/exercises_table.dart';

part 'exercise_dao.g.dart';

@DriftAccessor(
  tables: [
    Exercises,
    ExerciseVariations,
    ExerciseTargetMuscles,
  ],
)
class ExerciseDao extends DatabaseAccessor<AppDatabase>
    with _$ExerciseDaoMixin {
  ExerciseDao(super.db);

  Future<List<Exercise>> getAll() => select(exercises).get();

  Future<Exercise?> getById(int id) =>
      (select(exercises)..where((e) => e.id.equals(id))).getSingleOrNull();

  /// Same-name guard for inserts: canonical + verified locale synonyms.
  Future<int?> findIdByConflictingName(String name) async {
    final all = await select(exercises).get();
    for (final row in all) {
      if (ExerciseNameMatch.collidesWithCanonicalRow(
            name,
            canonicalName: row.name,
            isVerified: row.isVerified,
          )) {
        return row.id;
      }
    }
    return null;
  }

  /// Case-insensitive name lookup. Returns the first matching exercise id, or null.
  Future<int?> findIdByName(String name) async {
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    final all = await select(exercises).get();
    // Pass 1: exact case-insensitive match on persisted key
    for (final row in all) {
      if (row.name.trim().toLowerCase() == normalized) return row.id;
    }

    final resolvedCanon = exerciseCatalogLabelIndex.tryResolveCanonicalStrict(
      name,
    );
    if (resolvedCanon != null) {
      for (final row in all) {
        if (row.isVerified && row.name == resolvedCanon) return row.id;
      }
    }
    return null;
  }

  /// Fuzzy name lookup: [findIdByName], then diacritic-insensitive containment
  /// on persisted keys and verified synonyms.
  Future<int?> findIdByNameFuzzy(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;

    final byExactStages = await findIdByName(name);
    if (byExactStages != null) return byExactStages;

    final inputNorm = ExerciseLabelNormalizer.normalize(trimmed);
    if (inputNorm.isEmpty) return null;

    final all = await select(exercises).get();

    // Diacritic-insensitive equality on persisted key (custom + verified)
    for (final row in all) {
      final rowNorm = ExerciseLabelNormalizer.normalize(row.name);
      if (rowNorm == inputNorm) return row.id;
    }

    // Containment — pick the candidate whose length is closest to input
    int? bestId;
    var bestDelta = 999;
    for (final row in all) {
      for (final target in _rowFuzzyLabelTargets(row.name, row.isVerified)) {
        final rowNorm = ExerciseLabelNormalizer.normalize(target);
        if (rowNorm.isEmpty) continue;
        if (rowNorm.contains(inputNorm) || inputNorm.contains(rowNorm)) {
          final delta = (rowNorm.length - inputNorm.length).abs();
          if (delta < bestDelta) {
            bestId = row.id;
            bestDelta = delta;
          }
        }
      }
    }
    return bestId;
  }

  Iterable<String> _rowFuzzyLabelTargets(String name, bool isVerified) sync* {
    yield name;
    if (isVerified && exerciseCatalogLabelIndex.isKnownCanonicalKey(name)) {
      yield* exerciseCatalogLabelIndex.surfaceForms(name);
    }
  }

  Future<List<Exercise>> getByMuscleGroup(MuscleGroup group) =>
      (select(exercises)..where((e) => e.muscleGroup.equalsValue(group))).get();

  Future<int> create(ExercisesCompanion entry) =>
      into(exercises).insert(entry);

  Future<void> updateById(int id, ExercisesCompanion entry) =>
      (update(exercises)..where((e) => e.id.equals(id))).write(entry);

  Future<void> deleteById(int id) =>
      (delete(exercises)..where((e) => e.id.equals(id))).go();

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
