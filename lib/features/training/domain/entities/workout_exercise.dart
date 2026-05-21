import '../enums/load_mode.dart';

/// Configuration of an exercise within a workout (sets, rep range, rest).
class WorkoutExercise {
  final String id;
  final String workoutId;
  final String exerciseId;
  final int sortOrder;
  final int sets;

  /// Minimum target reps per set. Null for cardio exercises.
  final int? minReps;

  /// Maximum target reps per set. Null for cardio exercises.
  /// When equal to [minReps], behaves as a fixed target.
  final int? maxReps;

  /// Whether the last set (or all sets) should be performed as
  /// "As Many Reps As Possible" — user goes to near-failure.
  final bool isAmrap;

  /// Rest time between sets in seconds.
  final int restSeconds;

  /// Planned duration per set in seconds. Used for cardio exercises.
  final int? durationSeconds;

  /// Superset group ID. Exercises sharing the same non-null groupId
  /// are executed back-to-back before rest.
  final int? groupId;

  /// Whether this exercise is performed unilaterally (one side at a time).
  final bool isUnilateral;

  /// User-chosen load mode for this exercise within this workout. Overrides
  /// the catalog default (`Exercise.defaultLoadMode`). Null means "use the
  /// catalog default".
  final LoadMode? loadModeOverride;

  /// Free-text execution notes (postural cues, technique reminders, etc.).
  final String? notes;

  const WorkoutExercise({
    required this.id,
    required this.workoutId,
    required this.exerciseId,
    required this.sortOrder,
    required this.sets,
    this.minReps,
    this.maxReps,
    this.isAmrap = false,
    required this.restSeconds,
    this.durationSeconds,
    this.groupId,
    this.isUnilateral = false,
    this.loadModeOverride,
    this.notes,
  });

  /// Whether this is a rep range (min != max) rather than a fixed target.
  bool get isRepRange =>
      minReps != null && maxReps != null && minReps != maxReps;

  /// Display-friendly rep string: "10", "8-12", or "5+" (AMRAP).
  String get repsDisplay {
    if (minReps == null) return '';
    if (isAmrap) return '$minReps+';
    if (maxReps != null && maxReps != minReps) return '$minReps-$maxReps';
    return '$minReps';
  }

  /// The rep target used for execution planning.
  /// AMRAP: minReps (minimum before going to failure).
  /// Range: maxReps (target to reach for progression).
  /// Fixed: minReps (same as maxReps).
  int? get targetReps => isAmrap ? minReps : (maxReps ?? minReps);
}
