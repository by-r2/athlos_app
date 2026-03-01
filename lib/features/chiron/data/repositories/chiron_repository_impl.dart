import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/result.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../../profile/domain/enums/experience_level.dart';
import '../../../profile/domain/enums/gender.dart';
import '../../../profile/domain/repositories/user_profile_repository.dart';
import '../../../training/domain/entities/workout.dart' as domain_workout;
import '../../../training/domain/entities/workout_exercise.dart' as domain_we;
import '../../../training/domain/repositories/equipment_repository.dart';
import '../../../training/domain/repositories/exercise_repository.dart';
import '../../../training/domain/repositories/workout_repository.dart';
import '../../domain/entities/chiron_message.dart';
import '../../domain/repositories/chiron_repository.dart';
import '../services/gemini_models_loader.dart';
import '../services/gemini_rest_client.dart';

/// Fallback when the API list is unavailable. Use only "-latest" aliases
/// so Google can change the underlying version without app updates.
const List<String> _geminiModelIdsFallback = [
  'gemini-flash-latest',
  'gemini-1.5-flash-latest',
  'gemini-1.5-flash-8b-latest',
];

class ChironRepositoryImpl implements ChironRepository {
  ChironRepositoryImpl({
    required String apiKey,
    required UserProfileRepository profileRepo,
    required EquipmentRepository equipmentRepo,
    required WorkoutRepository workoutRepo,
    required ExerciseRepository exerciseRepo,
    GeminiModelsLoader? modelsLoader,
  })  : _profileRepo = profileRepo,
        _equipmentRepo = equipmentRepo,
        _workoutRepo = workoutRepo,
        _exerciseRepo = exerciseRepo,
        _modelsLoader = modelsLoader ?? GeminiModelsLoader(apiKey: apiKey),
        _restClient = GeminiRestClient(apiKey: apiKey);

  final UserProfileRepository _profileRepo;
  final GeminiRestClient _restClient;
  final EquipmentRepository _equipmentRepo;
  final WorkoutRepository _workoutRepo;
  final ExerciseRepository _exerciseRepo;
  final GeminiModelsLoader _modelsLoader;

  static const _maxMessagesPerMinute = 10;
  final _timestamps = <DateTime>[];

  static const _systemPrompt = '''
Você é o Quíron (Chiron), um assistente de treino com IA no aplicativo Athlos.
Quíron é inspirado no centauro da mitologia grega, mentor de heróis como Aquiles e Hércules.

## Diretrizes gerais
- Responda sempre em português do Brasil
- Seja conciso mas informativo
- Foque em treino, exercícios, nutrição básica e recuperação
- Use os dados do utilizador para personalizar as respostas
- Nunca dê conselhos médicos — recomende procurar um profissional quando apropriado
- Mantenha um tom motivacional mas profissional
- Use formatação Markdown quando apropriado (listas, negrito, etc.)

## Campos em falta
Verifica os campos do perfil do utilizador no contexto fornecido. Se algum campo crítico estiver vazio ou ausente (gender, injuries, experienceLevel, trainingFrequency), pergunta ao utilizador de forma natural durante a conversa e usa as funções disponíveis para guardar. Não faças um interrogatório — integra as perguntas na conversa de forma natural.

Campos críticos: gender (gênero), injuries (lesões), experienceLevel (nível de experiência), trainingFrequency (frequência de treino).
Campos complementares (bio): enriquece ao longo de conversas, sem pressionar.

## Gênero e montagem de treino
O gênero do utilizador (male/female) deve influenciar a montagem dos treinos:
- Mulher (female): dá prioridade a pernas e glúteos na escolha de exercícios e na estrutura do split (ex.: mais volume de perna, estética mais definida e proporcional).
- Homem (male): splits mais clássicos (superiores/inferiores, push/pull/legs) consoante o objetivo e estética.
A estética corporal desejada (athletic, bulky, robust) aplica-se de forma diferente conforme o gênero — adapta as sugestões.

## Equipamentos e criação de treino
Quando montares um treino (createWorkout ou em sugestões), usa o perfil e os equipamentos registados. Para cada exercício que exija equipamento que não conste na lista do utilizador, pergunta: "Tem [nome do equipamento]?" Se disser que sim, usa registerEquipment com esse nome e inclui o exercício no treino. Se disser que não, sugere um exercício alternativo (outro equipamento ou sem equipamento) e não incluas o original. Assim o treino fica sempre realizável e a lista de equipamentos vai sendo atualizada conforme o utilizador confirma. Não te limites só aos equipamentos já registados — pergunta e atualiza.

## Bio
Quando aprenderes algo relevante sobre o histórico do utilizador que ainda não esteja no bio (tempo de treino, desportos anteriores, contexto pessoal), usa updateBio para ACRESCENTAR ao bio existente. Nunca apagues o que já existe — concatena com um separador "; ".

## Lesões
Se o utilizador mencionar lesões ou limitações que não estejam registadas, usa updateInjuries para ACRESCENTAR à lista existente. Nunca apagues — concatena com "; ".

## Análise de progresso
Analisa o histórico de execuções para sugerir quando trocar de treino, progressões, e descanso. Considera a data de criação dos treinos e a frequência de execução. Compara pesos e reps entre sessões para identificar estagnação ou progressão.

## Criação de treinos
Quando o utilizador pedir para criar, montar ou sugerir um treino para salvar no aplicativo:
1. Considera o perfil completo: objetivo, estética, estilo, experiência, gênero e equipamentos registados.
2. Se algum exercício que queiras incluir precisar de equipamento que não está na lista, pergunta se o utilizador tem esse equipamento; se sim, usa registerEquipment e inclui o exercício; se não, escolhe um substituto.
3. Usa a função createWorkout com nome e lista de exercícios (exerciseName, sets, reps, restSeconds). Usa apenas nomes exatos do catálogo.
4. Após criar, confirma o nome e o número de exercícios e sugere abrir o módulo Training para ver e executar.
''';

  @override
  Stream<String> sendMessage({
    required String userMessage,
    required List<ChironMessage> history,
    required String userContext,
  }) async* {
    _enforceRateLimit();

    final modelIds =
        await _modelsLoader.getModelIdsForChat() ?? _geminiModelIdsFallback;

    Object? lastError;
    for (final modelId in modelIds) {
      try {
        await for (final chunk in _sendWithGeminiModel(
          modelId: modelId,
          userMessage: userMessage,
          history: history,
          userContext: userContext,
        )) {
          yield chunk;
        }
        return;
      } catch (e) {
        lastError = e;
        if (!_isQuotaOrRateLimit(e)) rethrow;
      }
    }
    if (lastError != null) {
      if (lastError is Exception) throw lastError;
      throw Exception(lastError.toString());
    }
  }

  /// Returns true if the exception indicates quota or rate limit (try next model).
  static bool _isQuotaOrRateLimit(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('quota') ||
        s.contains('rate limit') ||
        s.contains('resource_exhausted');
  }

  /// Sends the message using a single Gemini model via REST (supports
  /// thought_signature for thinking models). May throw on API errors.
  Stream<String> _sendWithGeminiModel({
    required String modelId,
    required String userMessage,
    required List<ChironMessage> history,
    required String userContext,
  }) async* {
    final systemInstruction = '$_systemPrompt\n\n$userContext';
    final toolDeclarations = getChironToolDeclarations();

    var contents = <Map<String, dynamic>>[];
    for (final msg in history) {
      final role = msg.role == ChironRole.user ? 'user' : 'model';
      contents.add({
        'role': role,
        'parts': [
          {'text': msg.content}
        ],
      });
    }
    contents.add({
      'role': 'user',
      'parts': [
        {'text': userMessage}
      ],
    });

    var parse = GeminiResponseParse(text: '');
    var createWorkoutSucceededThisTurn = false;

    while (true) {
      final responseJson = await _restClient.generateContent(
        modelId: modelId,
        contents: contents,
        systemInstruction: systemInstruction,
        toolDeclarations: toolDeclarations,
      );

      parse = parseGenerateContentResponse(responseJson);

      if (kDebugMode && parse.functionCalls.isEmpty && (parse.text == null || parse.text!.isEmpty)) {
        final candidate = (responseJson['candidates'] as List<dynamic>?)?.firstOrNull as Map<String, dynamic>?;
        final content = candidate?['content'] as Map<String, dynamic>?;
        final contentParts = content?['parts'] as List<dynamic>?;
        debugPrint('[Chiron] Empty response. finishReason=${candidate?['finishReason']}, parts count=${contentParts?.length ?? 0}');
      }

      if (parse.functionCalls.isEmpty) {
        break;
      }

      final nameToResponse = <MapEntry<String, Map<String, Object?>>>[];
      for (final call in parse.functionCalls) {
        if (kDebugMode) debugPrint('[Chiron] Function call: ${call.name}');
        final result = await _handleFunctionCallByName(call.name, call.args);
        if (call.name == 'createWorkout' && result['success'] == true) {
          createWorkoutSucceededThisTurn = true;
        }
        if (kDebugMode && result['success'] == false) {
          debugPrint('[Chiron] ${call.name} failed: ${result['error']}');
        }
        nameToResponse.add(MapEntry(call.name, result));
      }

      contents = List<Map<String, dynamic>>.from(contents);
      contents.add({
        'role': 'model',
        'parts': parse.modelParts,
      });
      contents.add({
        'role': 'user',
        'parts': buildFunctionResponseParts(
          thoughtSignature: parse.thoughtSignature,
          nameToResponse: nameToResponse,
        ),
      });
    }

    final text = parse.text;
    if (text != null && text.isNotEmpty) {
      yield text;
    } else if (createWorkoutSucceededThisTurn) {
      yield 'Treino criado e salvo no seu perfil. Confira no módulo Treino.';
    }
  }

  Future<Map<String, Object?>> _handleFunctionCallByName(
    String name,
    Map<String, dynamic> args,
  ) async {
    switch (name) {
      case 'updateBio':
        return _handleUpdateBio(args['bio'] as String);
      case 'updateInjuries':
        return _handleUpdateInjuries(args['injuries'] as String);
      case 'updateExperienceLevel':
        return _handleUpdateExperienceLevel(args['level'] as String);
      case 'updateTrainingFrequency':
        final days = args['daysPerWeek'];
        return _handleUpdateTrainingFrequency(
          days is int ? days : int.parse(days.toString()),
        );
      case 'updateGender':
        return _handleUpdateGender(args['gender'] as String);
      case 'registerEquipment':
        return _handleRegisterEquipment(args['equipmentName'] as String);
      case 'removeEquipment':
        return _handleRemoveEquipment(args['equipmentName'] as String);
      case 'createWorkout':
        return _handleCreateWorkout(
          args['name']?.toString() ?? '',
          args['description']?.toString(),
          args['exercises'] is List ? args['exercises'] as List? : null,
        );
      default:
        return {'success': false, 'error': 'Unknown function: $name'};
    }
  }

  Future<Map<String, Object?>> _handleCreateWorkout(
    String name,
    String? description,
    List? exercisesList,
  ) async {
    if (name.trim().isEmpty) {
      return {'success': false, 'error': 'Nome do treino é obrigatório'};
    }
    if (exercisesList == null || exercisesList.isEmpty) {
      return {'success': false, 'error': 'O treino precisa de pelo menos um exercício'};
    }

    final workoutExercises = <domain_we.WorkoutExercise>[];
    for (var i = 0; i < exercisesList.length; i++) {
      final item = exercisesList[i];
      if (item is! Map) continue;
      final map = item;
      final exerciseName = map['exerciseName']?.toString().trim();
      if (exerciseName == null || exerciseName.isEmpty) continue;

      final sets = _parseInt(map['sets'], 3);
      final reps = map['reps'] != null ? _parseInt(map['reps'], 10) : null;
      final restSeconds = map['restSeconds'] != null
          ? _parseInt(map['restSeconds'], 90)
          : 90;
      final durationSeconds =
          map['durationSeconds'] != null ? _parseInt(map['durationSeconds'], 0) : null;

      final exResult = await _exerciseRepo.findByName(exerciseName);
      if (!exResult.isSuccess) {
        return {
          'success': false,
          'error': 'Erro ao buscar exercício "$exerciseName"',
        };
      }
      final exercise = exResult.getOrThrow();
      if (exercise == null) {
        return {
          'success': false,
          'error': 'Exercício não encontrado no catálogo: "$exerciseName". '
              'Use o nome exato do exercício.',
        };
      }

      workoutExercises.add(
        domain_we.WorkoutExercise(
          workoutId: 0,
          exerciseId: exercise.id,
          order: i,
          sets: sets,
          reps: reps,
          rest: restSeconds,
          duration: durationSeconds,
          groupId: null,
        ),
      );
    }

    if (workoutExercises.isEmpty) {
      return {'success': false, 'error': 'Nenhum exercício válido para criar o treino'};
    }

    final workout = domain_workout.Workout(
      id: 0,
      name: name.trim(),
      description: description?.trim().isEmpty ?? true ? null : description?.trim(),
      createdAt: DateTime.now(),
    );

    final result = await _workoutRepo.create(workout, workoutExercises);
    if (!result.isSuccess) {
      return {'success': false, 'error': 'Falha ao salvar o treino'};
    }

    final id = result.getOrThrow();
    return {
      'success': true,
      'workoutId': id,
      'workoutName': workout.name,
      'exerciseCount': workoutExercises.length,
    };
  }

  int _parseInt(dynamic value, int fallback) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.round();
    final parsed = int.tryParse(value.toString());
    return parsed ?? fallback;
  }

  Future<Map<String, Object?>> _handleUpdateBio(String newBio) async {
    final profile = await _getProfile();
    if (profile == null) return {'success': false, 'error': 'No profile'};

    final existing = profile.bio ?? '';
    final combined =
        existing.isEmpty ? newBio : '$existing; $newBio';

    final result = await _profileRepo.update(
      profile.copyWith(bio: () => combined),
    );
    return result.isSuccess
        ? {'success': true, 'bio': combined}
        : {'success': false, 'error': 'Failed to update bio'};
  }

  Future<Map<String, Object?>> _handleUpdateInjuries(
      String newInjuries) async {
    final profile = await _getProfile();
    if (profile == null) return {'success': false, 'error': 'No profile'};

    final existing = profile.injuries ?? '';
    final combined =
        existing.isEmpty ? newInjuries : '$existing; $newInjuries';

    final result = await _profileRepo.update(
      profile.copyWith(injuries: () => combined),
    );
    return result.isSuccess
        ? {'success': true, 'injuries': combined}
        : {'success': false, 'error': 'Failed to update injuries'};
  }

  Future<Map<String, Object?>> _handleUpdateExperienceLevel(
      String level) async {
    final profile = await _getProfile();
    if (profile == null) return {'success': false, 'error': 'No profile'};

    final parsed = ExperienceLevel.values.firstWhere(
      (e) => e.name == level,
      orElse: () => ExperienceLevel.beginner,
    );

    final result = await _profileRepo.update(
      profile.copyWith(experienceLevel: () => parsed),
    );
    return result.isSuccess
        ? {'success': true, 'level': parsed.name}
        : {'success': false, 'error': 'Failed to update experience level'};
  }

  Future<Map<String, Object?>> _handleUpdateTrainingFrequency(
      int days) async {
    final profile = await _getProfile();
    if (profile == null) return {'success': false, 'error': 'No profile'};

    final clamped = days.clamp(1, 7);
    final result = await _profileRepo.update(
      profile.copyWith(trainingFrequency: () => clamped),
    );
    return result.isSuccess
        ? {'success': true, 'daysPerWeek': clamped}
        : {'success': false, 'error': 'Failed to update frequency'};
  }

  Future<Map<String, Object?>> _handleUpdateGender(String gender) async {
    final profile = await _getProfile();
    if (profile == null) return {'success': false, 'error': 'No profile'};

    final parsed = Gender.values
        .where((e) => e.name == gender)
        .firstOrNull;
    if (parsed == null) {
      return {'success': false, 'error': 'Invalid gender: $gender'};
    }
    final result = await _profileRepo.update(
      profile.copyWith(gender: () => parsed),
    );
    return result.isSuccess
        ? {'success': true, 'gender': parsed.name}
        : {'success': false, 'error': 'Failed to update gender'};
  }

  Future<Map<String, Object?>> _handleRegisterEquipment(
      String equipmentName) async {
    final result = await _equipmentRepo.addByName(equipmentName);
    return result.isSuccess
        ? {'success': true, 'equipment': equipmentName}
        : {'success': false, 'error': 'Failed to register equipment'};
  }

  Future<Map<String, Object?>> _handleRemoveEquipment(
      String equipmentName) async {
    final result = await _equipmentRepo.removeByName(equipmentName);
    return result.isSuccess
        ? {'success': true, 'removed': equipmentName}
        : {'success': false, 'error': 'Failed to remove equipment'};
  }

  Future<UserProfile?> _getProfile() async {
    final result = await _profileRepo.get();
    return result.isSuccess ? result.getOrThrow() : null;
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
