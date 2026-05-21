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

@DriftAccessor(tables: [Exercises, ExerciseVariations, ExerciseTargetMuscles])
class ExerciseDao extends DatabaseAccessor<AppDatabase>
    with _$ExerciseDaoMixin {
  ExerciseDao(super.db);

  Future<void> _markDirty(String id) {
    final now = DateTime.now().toUtc();
    return (update(exercises)..where((e) => e.id.equals(id))).write(
      ExercisesCompanion(
        isDirty: const Value(true),
        updatedAt: Value(now),
      ),
    );
  }

  Future<List<Exercise>> getAll() =>
      (select(exercises)..where((e) => e.deletedAt.isNull())).get();

  /// Returns exercises visible to the user: verified OR created by them.
  Future<List<Exercise>> getVisible(String userId) =>
      (select(exercises)
            ..where(
              (e) =>
                  e.deletedAt.isNull() &
                  (e.isVerified.equals(true) | e.createdBy.equals(userId)),
            ))
          .get();

  Future<Exercise?> getById(String id) =>
      (select(exercises)
            ..where((e) => e.id.equals(id) & e.deletedAt.isNull()))
          .getSingleOrNull();

  /// Same-name guard for inserts: canonical + verified locale synonyms.
  Future<String?> findIdByConflictingName(String name) async {
    final all = await getAll();
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
  Future<String?> findIdByName(String name) async {
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    final all = await getAll();
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
  Future<String?> findIdByNameFuzzy(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;

    final byExactStages = await findIdByName(name);
    if (byExactStages != null) return byExactStages;

    final inputNorm = ExerciseLabelNormalizer.normalize(trimmed);
    if (inputNorm.isEmpty) return null;

    final all = await getAll();

    for (final row in all) {
      final rowNorm = ExerciseLabelNormalizer.normalize(row.name);
      if (rowNorm == inputNorm) return row.id;
    }

    String? bestId;
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

  Future<List<Exercise>> getByMuscleGroup(
    MuscleGroup group, {
    required String userId,
  }) =>
      (select(exercises)
            ..where(
              (e) =>
                  e.muscleGroup.equalsValue(group) &
                  e.deletedAt.isNull() &
                  (e.isVerified.equals(true) | e.createdBy.equals(userId)),
            ))
          .get();

  Future<void> create(ExercisesCompanion entry) async {
    await into(exercises).insert(entry);
    await _markDirty(entry.id.value);
  }

  Future<void> updateById(String id, ExercisesCompanion entry) async {
    await (update(exercises)..where((e) => e.id.equals(id))).write(entry);
    await _markDirty(id);
  }

  Future<void> deleteById(String id) {
    final now = DateTime.now().toUtc();
    return (update(exercises)..where((e) => e.id.equals(id))).write(
      ExercisesCompanion(
        deletedAt: Value(now),
        isDirty: const Value(true),
        updatedAt: Value(now),
      ),
    );
  }

  /// Returns user-created (non-verified) exercises.
  Future<List<Exercise>> getByUser(String userId) =>
      (select(exercises)
            ..where(
              (e) =>
                  e.createdBy.equals(userId) &
                  e.isVerified.equals(false) &
                  e.deletedAt.isNull(),
            ))
          .get();

  // --- Muscle targeting relations ---

  Future<List<ExerciseTargetMuscle>> getMuscleFoci(String exerciseId) =>
      (select(exerciseTargetMuscles)
            ..where((e) => e.exerciseId.equals(exerciseId)))
          .get();

  Future<void> setMuscleFoci(
    String exerciseId,
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
    await _markDirty(exerciseId);
  }

  // --- Variation relations ---

  Future<List<Exercise>> getVariations(String exerciseId) {
    final query = select(exercises).join([
      innerJoin(
        exerciseVariations,
        exerciseVariations.variationId.equalsExp(exercises.id),
      ),
    ])
      ..where(
        exerciseVariations.exerciseId.equals(exerciseId) &
            exercises.deletedAt.isNull(),
      );
    return query.map((row) => row.readTable(exercises)).get();
  }

  Future<void> addVariation(String exerciseId, String variationId) async {
    await into(exerciseVariations).insert(
      ExerciseVariationsCompanion(
        exerciseId: Value(exerciseId),
        variationId: Value(variationId),
      ),
    );
    await _markDirty(exerciseId);
  }

  Future<void> removeVariation(String exerciseId, String variationId) async {
    await (delete(exerciseVariations)
          ..where(
            (e) =>
                e.exerciseId.equals(exerciseId) &
                e.variationId.equals(variationId),
          ))
        .go();
    await _markDirty(exerciseId);
  }
}
