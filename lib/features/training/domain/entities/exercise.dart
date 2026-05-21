import '../enums/exercise_type.dart';
import '../enums/load_mode.dart';
import '../enums/movement_pattern.dart';
import '../enums/muscle_group.dart';
import '../enums/muscle_region.dart';
import '../enums/muscle_role.dart';
import '../enums/target_muscle.dart';

/// A specific muscle targeted by an exercise, with an optional region emphasis.
class ExerciseMuscleFocus {
  final TargetMuscle muscle;
  final MuscleRegion? region;
  final MuscleRole role;

  const ExerciseMuscleFocus(
    this.muscle, [
    this.region,
    this.role = MuscleRole.primary,
  ]);
}

/// Exercise with muscle targeting details.
class Exercise {
  final String id;
  final String name;
  final MuscleGroup muscleGroup;
  final ExerciseType type;
  final MovementPattern? movementPattern;
  final String? description;
  final bool isVerified;

  /// Default load mode suggested by the catalog. The user may override per
  /// workout (`WorkoutExercise.loadModeOverride`) or per executed set
  /// (`ExecutionSet.loadModeOverride`).
  ///
  /// Replaces the legacy `isBodyweight: bool` flag — `defaultLoadMode ==
  /// LoadMode.bodyweight` is the equivalent of "is bodyweight" for filtering.
  final LoadMode defaultLoadMode;

  /// Fraction of body weight applied as load when the exercise is performed
  /// in `bodyweight` or `assisted` modes (e.g. 0.64 for a standard push-up,
  /// 1.00 for a pull-up). Source: Ebben et al. (2011) JSCR; ExRx via de Leva
  /// segmental data.
  ///
  /// `null` means the exercise never uses body weight as part of the load.
  /// A non-null value also signals that the catalog supports switching the
  /// load mode at the workout level (BW ↔ machine ↔ assisted).
  final double? bodyweightLoadFactor;

  /// True for isometric exercises measured in duration rather than reps
  /// (plank, wall sit, dead hang, L-sit, etc.).
  final bool isIsometric;

  /// Muscles this exercise targets, loaded from the junction table.
  final List<ExerciseMuscleFocus> muscles;

  const Exercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    this.type = ExerciseType.strength,
    this.movementPattern,
    this.description,
    this.isVerified = false,
    this.defaultLoadMode = LoadMode.weighted,
    this.bodyweightLoadFactor,
    this.isIsometric = false,
    this.muscles = const [],
  });

  bool get isCardio => type == ExerciseType.cardio;

  /// Whether this exercise can switch between BW / machine / assisted at the
  /// workout level. Tied to the presence of a load factor.
  bool get supportsLoadModeOverride =>
      bodyweightLoadFactor != null && !isIsometric;
}
