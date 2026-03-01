import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../profile/presentation/providers/profile_notifier.dart';
import '../../../training/presentation/providers/workout_notifier.dart';
import '../../data/repositories/chiron_providers.dart';
import '../../domain/entities/chiron_message.dart';
import 'chiron_chat_state.dart';

part 'chiron_notifier.g.dart';

@riverpod
class ChironNotifier extends _$ChironNotifier {
  @override
  ChironChatState build() => const ChironChatState();

  Future<void> send(String userMessage) async {
    if (userMessage.trim().isEmpty || state.isStreaming) return;

    final userMsg = ChironMessage(
      role: ChironRole.user,
      content: userMessage.trim(),
      createdAt: DateTime.now(),
    );

    final assistantMsg = ChironMessage(
      role: ChironRole.assistant,
      content: '',
      createdAt: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg, assistantMsg],
      isStreaming: true,
    );

    try {
      final promptBuilder = ref.read(promptBuilderProvider);
      final userContext = await promptBuilder.build();

      final repository = ref.read(chironRepositoryProvider);
      final stream = repository.sendMessage(
        userMessage: userMessage.trim(),
        history: state.messages.where((m) => m.content.isNotEmpty).toList()
          ..removeLast(),
        userContext: userContext,
      );

      final buffer = StringBuffer();

      await for (final chunk in stream) {
        buffer.write(chunk);
        final updated = List<ChironMessage>.from(state.messages);
        updated[updated.length - 1] =
            updated.last.copyWith(content: buffer.toString());
        state = state.copyWith(messages: updated);
      }
    } on Exception catch (e) {
      final updated = List<ChironMessage>.from(state.messages);
      final errorText = e.toString().contains('Rate limit')
          ? 'Limite de mensagens atingido. Aguarde um momento.'
          : 'Desculpe, ocorreu um erro. Tente novamente.';
      updated[updated.length - 1] =
          updated.last.copyWith(content: errorText);
      state = state.copyWith(messages: updated);
    } finally {
      state = state.copyWith(isStreaming: false);
      // Refresh profile and workout list in case function calling updated them
      ref.invalidate(profileProvider);
      ref.invalidate(workoutListProvider);
    }
  }

  void clear() => state = const ChironChatState();
}
