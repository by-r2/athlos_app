import 'dart:async';

import 'package:google_generative_ai/google_generative_ai.dart';

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

class ChironRepositoryImpl implements ChironRepository {
  final String _apiKey;
  final UserProfileRepository _profileRepo;
  final EquipmentRepository _equipmentRepo;
  final WorkoutRepository _workoutRepo;
  final ExerciseRepository _exerciseRepo;

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

  static final _toolDeclarations = [
    Tool(functionDeclarations: [
      FunctionDeclaration(
        'updateBio',
        'Acrescenta informação ao campo bio do perfil do utilizador. '
            'Concatena ao bio existente, nunca sobrescreve.',
        Schema.object(properties: {
          'bio': Schema.string(
            description: 'Texto a acrescentar ao bio existente',
          ),
        }, requiredProperties: [
          'bio'
        ]),
      ),
      FunctionDeclaration(
        'updateInjuries',
        'Acrescenta lesão/limitação ao campo injuries do perfil. '
            'Concatena ao texto existente, nunca sobrescreve.',
        Schema.object(properties: {
          'injuries': Schema.string(
            description: 'Texto da lesão a acrescentar',
          ),
        }, requiredProperties: [
          'injuries'
        ]),
      ),
      FunctionDeclaration(
        'updateExperienceLevel',
        'Atualiza o nível de experiência do utilizador.',
        Schema.object(properties: {
          'level': Schema.enumString(
            enumValues: ['beginner', 'intermediate', 'advanced'],
            description: 'Nível de experiência',
          ),
        }, requiredProperties: [
          'level'
        ]),
      ),
      FunctionDeclaration(
        'updateGender',
        'Atualiza o gênero do utilizador (influencia a montagem dos treinos).',
        Schema.object(properties: {
          'gender': Schema.enumString(
            enumValues: ['male', 'female'],
            description: 'Gênero: male = homem, female = mulher',
          ),
        }, requiredProperties: [
          'gender'
        ]),
      ),
      FunctionDeclaration(
        'updateTrainingFrequency',
        'Atualiza a frequência de treino semanal do utilizador.',
        Schema.object(properties: {
          'daysPerWeek': Schema.integer(
            description: 'Número de dias por semana (1-7)',
          ),
        }, requiredProperties: [
          'daysPerWeek'
        ]),
      ),
      FunctionDeclaration(
        'registerEquipment',
        'Regista um equipamento que o utilizador confirmou ter disponível.',
        Schema.object(properties: {
          'equipmentName': Schema.string(
            description: 'Nome do equipamento a registar',
          ),
        }, requiredProperties: [
          'equipmentName'
        ]),
      ),
      FunctionDeclaration(
        'removeEquipment',
        'Remove um equipamento que o utilizador disse já não ter.',
        Schema.object(properties: {
          'equipmentName': Schema.string(
            description: 'Nome do equipamento a remover',
          ),
        }, requiredProperties: [
          'equipmentName'
        ]),
      ),
      FunctionDeclaration(
        'createWorkout',
        'Cria um treino no aplicativo com o nome e a lista de exercícios. '
            'Usa os nomes exatos dos exercícios do catálogo (o contexto inclui treinos existentes com nomes de exercícios). '
            'Cada exercício tem sets, reps e tempo de descanso em segundos.',
        Schema.object(
          properties: {
            'name': Schema.string(
              description: 'Nome do treino',
            ),
            'description': Schema.string(
              description: 'Descrição opcional do treino',
              nullable: true,
            ),
            'exercises': Schema.array(
              description: 'Lista de exercícios do treino, na ordem desejada',
              items: Schema.object(
                properties: {
                  'exerciseName': Schema.string(
                    description:
                        'Nome exato do exercício no catálogo (ex: Supino reto, Agachamento livre)',
                  ),
                  'sets': Schema.integer(
                    description: 'Número de séries (ex: 3)',
                  ),
                  'reps': Schema.integer(
                    description: 'Repetições por série (ex: 10). Para cardio use 0 e preencha durationSeconds',
                    nullable: true,
                  ),
                  'restSeconds': Schema.integer(
                    description: 'Descanso entre séries em segundos (ex: 90)',
                    nullable: true,
                  ),
                  'durationSeconds': Schema.integer(
                    description: 'Duração por série em segundos (só para cardio)',
                    nullable: true,
                  ),
                },
                requiredProperties: ['exerciseName', 'sets'],
              ),
            ),
          },
          requiredProperties: ['name', 'exercises'],
        ),
      ),
    ]),
  ];

  ChironRepositoryImpl({
    required String apiKey,
    required UserProfileRepository profileRepo,
    required EquipmentRepository equipmentRepo,
    required WorkoutRepository workoutRepo,
    required ExerciseRepository exerciseRepo,
  })  : _apiKey = apiKey,
        _profileRepo = profileRepo,
        _equipmentRepo = equipmentRepo,
        _workoutRepo = workoutRepo,
        _exerciseRepo = exerciseRepo;

  @override
  Stream<String> sendMessage({
    required String userMessage,
    required List<ChironMessage> history,
    required String userContext,
  }) async* {
    _enforceRateLimit();

    final model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: _apiKey,
      systemInstruction: Content.system('$_systemPrompt\n\n$userContext'),
      tools: _toolDeclarations,
    );

    final chatHistory = history.map((msg) {
      final role = msg.role == ChironRole.user ? 'user' : 'model';
      return Content(role, [TextPart(msg.content)]);
    }).toList();

    final chat = model.startChat(history: chatHistory);
    var response = await chat.sendMessage(Content.text(userMessage));

    // Function calling loop: handle tool calls until we get pure text
    while (response.functionCalls.isNotEmpty) {
      final functionResponses = <FunctionResponse>[];

      for (final call in response.functionCalls) {
        final result = await _handleFunctionCall(call);
        functionResponses.add(
          FunctionResponse(call.name, result),
        );
      }

      response = await chat.sendMessage(
        Content.functionResponses(functionResponses),
      );
    }

    final text = response.text;
    if (text != null && text.isNotEmpty) {
      yield text;
    }
  }

  Future<Map<String, Object?>> _handleFunctionCall(FunctionCall call) async {
    switch (call.name) {
      case 'updateBio':
        return _handleUpdateBio(call.args['bio'] as String);
      case 'updateInjuries':
        return _handleUpdateInjuries(call.args['injuries'] as String);
      case 'updateExperienceLevel':
        return _handleUpdateExperienceLevel(call.args['level'] as String);
      case 'updateTrainingFrequency':
        final days = call.args['daysPerWeek'];
        return _handleUpdateTrainingFrequency(
          days is int ? days : int.parse(days.toString()),
        );
      case 'updateGender':
        return _handleUpdateGender(call.args['gender'] as String);
      case 'registerEquipment':
        return _handleRegisterEquipment(
            call.args['equipmentName'] as String);
      case 'removeEquipment':
        return _handleRemoveEquipment(
            call.args['equipmentName'] as String);
      case 'createWorkout':
        return _handleCreateWorkout(
          call.args['name'] as String,
          call.args['description'] as String?,
          call.args['exercises'] as List<dynamic>?,
        );
      default:
        return {'success': false, 'error': 'Unknown function: ${call.name}'};
    }
  }

  Future<Map<String, Object?>> _handleCreateWorkout(
    String name,
    String? description,
    List<dynamic>? exercisesList,
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
      if (item is! Map<String, dynamic>) continue;
      final exerciseName = item['exerciseName']?.toString().trim();
      if (exerciseName == null || exerciseName.isEmpty) continue;

      final sets = _parseInt(item['sets'], 3);
      final reps = item['reps'] != null ? _parseInt(item['reps'], 10) : null;
      final restSeconds = item['restSeconds'] != null
          ? _parseInt(item['restSeconds'], 90)
          : 90;
      final durationSeconds =
          item['durationSeconds'] != null ? _parseInt(item['durationSeconds'], 0) : null;

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
