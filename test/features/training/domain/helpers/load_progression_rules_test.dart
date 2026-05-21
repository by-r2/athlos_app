import 'package:athlos_app/features/training/domain/entities/exercise.dart';
import 'package:athlos_app/features/training/domain/enums/exercise_type.dart';
import 'package:athlos_app/features/training/domain/enums/load_mode.dart';
import 'package:athlos_app/features/training/domain/enums/movement_pattern.dart';
import 'package:athlos_app/features/training/domain/enums/muscle_group.dart';
import 'package:athlos_app/features/training/domain/helpers/load_progression_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Exercise ex({MuscleGroup mg = MuscleGroup.chest, MovementPattern? mp}) =>
      Exercise(id: 'ex-1', name: 't', muscleGroup: mg, movementPattern: mp);

  test('hinge pattern uses larger increment', () {
    expect(
      progressionLoadIncreaseFraction(
        ex(mp: MovementPattern.hinge, mg: MuscleGroup.back),
      ),
      closeTo(0.05, 1e-9),
    );
  });

  test('isolation + lower muscle group uses larger increment', () {
    expect(
      progressionLoadIncreaseFraction(
        ex(mp: MovementPattern.isolation, mg: MuscleGroup.quadriceps),
      ),
      closeTo(0.05, 1e-9),
    );
  });

  test('upper isolation keeps conservative increment', () {
    expect(
      progressionLoadIncreaseFraction(
        ex(mp: MovementPattern.isolation, mg: MuscleGroup.biceps),
      ),
      closeTo(0.025, 1e-9),
    );
  });

  test('default strength exercise without pattern', () {
    expect(
      progressionLoadIncreaseFraction(
        Exercise(
          id: 'ex-1',
          name: 'x',
          muscleGroup: MuscleGroup.shoulders,
          type: ExerciseType.strength,
          defaultLoadMode: LoadMode.weighted,
        ),
      ),
      closeTo(0.025, 1e-9),
    );
  });
}
