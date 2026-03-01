import 'dart:async';

import 'package:google_generative_ai/google_generative_ai.dart';

import '../../domain/entities/chiron_message.dart';
import '../../domain/repositories/chiron_repository.dart';

class ChironRepositoryImpl implements ChironRepository {
  final String _apiKey;

  static const _maxMessagesPerMinute = 10;
  final _timestamps = <DateTime>[];

  static const _systemPrompt = '''
Você é o Quíron (Chiron), um assistente de treino com IA no aplicativo Athlos.
Quíron é inspirado no centauro da mitologia grega, mentor de heróis como Aquiles e Hércules.

Diretrizes:
- Responda sempre em português do Brasil
- Seja conciso mas informativo
- Foque em treino, exercícios, nutrição básica e recuperação
- Use os dados do utilizador para personalizar as respostas
- Quando sugerir treinos, considere os equipamentos disponíveis e objetivos do utilizador
- Nunca dê conselhos médicos — recomende procurar um profissional quando apropriado
- Mantenha um tom motivacional mas profissional
- Use formatação Markdown quando apropriado (listas, negrito, etc.)
''';

  ChironRepositoryImpl({required String apiKey}) : _apiKey = apiKey;

  @override
  Stream<String> sendMessage({
    required String userMessage,
    required List<ChironMessage> history,
    required String userContext,
  }) async* {
    _enforceRateLimit();

    final model = GenerativeModel(
      model: 'gemini-flash-latest',
      apiKey: _apiKey,
      systemInstruction: Content.system('$_systemPrompt\n\n$userContext'),
    );

    final chatHistory = history.map((msg) {
      final role = msg.role == ChironRole.user ? 'user' : 'model';
      return Content(role, [TextPart(msg.content)]);
    }).toList();

    final chat = model.startChat(history: chatHistory);
    final response = chat.sendMessageStream(Content.text(userMessage));

    await for (final chunk in response) {
      final text = chunk.text;
      if (text != null && text.isNotEmpty) {
        yield text;
      }
    }
  }

  void _enforceRateLimit() {
    final now = DateTime.now();
    _timestamps.removeWhere((t) => now.difference(t).inMinutes >= 1);

    if (_timestamps.length >= _maxMessagesPerMinute) {
      throw Exception('Rate limit exceeded');
    }

    _timestamps.add(now);
  }
}
