import '../../domain/entities/chiron_message.dart';

class ChironChatState {
  final List<ChironMessage> messages;
  final bool isStreaming;

  const ChironChatState({
    this.messages = const [],
    this.isStreaming = false,
  });

  ChironChatState copyWith({
    List<ChironMessage>? messages,
    bool? isStreaming,
  }) =>
      ChironChatState(
        messages: messages ?? this.messages,
        isStreaming: isStreaming ?? this.isStreaming,
      );
}
