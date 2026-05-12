import '../../../../core/errors/result.dart';
import '../entities/exercise.dart';
import '../enums/muscle_group.dart';
import '../enums/muscle_region.dart';
import '../enums/muscle_role.dart';
import '../enums/target_muscle.dart';

/// Contract for exercise data operations.
abstract interface class ExerciseRepository {
  Future<Result<List<Exercise>>> getAll();
  Future<Result<Exercise?>> getById(int id);

  /// Case-insensitive lookup by exercise name. Returns the first match or null.
  Future<Result<Exercise?>> findByName(String name);

  /// Fuzzy lookup: tries exact, then diacritics-normalized, then containment.
  Future<Result<Exercise?>> findByNameFuzzy(String name);
  Future<Result<List<Exercise>>> getByMuscleGroup(MuscleGroup group);
  Future<Result<List<Exercise>>> getVariations(int exerciseId);
  Future<Result<List<ExerciseMuscleFocus>>> getMuscleFoci(int exerciseId);
  Future<Result<int>> create(
    Exercise exercise, {
    List<({TargetMuscle muscle, MuscleRegion? region, MuscleRole role})>
        muscles =
        const [],
  });
  Future<Result<void>> update(
    Exercise exercise, {
    List<({TargetMuscle muscle, MuscleRegion? region, MuscleRole role})>?
    muscles,
  });
  Future<Result<void>> delete(int id);
  Future<Result<void>> addVariation(int exerciseId, int variationId);
  Future<Result<void>> removeVariation(int exerciseId, int variationId);
}
