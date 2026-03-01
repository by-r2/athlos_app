import 'dart:async';

import 'package:flutter/foundation.dart';
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

      // If the API returned no text (e.g. only function calls, or empty response)
      if (buffer.isEmpty) {
        final updated = List<ChironMessage>.from(state.messages);
        updated[updated.length - 1] = updated.last.copyWith(
          content: 'O Quíron não retornou texto. Pode ter sido um problema '
              'temporário — tente novamente.',
        );
        state = state.copyWith(messages: updated);
      }
    } on Exception catch (e) {
      final updated = List<ChironMessage>.from(state.messages);
      final String errorText = _errorMessage(e);
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

  static String _errorMessage(Exception e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('rate limit') || msg.contains('quota')) {
      return 'Limite de uso da API do Quíron atingido no momento. '
          'Tente novamente daqui a alguns minutos.';
    }
    if (kDebugMode && e.toString().isNotEmpty) {
      return 'Desculpe, ocorreu um erro. Tente novamente.\n\n'
          '(_debug: ${e.toString().length > 200 ? "${e.toString().substring(0, 200)}..." : e} )';
    }
    return 'Desculpe, ocorreu um erro. Tente novamente.';
  }
}
