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
  Future<Result<List<Exercise>>> getByMuscleGroup(MuscleGroup group);
  Future<Result<List<Exercise>>> getVariations(int exerciseId);
  Future<Result<List<int>>> getEquipmentIds(int exerciseId);
  Future<Result<Map<int, List<int>>>> getEquipmentMap();
  Future<Result<List<ExerciseMuscleFocus>>> getMuscleFoci(int exerciseId);
  Future<Result<int>> create(
    Exercise exercise, {
    List<int> equipmentIds = const [],
    List<({TargetMuscle muscle, MuscleRegion? region, MuscleRole role})>
        muscles = const [],
  });
  Future<Result<void>> update(
    Exercise exercise, {
    List<int>? equipmentIds,
    List<({TargetMuscle muscle, MuscleRegion? region, MuscleRole role})>?
        muscles,
  });
  Future<Result<void>> delete(int id);
  Future<Result<void>> addVariation(int exerciseId, int variationId);
  Future<Result<void>> removeVariation(int exerciseId, int variationId);
}
