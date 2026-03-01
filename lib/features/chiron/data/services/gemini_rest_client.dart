import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// REST client for Gemini generateContent API with support for
/// [thoughtSignature] so thinking models (2.5, 3) work with function calling.
class GeminiRestClient {
  GeminiRestClient({required String apiKey}) : _apiKey = apiKey;

  final String _apiKey;

  static const _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  /// Sends a single generateContent request. Returns the parsed JSON response.
  /// Throws on HTTP error or API error block.
  Future<Map<String, dynamic>> generateContent({
    required String modelId,
    required List<Map<String, dynamic>> contents,
    required String systemInstruction,
    required List<Map<String, dynamic>> toolDeclarations,
  }) async {
    final uri = Uri.parse('$_baseUrl/$modelId:generateContent').replace(
      queryParameters: {'key': _apiKey},
    );
    final body = <String, dynamic>{
      'contents': contents,
      'systemInstruction': _systemInstructionContent(systemInstruction),
      'tools': [
        {'functionDeclarations': toolDeclarations}
      ],
    };

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ).timeout(
      const Duration(seconds: 120),
      onTimeout: () => throw Exception('generateContent timeout'),
    );

    final json = jsonDecode(response.body) as Map<String, dynamic>?;
    if (response.statusCode != 200) {
      final message = json?['error']?['message'] ?? response.body;
      throw Exception('Gemini API error (${response.statusCode}): $message');
    }

    if (json == null) throw Exception('Empty response');
    return json;
  }

  Map<String, dynamic> _systemInstructionContent(String text) {
    return {
      'parts': [
        {'text': text}
      ]
    };
  }
}

/// Result of parsing one generateContent response.
class GeminiResponseParse {
  GeminiResponseParse({
    this.text,
    List<GeminiFunctionCall>? functionCalls,
    this.thoughtSignature,
    List<Map<String, dynamic>>? modelParts,
  })  : functionCalls = functionCalls ?? [],
        modelParts = modelParts ?? [];

  final String? text;
  final List<GeminiFunctionCall> functionCalls;
  final String? thoughtSignature;
  /// Raw parts from the model turn (to append to contents when sending back).
  final List<Map<String, dynamic>> modelParts;
}

class GeminiFunctionCall {
  GeminiFunctionCall({required this.name, required this.args});
  final String name;
  final Map<String, dynamic> args;
}

/// Parses generateContent response JSON into text, function calls, and
/// thought signature. Extracts [modelParts] so they can be echoed back.
GeminiResponseParse parseGenerateContentResponse(Map<String, dynamic> json) {
  final candidates = json['candidates'] as List<dynamic>?;
  if (candidates == null || candidates.isEmpty) {
    return GeminiResponseParse(text: '');
  }

  final candidate = candidates[0] as Map<String, dynamic>?;
  final content = candidate?['content'] as Map<String, dynamic>?;
  final parts = content?['parts'] as List<dynamic>?;
  if (parts == null || parts.isEmpty) {
    return GeminiResponseParse(text: '');
  }

  final buffer = StringBuffer();
  final functionCalls = <GeminiFunctionCall>[];
  String? thoughtSignature;
  final modelParts = <Map<String, dynamic>>[];

  final thoughtBuffer = StringBuffer();

  for (final p in parts) {
    if (p is! Map<String, dynamic>) continue;
    modelParts.add(Map<String, dynamic>.from(p));

    if (p.containsKey('text')) {
      final t = p['text'] as String?;
      if (t != null && t.isNotEmpty) {
        final isThought = p['thought'] == true;
        if (isThought) {
          thoughtBuffer.write(t);
        } else {
          buffer.write(t);
        }
      }
    }
    if (p.containsKey('functionCall')) {
      final fc = p['functionCall'] as Map<String, dynamic>?;
      if (fc != null) {
        final name = fc['name'] as String?;
        final args = fc['args'] as Map<String, dynamic>?;
        if (name != null) {
          functionCalls.add(GeminiFunctionCall(
            name: name,
            args: args ?? {},
          ));
        }
      }
      // thoughtSignature can be on the same part as functionCall (Gemini 3).
      final ts = p['thoughtSignature'] as String?;
      if (ts != null && ts.isNotEmpty) thoughtSignature ??= ts;
    }
    if (p.containsKey('thoughtSignature') && thoughtSignature == null) {
      final ts = p['thoughtSignature'] as String?;
      if (ts != null && ts.isNotEmpty) thoughtSignature = ts;
    }
  }

  // If no regular text but we have thought text (thinking models), use it as reply
  String? outText = buffer.isEmpty ? null : buffer.toString();
  if (outText == null && thoughtBuffer.isNotEmpty) {
    outText = thoughtBuffer.toString();
  }

  if (kDebugMode && outText == null && parts.isNotEmpty) {
    for (var i = 0; i < parts.length; i++) {
      final p = parts[i];
      if (p is Map<String, dynamic>) {
        final keys = p.keys.toList();
        debugPrint('[Chiron] Part $i keys: $keys');
      }
    }
  }

  return GeminiResponseParse(
    text: outText,
    functionCalls: functionCalls,
    thoughtSignature: thoughtSignature,
    modelParts: modelParts,
  );
}

/// Builds the "user" content part to send after executing function calls:
/// thoughtSignature first (if present), then one functionResponse per call.
List<Map<String, dynamic>> buildFunctionResponseParts({
  String? thoughtSignature,
  required List<MapEntry<String, Map<String, Object?>>> nameToResponse,
}) {
  final parts = <Map<String, dynamic>>[];
  if (thoughtSignature != null && thoughtSignature.isNotEmpty) {
    parts.add({'thoughtSignature': thoughtSignature});
  }
  for (final e in nameToResponse) {
    parts.add({
      'functionResponse': {
        'name': e.key,
        'response': e.value,
      }
    });
  }
  return parts;
}

/// Tool declarations for Chiron in the format expected by the REST API
/// (OpenAPI-style parameters). Kept in sync with repository handlers.
List<Map<String, dynamic>> getChironToolDeclarations() {
  return [
    {
      'name': 'updateBio',
      'description':
          'Acrescenta informação ao campo bio do perfil do utilizador. '
              'Concatena ao bio existente, nunca sobrescreve.',
      'parameters': _schema(
        properties: {
          'bio': _propString('Texto a acrescentar ao bio existente'),
        },
        required: ['bio'],
      ),
    },
    {
      'name': 'updateInjuries',
      'description':
          'Acrescenta lesão/limitação ao campo injuries do perfil. '
              'Concatena ao texto existente, nunca sobrescreve.',
      'parameters': _schema(
        properties: {
          'injuries': _propString('Texto da lesão a acrescentar'),
        },
        required: ['injuries'],
      ),
    },
    {
      'name': 'updateExperienceLevel',
      'description': 'Atualiza o nível de experiência do utilizador.',
      'parameters': _schema(
        properties: {
          'level': _propEnum(
            ['beginner', 'intermediate', 'advanced'],
            'Nível de experiência',
          ),
        },
        required: ['level'],
      ),
    },
    {
      'name': 'updateGender',
      'description':
          'Atualiza o gênero do utilizador (influencia a montagem dos treinos).',
      'parameters': _schema(
        properties: {
          'gender': _propEnum(
            ['male', 'female'],
            'Gênero: male = homem, female = mulher',
          ),
        },
        required: ['gender'],
      ),
    },
    {
      'name': 'updateTrainingFrequency',
      'description': 'Atualiza a frequência de treino semanal do utilizador.',
      'parameters': _schema(
        properties: {
          'daysPerWeek': _propInteger('Número de dias por semana (1-7)'),
        },
        required: ['daysPerWeek'],
      ),
    },
    {
      'name': 'registerEquipment',
      'description':
          'Regista um equipamento que o utilizador confirmou ter disponível.',
      'parameters': _schema(
        properties: {
          'equipmentName': _propString('Nome do equipamento a registar'),
        },
        required: ['equipmentName'],
      ),
    },
    {
      'name': 'removeEquipment',
      'description':
          'Remove um equipamento que o utilizador disse já não ter.',
      'parameters': _schema(
        properties: {
          'equipmentName': _propString('Nome do equipamento a remover'),
        },
        required: ['equipmentName'],
      ),
    },
    {
      'name': 'createWorkout',
      'description':
          'Cria um treino no aplicativo com o nome e a lista de exercícios. '
              'Usa os nomes exatos dos exercícios do catálogo. '
              'Cada exercício tem sets, reps e tempo de descanso em segundos.',
      'parameters': _schema(
        properties: {
          'name': _propString('Nome do treino'),
          'description': _propString(
            'Descrição opcional do treino',
            nullable: true,
          ),
          'exercises': {
            'type': 'array',
            'description': 'Lista de exercícios do treino, na ordem desejada',
            'items': _schema(
              properties: {
                'exerciseName': _propString(
                  'Nome exato do exercício no catálogo',
                ),
                'sets': _propInteger('Número de séries'),
                'reps': _propInteger(
                  'Repetições por série. Para cardio use 0 e preencha durationSeconds',
                  nullable: true,
                ),
                'restSeconds': _propInteger(
                  'Descanso entre séries em segundos',
                  nullable: true,
                ),
                'durationSeconds': _propInteger(
                  'Duração por série em segundos (só para cardio)',
                  nullable: true,
                ),
              },
              required: ['exerciseName', 'sets'],
            ),
          },
        },
        required: ['name', 'exercises'],
      ),
    },
  ];
}

Map<String, dynamic> _schema({
  required Map<String, dynamic> properties,
  required List<String> required,
}) {
  return {
    'type': 'object',
    'properties': properties,
    'required': required,
  };
}

Map<String, dynamic> _propString(String description, {bool? nullable}) {
  final m = <String, dynamic>{'type': 'string', 'description': description};
  if (nullable == true) m['nullable'] = true;
  return m;
}

Map<String, dynamic> _propInteger(String description, {bool? nullable}) {
  final m = <String, dynamic>{'type': 'integer', 'description': description};
  if (nullable == true) m['nullable'] = true;
  return m;
}

Map<String, dynamic> _propEnum(List<String> values, String description) {
  return {
    'type': 'string',
    'description': description,
    'enum': values,
  };
}
