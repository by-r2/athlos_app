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

/// Per template line frozen at finish (supports substitution metadata).
class ExecutionContextFallbackLine {
  final String workoutExerciseId;
  final String exerciseId;
  final String? substitutedFromExerciseId;
  final String displayName;
  final String? substitutedFromDisplayName;
  final bool isVerified;
  final MuscleGroup muscleGroup;
  final int sortOrder;
  final int? groupId;
  final bool isUnilateral;
  final LoadMode? loadModeOverride;

  const ExecutionContextFallbackLine({
    required this.workoutExerciseId,
    required this.exerciseId,
    this.substitutedFromExerciseId,
    required this.displayName,
    this.substitutedFromDisplayName,
    this.isVerified = false,
    required this.muscleGroup,
    this.sortOrder = 0,
    this.groupId,
    this.isUnilateral = false,
    this.loadModeOverride,
  });

  bool get wasSubstituted =>
      substitutedFromExerciseId != null &&
      substitutedFromExerciseId!.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'workoutExerciseId': workoutExerciseId,
    'exerciseId': exerciseId,
    if (substitutedFromExerciseId != null)
      'substitutedFromExerciseId': substitutedFromExerciseId,
    'displayName': displayName,
    if (substitutedFromDisplayName != null)
      'substitutedFromDisplayName': substitutedFromDisplayName,
    'isVerified': isVerified,
    'muscleGroup': muscleGroup.name,
    'sortOrder': sortOrder,
    if (groupId != null) 'groupId': groupId,
    'isUnilateral': isUnilateral,
    if (loadModeOverride != null) 'loadModeOverride': loadModeOverride!.name,
  };

  factory ExecutionContextFallbackLine.fromJson(Map<String, dynamic> json) {
    return ExecutionContextFallbackLine(
      workoutExerciseId: json['workoutExerciseId'] as String,
      exerciseId: json['exerciseId'] as String,
      substitutedFromExerciseId:
          json['substitutedFromExerciseId'] as String?,
      displayName: json['displayName'] as String,
      substitutedFromDisplayName:
          json['substitutedFromDisplayName'] as String?,
      isVerified: json['isVerified'] as bool? ?? false,
      muscleGroup: MuscleGroup.values.byName(json['muscleGroup'] as String),
      sortOrder: json['sortOrder'] as int? ?? 0,
      groupId: json['groupId'] as int?,
      isUnilateral: json['isUnilateral'] as bool? ?? false,
      loadModeOverride: json['loadModeOverride'] == null
          ? null
          : LoadMode.values.byName(json['loadModeOverride'] as String),
    );
  }
}

/// Immutable session context stored on [WorkoutExecution.contextFallback].
class ExecutionContextFallback {
  static const int currentSchemaVersion = 2;

  final int schemaVersion;
  final Map<String, ExecutionContextFallbackExercise> exercises;
  final Map<String, ExecutionContextFallbackLine> lines;

  const ExecutionContextFallback({
    this.schemaVersion = currentSchemaVersion,
    required this.exercises,
    this.lines = const {},
  });

  ExecutionContextFallbackExercise? forExercise(String exerciseId) =>
      exercises[exerciseId];

  ExecutionContextFallbackLine? forLine(String workoutExerciseId) =>
      lines[workoutExerciseId];

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'exercises': exercises.map((k, v) => MapEntry(k, v.toJson())),
    if (lines.isNotEmpty)
      'lines': lines.map((k, v) => MapEntry(k, v.toJson())),
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

    final rawLines = json['lines'];
    final parsedLines = <String, ExecutionContextFallbackLine>{};
    if (rawLines is Map) {
      for (final entry in rawLines.entries) {
        final value = entry.value;
        if (value is Map<String, dynamic>) {
          final line = ExecutionContextFallbackLine.fromJson(value);
          parsedLines[line.workoutExerciseId] = line;
        } else if (value is Map) {
          final line = ExecutionContextFallbackLine.fromJson(
            value.map((k, v) => MapEntry(k.toString(), v)),
          );
          parsedLines[line.workoutExerciseId] = line;
        }
      }
    }

    return ExecutionContextFallback(
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      exercises: parsed,
      lines: parsedLines,
    );
  }
}
