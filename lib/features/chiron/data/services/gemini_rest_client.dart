import 'dart:convert';

import 'package:http/http.dart' as http;

class GeminiApiException implements Exception {
  GeminiApiException({
    required this.message,
    this.statusCode,
  });

  final String message;
  final int? statusCode;

  bool get isRetryable =>
      statusCode == 429 ||
      statusCode == 500 ||
      statusCode == 502 ||
      statusCode == 503 ||
      statusCode == 504;

  bool get isQuotaOrRateLimit {
    final normalized = message.toLowerCase();
    return statusCode == 429 ||
        normalized.contains('quota') ||
        normalized.contains('rate limit') ||
        normalized.contains('resource_exhausted');
  }

  @override
  String toString() {
    if (statusCode != null) return 'Gemini API error ($statusCode): $message';
    return 'Gemini API error: $message';
  }
}

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
      const Duration(seconds: 30),
      onTimeout: () => throw GeminiApiException(message: 'generateContent timeout'),
    );

    final json = jsonDecode(response.body) as Map<String, dynamic>?;
    if (response.statusCode != 200) {
      final message = json?['error']?['message'] ?? response.body;
      throw GeminiApiException(
        statusCode: response.statusCode,
        message: message.toString(),
      );
    }

    if (json == null) throw GeminiApiException(message: 'Empty response');
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
          'Append information to the user bio field. '
              'Concatenate to existing bio, never overwrite.',
      'parameters': _schema(
        properties: {
          'bio': _propString('Text to append to existing bio'),
        },
        required: ['bio'],
      ),
    },
    {
      'name': 'updateInjuries',
      'description':
          'Append injury/limitation text to profile injuries field. '
              'Concatenate to existing text, never overwrite.',
      'parameters': _schema(
        properties: {
          'injuries': _propString('Injury text to append'),
        },
        required: ['injuries'],
      ),
    },
    {
      'name': 'updateExperienceLevel',
      'description': 'Update user experience level.',
      'parameters': _schema(
        properties: {
          'level': _propEnum(
            ['beginner', 'intermediate', 'advanced'],
            'Experience level',
          ),
        },
        required: ['level'],
      ),
    },
    {
      'name': 'updateGender',
      'description': 'Update user gender (influences workout planning).',
      'parameters': _schema(
        properties: {
          'gender': _propEnum(
            ['male', 'female'],
            'Gender: male or female',
          ),
        },
        required: ['gender'],
      ),
    },
    {
      'name': 'updateTrainingFrequency',
      'description': 'Update weekly training frequency.',
      'parameters': _schema(
        properties: {
          'daysPerWeek': _propInteger('Days per week (1-7)'),
        },
        required: ['daysPerWeek'],
      ),
    },
    {
      'name': 'registerEquipment',
      'description':
          'Register an equipment item confirmed as available by the user.',
      'parameters': _schema(
        properties: {
          'equipmentName': _propString('Equipment name to register'),
        },
        required: ['equipmentName'],
      ),
    },
    {
      'name': 'removeEquipment',
      'description': 'Remove an equipment item the user no longer has.',
      'parameters': _schema(
        properties: {
          'equipmentName': _propString('Equipment name to remove'),
        },
        required: ['equipmentName'],
      ),
    },
    {
      'name': 'createWorkout',
      'description':
          'Create a workout with name and ordered exercise list. '
              'Use exact catalog exercise names. '
              'Each exercise supports sets, reps, and rest seconds.',
      'parameters': _schema(
        properties: {
          'name': _propString('Workout name'),
          'description': _propString(
            'Optional workout description',
            nullable: true,
          ),
          'exercises': {
            'type': 'array',
            'description': 'Ordered workout exercise list',
            'items': _schema(
              properties: {
                'exerciseName': _propString(
                  'Exact exercise name from catalog',
                ),
                'sets': _propInteger('Number of sets'),
                'reps': _propInteger(
                  'Repetitions per set. For cardio use 0 and fill durationSeconds',
                  nullable: true,
                ),
                'restSeconds': _propInteger(
                  'Rest between sets in seconds',
                  nullable: true,
                ),
                'durationSeconds': _propInteger(
                  'Duration per set in seconds (cardio only)',
                  nullable: true,
                ),
                'notes': _propString(
                  'Execution notes, posture cues, or technical variations (e.g. "supine on bench", "back against wall")',
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
    {
      'name': 'archiveWorkout',
      'description':
          'Archive a workout (remove from active list, keep in history). '
              'Use workout ID from context (Active Workouts: id=X). '
              'Never delete workouts. To replace a plan, create a new workout first then archive the old one.',
      'parameters': _schema(
        properties: {
          'workoutId': _propInteger('Workout ID to archive (see context)'),
        },
        required: ['workoutId'],
      ),
    },
    {
      'name': 'setCycle',
      'description':
          'Set workout cycle order (routine). Call after creating new workouts and archiving old ones. '
              'steps: ordered list where each item is { type: "workout", workoutId: N } or { type: "rest" }. '
              'Include only active workoutIds (newly created or retained). Replaces the full cycle.',
      'parameters': _schema(
        properties: {
          'steps': {
            'type': 'array',
            'description': 'Ordered cycle steps: workout (with workoutId) or rest',
            'items': _schema(
              properties: {
                'type': _propEnum(
                  ['workout', 'rest'],
                  'Step type: workout or rest',
                ),
                'workoutId': _propInteger(
                  'Workout ID (required when type=workout)',
                  nullable: true,
                ),
              },
              required: ['type'],
            ),
          },
        },
        required: ['steps'],
      ),
    },
    {
      'name': 'getTrainingState',
      'description':
          'Get current training state: active workouts (id and name) and cycle steps order. '
              'Call at the end to verify all changes were applied correctly.',
      'parameters': _schema(
        properties: {},
        required: [],
      ),
    },
    {
      'name': 'requestExtendedHistory',
      'description':
          'Request extended workout/execution context when long-term trends, comparisons, or broader history are needed.',
      'parameters': _schema(
        properties: {},
        required: [],
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
