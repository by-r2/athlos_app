import '../../../../core/errors/result.dart';
import '../entities/workout.dart';
import '../entities/workout_exercise.dart';

/// Contract for workout data operations.
abstract interface class WorkoutRepository {
  Future<Result<List<Workout>>> getAll();
  Future<Result<List<Workout>>> getActive();
  Future<Result<List<Workout>>> getArchived();
  Future<Result<Workout?>> getById(int id);
  Future<Result<int>> create(Workout workout, List<WorkoutExercise> exercises);
  Future<Result<void>> update(Workout workout, List<WorkoutExercise> exercises);
  Future<Result<void>> delete(int id);
  Future<Result<void>> archive(int id);
  Future<Result<void>> unarchive(int id);
  Future<Result<int>> duplicate(int id);
  Future<Result<void>> reorder(List<int> orderedIds);
  Future<Result<List<WorkoutExercise>>> getExercises(int workoutId);
}
