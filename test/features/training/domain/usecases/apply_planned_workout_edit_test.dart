import 'package:athlos_app/core/errors/result.dart';
import 'package:athlos_app/features/training/domain/entities/workout.dart';
import 'package:athlos_app/features/training/domain/entities/workout_exercise.dart';
import 'package:athlos_app/features/training/domain/repositories/workout_repository.dart';
import 'package:athlos_app/features/training/domain/usecases/apply_planned_workout_edit.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeWorkoutRepo implements WorkoutRepository {
  _FakeWorkoutRepo({required this.workout});

  Workout workout;
  List<WorkoutExercise>? lastUpdatedExercises;

  @override
  Future<Result<void>> update(Workout workout, List<WorkoutExercise> exercises) async {
    lastUpdatedExercises = exercises;
    this.workout = workout;
    return const Success(null);
  }

  @override
  Future<Result<Workout?>> getById(String id) async => Success(workout);

  @override
  Future<Result<String>> createDraft({required String name}) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> promoteDraft(String workoutId, {required String name}) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> archiveDraft(String workoutId) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> deleteDraft(String workoutId) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> persistDraftExercises(
    String workoutId,
    List<WorkoutExercise> exercises,
  ) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> archive(String id) => throw UnimplementedError();

  @override
  Future<Result<String>> create(Workout workout, List<WorkoutExercise> exercises) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> delete(String id) => throw UnimplementedError();

  @override
  Future<Result<String>> duplicate(String id, {required String nameSuffix}) =>
      throw UnimplementedError();

  @override
  Future<Result<List<Workout>>> getActive() => throw UnimplementedError();

  @override
  Future<Result<List<Workout>>> getAll() => throw UnimplementedError();

  @override
  Future<Result<List<Workout>>> getArchived() => throw UnimplementedError();

  @override
  Future<Result<List<WorkoutExercise>>> getExercises(String workoutId) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> reorder(List<String> orderedIds) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> unarchive(String id) => throw UnimplementedError();
}

void main() {
  group('ApplyPlannedWorkoutEdit', () {
    late _FakeWorkoutRepo workouts;
    late ApplyPlannedWorkoutEdit useCase;

    const workoutId = 'w1';
    final templateExercise = WorkoutExercise(
      id: 'we1',
      workoutId: workoutId,
      exerciseId: 'ex1',
      sortOrder: 0,
      sets: 3,
      minReps: 10,
      maxReps: 10,
      restSeconds: 60,
    );

    setUp(() {
      workouts = _FakeWorkoutRepo(
        workout: Workout(
          id: workoutId,
          name: 'Push A',
          createdAt: DateTime(2026, 1, 1),
        ),
      );
      useCase = ApplyPlannedWorkoutEdit(workouts);
    });

    test('sessionOnly is a no-op', () async {
      final result = await useCase(
        ApplyPlannedWorkoutEditParams(
          workoutId: workoutId,
          exercises: [templateExercise],
          outcome: PlannedWorkoutEditOutcome.sessionOnly,
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(workouts.lastUpdatedExercises, isNull);
    });

    test('persist updates the saved workout in place', () async {
      final result = await useCase(
        ApplyPlannedWorkoutEditParams(
          workoutId: workoutId,
          exercises: [templateExercise],
          outcome: PlannedWorkoutEditOutcome.persist,
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(workouts.lastUpdatedExercises?.length, 1);
      expect(workouts.workout.id, workoutId);
    });
  });
}
