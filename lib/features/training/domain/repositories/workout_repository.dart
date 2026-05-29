import '../../../../core/errors/result.dart';
import '../entities/workout.dart';
import '../entities/workout_exercise.dart';

/// Contract for workout data operations.
abstract interface class WorkoutRepository {
  Future<Result<List<Workout>>> getAll();
  Future<Result<List<Workout>>> getActive();
  Future<Result<List<Workout>>> getArchived();
  Future<Result<Workout?>> getById(String id);
  Future<Result<String>> create(Workout workout, List<WorkoutExercise> exercises);

  /// Creates a hidden draft workout for ad-hoc execution (no exercises).
  Future<Result<String>> createDraft({required String name});

  /// Clears [isDraft] and sets the display [name].
  Future<Result<void>> promoteDraft(String workoutId, {required String name});

  /// Archives a draft that will not be saved as a reusable template.
  Future<Result<void>> archiveDraft(String workoutId);
  Future<Result<void>> update(Workout workout, List<WorkoutExercise> exercises);
  Future<Result<void>> delete(String id);
  Future<Result<void>> archive(String id);
  Future<Result<void>> unarchive(String id);
  Future<Result<String>> duplicate(String id, {required String nameSuffix});
  Future<Result<void>> reorder(List<String> orderedIds);
  Future<Result<List<WorkoutExercise>>> getExercises(String workoutId);
}
