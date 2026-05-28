import '../enums/load_mode.dart';
import '../enums/muscle_group.dart';

/// Per-exercise metadata frozen at workout finish for history fallback.
class ExecutionContextFallbackExercise {
  final String displayName;
  final bool isVerified;
  final MuscleGroup muscleGroup;
  final LoadMode defaultLoadMode;
  final double? bodyweightLoadFactor;
  final bool isUnilateral;
  final LoadMode? loadModeOverride;
  final int? groupId;
  final int sortOrder;

  const ExecutionContextFallbackExercise({
    required this.displayName,
    this.isVerified = false,
    required this.muscleGroup,
    this.defaultLoadMode = LoadMode.weighted,
    this.bodyweightLoadFactor,
    this.isUnilateral = false,
    this.loadModeOverride,
    this.groupId,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toJson() => {
    'displayName': displayName,
    'isVerified': isVerified,
    'muscleGroup': muscleGroup.name,
    'defaultLoadMode': defaultLoadMode.name,
    'bodyweightLoadFactor': bodyweightLoadFactor,
    'isUnilateral': isUnilateral,
    'loadModeOverride': loadModeOverride?.name,
    'groupId': groupId,
    'sortOrder': sortOrder,
  };

  factory ExecutionContextFallbackExercise.fromJson(Map<String, dynamic> json) {
    return ExecutionContextFallbackExercise(
      displayName: json['displayName'] as String,
      isVerified: json['isVerified'] as bool? ?? false,
      muscleGroup: MuscleGroup.values.byName(json['muscleGroup'] as String),
      defaultLoadMode: LoadMode.values.byName(
        json['defaultLoadMode'] as String? ?? LoadMode.weighted.name,
      ),
      bodyweightLoadFactor: (json['bodyweightLoadFactor'] as num?)?.toDouble(),
      isUnilateral: json['isUnilateral'] as bool? ?? false,
      loadModeOverride: json['loadModeOverride'] == null
          ? null
          : LoadMode.values.byName(json['loadModeOverride'] as String),
      groupId: json['groupId'] as int?,
      sortOrder: json['sortOrder'] as int? ?? 0,
    );
  }
}

/// Immutable session context stored on [WorkoutExecution.contextFallback].
class ExecutionContextFallback {
  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final Map<String, ExecutionContextFallbackExercise> exercises;

  const ExecutionContextFallback({
    this.schemaVersion = currentSchemaVersion,
    required this.exercises,
  });

  ExecutionContextFallbackExercise? forExercise(String exerciseId) =>
      exercises[exerciseId];

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'exercises': exercises.map((k, v) => MapEntry(k, v.toJson())),
  };

  factory ExecutionContextFallback.fromJson(Map<String, dynamic> json) {
    final raw = json['exercises'];
    final parsed = <String, ExecutionContextFallbackExercise>{};
    if (raw is Map) {
      for (final entry in raw.entries) {
        final value = entry.value;
        if (value is Map<String, dynamic>) {
          parsed[entry.key.toString()] =
              ExecutionContextFallbackExercise.fromJson(value);
        } else if (value is Map) {
          parsed[entry.key.toString()] =
              ExecutionContextFallbackExercise.fromJson(
                value.map((k, v) => MapEntry(k.toString(), v)),
              );
        }
      }
    }
    return ExecutionContextFallback(
      schemaVersion: json['schemaVersion'] as int? ?? currentSchemaVersion,
      exercises: parsed,
    );
  }
}
