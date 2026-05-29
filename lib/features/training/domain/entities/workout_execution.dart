import '../enums/session_kind.dart';
import 'execution_context_fallback.dart';

/// Record of a completed (or in-progress) workout execution.
class WorkoutExecution {
  final String id;
  final String workoutId;
  final String? programId;
  final SessionKind sessionKind;
  final DateTime startedAt;
  final DateTime? finishedAt;

  /// Frozen at finish when the live workout may later be deleted.
  final String? workoutNameSnapshot;

  /// Frozen at finish when the live program may later be removed.
  final String? programNameSnapshot;

  /// Per-exercise metadata fallback (names, load mode, template flags).
  final ExecutionContextFallback? contextFallback;

  const WorkoutExecution({
    required this.id,
    required this.workoutId,
    this.programId,
    this.sessionKind = SessionKind.planned,
    required this.startedAt,
    this.finishedAt,
    this.workoutNameSnapshot,
    this.programNameSnapshot,
    this.contextFallback,
  });

  bool get isFinished => finishedAt != null;

  Duration? get duration => finishedAt?.difference(startedAt);
}
