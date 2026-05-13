import '../enums/duration_mode.dart';
import '../enums/program_focus.dart';
import 'deload_config.dart';

/// A training program (mesocycle) — a named, time-bound container
/// that owns a cycle and tracks progress.
class TrainingProgram {
  final int id;
  final String name;
  final ProgramFocus focus;
  final DurationMode durationMode;
  final int durationValue;
  final int? defaultRestSeconds;
  final bool isActive;
  final bool isInDeload;
  final DeloadConfig? deloadConfig;
  final DateTime createdAt;
  final DateTime? archivedAt;

  const TrainingProgram({
    required this.id,
    required this.name,
    required this.focus,
    required this.durationMode,
    required this.durationValue,
    this.defaultRestSeconds,
    this.isActive = false,
    this.isInDeload = false,
    this.deloadConfig,
    required this.createdAt,
    this.archivedAt,
  });

  bool get isArchived => archivedAt != null;

  bool get hasDeloadConfig => deloadConfig != null;

  TrainingProgram copyWith({
    String? name,
    ProgramFocus? focus,
    DurationMode? durationMode,
    int? durationValue,
    int? Function()? defaultRestSeconds,
    bool? isActive,
    bool? isInDeload,
    DeloadConfig? Function()? deloadConfig,
    DateTime? Function()? archivedAt,
  }) => TrainingProgram(
    id: id,
    name: name ?? this.name,
    focus: focus ?? this.focus,
    durationMode: durationMode ?? this.durationMode,
    durationValue: durationValue ?? this.durationValue,
    defaultRestSeconds: defaultRestSeconds != null
        ? defaultRestSeconds()
        : this.defaultRestSeconds,
    isActive: isActive ?? this.isActive,
    isInDeload: isInDeload ?? this.isInDeload,
    deloadConfig: deloadConfig != null ? deloadConfig() : this.deloadConfig,
    createdAt: createdAt,
    archivedAt: archivedAt != null ? archivedAt() : this.archivedAt,
  );
}
