import '../entities/exercise.dart';
import '../enums/movement_pattern.dart';
import '../enums/muscle_group.dart';

/// Fractional load bump applied when **all** prescribed work sets hit `maxReps`.
///
/// Lower-body / axial patterns typically tolerate somewhat larger increments
/// (~5%+ in common programming) versus upper/accessory lifts (~2.5%).
double progressionLoadIncreaseFraction(Exercise exercise) {
  switch (exercise.movementPattern) {
    case MovementPattern.squat:
    case MovementPattern.hinge:
    case MovementPattern.lunge:
      return 0.05;
    case MovementPattern.push:
    case MovementPattern.pull:
    case MovementPattern.isolation:
    case MovementPattern.carry:
    case MovementPattern.rotation:
    case null:
      break;
  }

  switch (exercise.muscleGroup) {
    case MuscleGroup.quadriceps:
    case MuscleGroup.hamstrings:
    case MuscleGroup.glutes:
    case MuscleGroup.calves:
    case MuscleGroup.adductors:
    case MuscleGroup.fullBody:
      return 0.05;
    case MuscleGroup.chest:
    case MuscleGroup.back:
    case MuscleGroup.shoulders:
    case MuscleGroup.biceps:
    case MuscleGroup.triceps:
    case MuscleGroup.forearms:
    case MuscleGroup.abs:
    case MuscleGroup.cardio:
      return 0.025;
  }
}
