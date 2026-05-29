import 'package:athlos_app/core/errors/result.dart';
import 'package:athlos_app/features/training/domain/entities/cycle_step.dart';
import 'package:athlos_app/features/training/domain/entities/workout.dart';
import 'package:athlos_app/features/training/domain/entities/workout_exercise.dart';
import 'package:athlos_app/features/training/domain/repositories/cycle_repository.dart';
import 'package:athlos_app/features/training/domain/repositories/workout_repository.dart';
import 'package:athlos_app/features/training/domain/usecases/promote_ad_hoc_workout.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeWorkoutRepo implements WorkoutRepository {
  _FakeWorkoutRepo({required this.workout});

  Workout workout;
  List<WorkoutExercise>? lastUpdatedExercises;
  bool deleteDraftCalled = false;
  bool promoteCalled = false;

  @override
  Future<Result<void>> deleteDraft(String workoutId) async {
    deleteDraftCalled = true;
    return const Success(null);
  }

  @override
  Future<Result<void>> archiveDraft(String workoutId) async =>
      const Success(null);

  @override
  Future<Result<void>> promoteDraft(String workoutId, {required String name}) async {
    promoteCalled = true;
    workout = workout.copyWith(name: name, isDraft: false);
    return const Success(null);
  }

  @override
  Future<Result<Workout?>> getById(String id) async => Success(workout);

  @override
  Future<Result<void>> update(Workout workout, List<WorkoutExercise> exercises) async {
    lastUpdatedExercises = exercises;
    this.workout = workout;
    return const Success(null);
  }

  @override
  Future<Result<String>> createDraft({required String name}) =>
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
  Future<Result<void>> persistDraftExercises(
    String workoutId,
    List<WorkoutExercise> exercises,
  ) async =>
      const Success(null);

  @override
  Future<Result<void>> unarchive(String id) => throw UnimplementedError();
}

class _FakeCycleRepo implements CycleRepository {
  String? appendedWorkoutId;
  String? appendedProgramId;

  @override
  Future<Result<void>> appendWorkoutToCycle(
    String workoutId,
    String programId,
  ) async {
    appendedWorkoutId = workoutId;
    appendedProgramId = programId;
    return const Success(null);
  }

  @override
  Future<Result<List<TrainingCycleStep>>> getSteps(String programId) async =>
      const Success([]);

  @override
  Future<Result<void>> removeWorkoutFromAllCycles(String workoutId) async =>
      const Success(null);

  @override
  Future<Result<void>> removeWorkoutFromCycle(
    String workoutId,
    String programId,
  ) async =>
      const Success(null);

  @override
  Future<Result<void>> setSteps(
    List<TrainingCycleStep> steps,
    String programId,
  ) async =>
      const Success(null);
}

void main() {
  group('PromoteAdHocWorkout', () {
    late _FakeWorkoutRepo workouts;
    late _FakeCycleRepo cycle;
    late PromoteAdHocWorkout useCase;

    const workoutId = 'w1';
    const programId = 'p1';
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
          name: 'Draft',
          isDraft: true,
          createdAt: DateTime(2026, 1, 1),
        ),
      );
      cycle = _FakeCycleRepo();
      useCase = PromoteAdHocWorkout(workouts, cycle);
    });

    test('historyOnly deletes local draft without persisting exercises', () async {
      final result = await useCase(
        PromoteAdHocWorkoutParams(
          workoutId: workoutId,
          programId: programId,
          name: 'Ignored',
          exercises: [templateExercise],
          outcome: AdHocSaveOutcome.historyOnly,
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(workouts.deleteDraftCalled, isTrue);
      expect(workouts.promoteCalled, isFalse);
      expect(workouts.lastUpdatedExercises, isNull);
    });

    test('save promotes, writes workout_exercises, and appends to cycle', () async {
      final result = await useCase(
        PromoteAdHocWorkoutParams(
          workoutId: workoutId,
          programId: programId,
          name: 'Peito improvisado',
          exercises: [templateExercise],
          outcome: AdHocSaveOutcome.save,
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(workouts.promoteCalled, isTrue);
      expect(workouts.lastUpdatedExercises?.length, 1);
      expect(workouts.workout.name, 'Peito improvisado');
      expect(cycle.appendedProgramId, programId);
      expect(cycle.appendedWorkoutId, workoutId);
    });
  });
}
