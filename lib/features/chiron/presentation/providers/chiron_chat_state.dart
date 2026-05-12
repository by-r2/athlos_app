import '../../domain/entities/chiron_message.dart';

/// Feedback for a tool invoked during the last assistant response.
class ChironToolFeedback {
  final String toolName;
  final bool success;

  const ChironToolFeedback({required this.toolName, required this.success});
}

class ChironChatState {
  final List<ChironMessage> messages;
  final bool isStreaming;
  final bool hasError;

  /// Tool invocations from the last response (for UI chips).
  final List<ChironToolFeedback> lastResponseToolFeedback;

  /// When createWorkout succeeded, the new workout id for deep link.
  final int? lastCreatedWorkoutId;

  const ChironChatState({
    this.messages = const [],
    this.isStreaming = false,
    this.hasError = false,
    this.lastResponseToolFeedback = const [],
    this.lastCreatedWorkoutId,
  });

  ChironChatState copyWith({
    List<ChironMessage>? messages,
    bool? isStreaming,
    bool? hasError,
    List<ChironToolFeedback>? lastResponseToolFeedback,
    int? lastCreatedWorkoutId,
    bool clearCreatedWorkoutId = false,
  }) => ChironChatState(
    messages: messages ?? this.messages,
    isStreaming: isStreaming ?? this.isStreaming,
    hasError: hasError ?? this.hasError,
    lastResponseToolFeedback:
        lastResponseToolFeedback ?? this.lastResponseToolFeedback,
    lastCreatedWorkoutId: clearCreatedWorkoutId
        ? null
        : (lastCreatedWorkoutId ?? this.lastCreatedWorkoutId),
  );
}
