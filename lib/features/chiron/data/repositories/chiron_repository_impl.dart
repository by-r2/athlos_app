import 'dart:async';
import 'dart:math';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/result.dart';
import '../../../profile/domain/entities/body_metric.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../../profile/domain/enums/experience_level.dart';
import '../../../profile/domain/enums/gender.dart';
import '../../../profile/domain/repositories/body_metric_repository.dart';
import '../../../profile/domain/repositories/user_profile_repository.dart';
import '../../../training/domain/entities/cycle_step.dart';
import '../../../training/domain/entities/workout.dart' as domain_workout;
import '../../../training/domain/entities/workout_exercise.dart' as domain_we;
import '../../../training/domain/repositories/cycle_repository.dart';
import '../../../training/domain/repositories/exercise_repository.dart';
import '../../../training/domain/entities/progression_rule.dart';
import '../../../training/domain/enums/progression_condition.dart';
import '../../../training/domain/enums/progression_frequency.dart';
import '../../../training/domain/enums/progression_type.dart';
import '../../../training/domain/entities/training_program.dart';
import '../../../training/domain/enums/duration_mode.dart';
import '../../../training/domain/enums/program_focus.dart';
import '../../../training/domain/entities/execution_set.dart';
import '../../../training/domain/helpers/training_metrics.dart';
import '../../../training/domain/repositories/program_repository.dart';
import '../../../training/domain/repositories/progression_rule_repository.dart';
import '../../../training/domain/repositories/workout_execution_repository.dart';
import '../../../training/domain/repositories/workout_repository.dart';
import '../../domain/entities/chiron_message.dart';
import '../../domain/repositories/chiron_repository.dart';
import '../helpers/chiron_equipment_names.dart';
import '../helpers/prompt_builder.dart';
import '../seeds/chiron_context_seed.dart';
import '../services/gemini_rest_client.dart';

/// Ordered model chain: primary first, fallback second.
/// gemini-2.5-flash is the best free-tier model for function calling;
/// gemini-2.0-flash serves as fallback when quota is exhausted.
const List<String> _geminiModelIds = ['gemini-2.5-flash', 'gemini-2.0-flash'];

/// Max output tokens per API call (includes thinking tokens for 2.5 models).
/// Must accommodate thinking budget + function call JSON or text response.
const int _maxOutputTokens = 4096;

/// Cap on thinking tokens for thinking models (gemini-2.5-flash).
/// Leaves the rest of maxOutputTokens for the actual visible response.
const int _thinkingBudget = 2048;

/// Slightly below default (1.0) for more consistent, reliable tool usage.
const double _temperature = 0.8;

/// Hard cap on function-calling round-trips per user message.
/// Prevents infinite loops from burning RPM quota.
const int _maxFunctionCallingRounds = 4;

const List<Duration> _geminiRetryBackoff = [
  Duration(seconds: 1),
  Duration(seconds: 2),
];
const int _geminiRetryJitterMaxMs = 400;

class ChironRepositoryImpl implements ChironRepository {
  ChironRepositoryImpl({
    required String apiKey,
    required UserProfileRepository profileRepo,
    required WorkoutRepository workoutRepo,
    required ExerciseRepository exerciseRepo,
    required CycleRepository cycleRepo,
    required ProgramRepository programRepo,
    required ProgressionRuleRepository progressionRuleRepo,
    required BodyMetricRepository bodyMetricRepo,
    required WorkoutExecutionRepository executionRepo,
    required PromptBuilder promptBuilder,
  }) : _profileRepo = profileRepo,
       _workoutRepo = workoutRepo,
       _exerciseRepo = exerciseRepo,
       _cycleRepo = cycleRepo,
       _programRepo = programRepo,
       _progressionRuleRepo = progressionRuleRepo,
       _bodyMetricRepo = bodyMetricRepo,
       _executionRepo = executionRepo,
       _promptBuilder = promptBuilder,
       _restClient = GeminiRestClient(apiKey: apiKey);

  final UserProfileRepository _profileRepo;
  final GeminiRestClient _restClient;
  final WorkoutRepository _workoutRepo;
  final ExerciseRepository _exerciseRepo;
  final CycleRepository _cycleRepo;
  final ProgramRepository _programRepo;
  final ProgressionRuleRepository _progressionRuleRepo;
  final BodyMetricRepository _bodyMetricRepo;
  final WorkoutExecutionRepository _executionRepo;
  final PromptBuilder _promptBuilder;

  /// Client-side RPM guard aligned with the free tier (10 RPM for
  /// gemini-2.5-flash). Counts every generateContent call, not just
  /// user messages, because function calling round-trips also count.
  static const _maxApiCallsPerMinute = 10;

  /// Max conversation turns (user+assistant pairs) sent to the API.
  /// 8 turns ≈ 16 messages — enough context for continuity while
  /// keeping input tokens low on the free tier.
  static const int _maxHistoryTurns = 8;
  static final Random _random = Random();
  final _timestamps = <DateTime>[];

  static const _systemPrompt =
      r'''You are Quíron — THE Chiron, the immortal centaur of Greek mythology and an experienced personal trainer. You trained Achilles, Heracles, and Jason. Now you train modern heroes through the Athlos app.

PERSONA & STYLE
- Always answer in Brazilian Portuguese. BE BRIEF — 2-3 short sentences max, WhatsApp style.
- Speak as the mythological Chiron: wise, direct, encouraging.
- Occasionally (not every message — roughly 1 in 4), end with a short standalone mythological quip on a separate paragraph. Compare the user's situation to a Greek myth you witnessed — keep it brief, witty, and always different. Draw from any myth (Heracles, Achilles, Jason, Perseus, Odysseus, Atalanta, etc). Never repeat the same reference twice in a conversation.
- Gender-aware address from User Profile: male → "guerreiro", "meu pupilo"; female → "guerreira", "minha pupila"; unknown → "meio-sangue" or user's name. NEVER use "guerreiro(a)" or "meu(minha)". Avoid "meu herói/heroína" as direct address — sounds unnatural. Use "herói/heroína" only as descriptor ("treinou como um herói").
- When calling tools, just call them — NEVER announce ("vou consultar", "deixa eu verificar").
- After creating/modifying a workout, confirm in one sentence. Do NOT list exercises back.
- Always be SPECIFIC and actionable. Never give vague advice. Say exactly what: how many sessions, how many weeks, what weight increase, what to track. Numbers, not generalities.
- Never give medical advice — recommend a health professional.
- Never expose internal IDs to the user.

RULES
- Profile fields missing (gender, experienceLevel, trainingFrequency, trainsAtGym, availableWorkoutMinutes)? Ask one at a time, naturally, and save with the tool.
- Injuries: use setInjuries with the COMPLETE updated text (read existing first). Bio: use updateBio to append new info only.
- Gym user ("Trains at gym: Yes") → assume standard equipment, no questions. Home user → if profile "Owned equipment" list is empty, ask what they have and call registerEquipment once per item. Otherwise use that list + bodyweight. Suggest missing items: "tu tem ou consegue improvisar um(a) X?"
- createWorkout/archiveWorkout do NOT update the cycle. You MUST call setCycle afterward with all active workout IDs, then getTrainingState to verify.

TRAINING — HOW TO BEHAVE
You are an evidence-based personal trainer. Your job is to give reliable, actionable advice.

Data reading:
- "Active Workouts" = workout names with exercise lists (→). "Recent History" = actual sessions with loads/reps.
- Read the data precisely. NEVER confuse number of workouts with number of exercises.
- If context data is insufficient for a reliable analysis (few sessions, no progression data), say so honestly. Never invent or guess.

Program changes:
- NEVER suggest changing a program just because time passed. Only suggest changes when: key lifts plateau 3+ weeks, persistent fatigue, goals changed, or the program is clearly flawed.
- If the user is progressing (weights/reps increasing across sessions) → celebrate and encourage consistency. Do NOT suggest changes.
- Minimum 4-8 weeks before any program change recommendation.

Building/analyzing workouts:
- Calculate weekly volume per muscle group based on experience level. Flag if clearly too low or too high.
- Check balance: push vs pull, anterior vs posterior. Flag imbalances.
- Respect available workout time from profile.

Analyzing progress:
- Compare the same exercise across sessions in Recent History.
- Increasing → progressing, encourage. Stagnant → suggest deload or variation. Decreasing → ask about recovery/sleep/stress.

<examples>
User: "Monta um treino de peito"
[calls createWorkout, setCycle, getTrainingState]
Assistant: "Pronto, guerreiro! Montei teu treino de peito com 5 exercícios. Dá uma olhada e me diz o que achou! ⚔️"

User: "Analise meu treino e veja se preciso trocar"
[reads Active Workouts and Recent History from context]
Assistant: "Teu Leg Day tem agachamento, leg press e extensora — boa base. Pelo histórico, teu agachamento subiu de 60kg pra 70kg em 3 semanas. Tá progredindo bem, não mexe nisso agora — consistência é o que separa heróis de mortais."

User: "Analise meu progresso"
[context has only 2 sessions recorded]
Assistant: "Meio-sangue, com apenas 2 sessões registradas ainda não consigo traçar uma análise confiável. Bota mais umas 3-4 sessões no histórico e aí te dou um panorama real da tua evolução."

User: "Quero trocar meu treino"
Assistant: "Qual o foco do novo treino, guerreiro?"

User: "Tenho dor no ombro quando faço supino"
Assistant: "Recomendo consultar um profissional de saúde pra avaliar esse ombro antes de continuar. Enquanto isso, posso montar um treino que evite pressão no ombro — quer?"
</examples>
''';
  static final RegExp _extendedContextPattern = RegExp(
    chironExtendedContextRegexSeed.join('|'),
    caseSensitive: false,
  );

  @override
  Stream<String> sendMessage({
    required String userMessage,
    required List<ChironMessage> history,
    ChironToolInvokedCallback? onToolInvoked,
  }) async* {
    final maxHistoryMessages = _maxHistoryTurns * 2;
    final trimmedHistory = history.length > maxHistoryMessages
        ? history.sublist(history.length - maxHistoryMessages)
        : history;
    final shouldStartExtended = _needsExtendedContext(userMessage);
    final initialUserContext = await _promptBuilder.build(
      extended: shouldStartExtended,
    );

    final modelIds = _geminiModelIds;

    Object? lastError;
    for (final modelId in modelIds) {
      for (var attempt = 0; attempt <= _geminiRetryBackoff.length; attempt++) {
        try {
          await for (final chunk in _sendWithGeminiModel(
            modelId: modelId,
            userMessage: userMessage,
            history: trimmedHistory,
            userContext: initialUserContext,
            extendedAlreadyLoaded: shouldStartExtended,
            onToolInvoked: onToolInvoked,
          )) {
            yield chunk;
          }
          return;
        } catch (e) {
          lastError = e;
          final shouldRetryOnSameModel =
              _isRetryableError(e) && attempt < _geminiRetryBackoff.length;
          if (shouldRetryOnSameModel) {
            await Future<void>.delayed(
              _withJitter(_geminiRetryBackoff[attempt]),
            );
            continue;
          }
          if (_isModelFallbackError(e)) {
            break;
          }
          rethrow;
        }
      }
    }
    if (lastError != null) {
      // ignore: only_throw_errors
      throw lastError;
    }
  }

  /// Returns true when we can switch to the next model.
  static bool _isModelFallbackError(Object e) {
    return _isQuotaOrRateLimit(e) || _isRetryableError(e);
  }

  /// Returns true if the exception indicates quota or rate limit (try next model).
  static bool _isQuotaOrRateLimit(Object e) {
    if (e is GeminiApiException) return e.isQuotaOrRateLimit;
    final s = e.toString().toLowerCase();
    return s.contains('quota') ||
        s.contains('rate limit') ||
        s.contains('resource_exhausted');
  }

  /// Returns true for transient errors where retrying can succeed.
  static bool _isRetryableError(Object e) {
    if (e is GeminiApiException && e.isRetryable) return true;

    final s = e.toString().toLowerCase();
    return s.contains('high demand') ||
        s.contains('temporar') ||
        s.contains('timeout') ||
        s.contains('socketexception') ||
        s.contains('failed host lookup') ||
        s.contains('handshake') ||
        s.contains('connection closed');
  }

  static Duration _withJitter(Duration baseDelay) {
    final jitterMs = _random.nextInt(_geminiRetryJitterMaxMs + 1);
    return baseDelay + Duration(milliseconds: jitterMs);
  }

  static bool _needsExtendedContext(String userMessage) {
    return _extendedContextPattern.hasMatch(userMessage.toLowerCase());
  }

  static final RegExp _workoutActionPattern = RegExp(
    r'(mont|cri|trein|substitui|troc|arquiv|novo|perna|peito|costas|ombro|'
    r'braço|bíceps|tríceps|abdomen|push|pull|leg|upper|lower|full\s*body|'
    r'split|ciclo|rotina|plano)',
    caseSensitive: false,
  );

  static final RegExp _equipmentPattern = RegExp(
    r'(equipamento|haltere|barra|máquina|cabo|polia|anilha|banco|corda|'
    r'kettlebell|elástic|faixa|smith|leg\s*press|hack)',
    caseSensitive: false,
  );

  static const _workoutAndEquipmentTools = {
    'createWorkout',
    'updateWorkout',
    'archiveWorkout',
    'setCycle',
    'getTrainingState',
    'registerEquipment',
    'removeEquipment',
  };

  /// Returns tool declarations filtered to the message context.
  ///
  /// Profile tools are always available — the model needs them to collect
  /// user info during natural conversation (onboarding, follow-ups).
  /// Workout & equipment tools are only included when action keywords match,
  /// saving output tokens on pure Q&A turns.
  static List<Map<String, dynamic>> _toolsForContext(String userMessage) {
    final msg = userMessage.toLowerCase();

    final needsWorkoutTools =
        _workoutActionPattern.hasMatch(msg) || _equipmentPattern.hasMatch(msg);

    if (needsWorkoutTools) return getChironToolDeclarations();

    // Profile tools + requestExtendedHistory always available;
    // workout/equipment tools excluded.
    return getChironToolDeclarations()
        .where((t) => !_workoutAndEquipmentTools.contains(t['name']))
        .toList();
  }

  /// Sends the message using a single Gemini model via REST (supports
  /// thought_signature for thinking models). May throw on API errors.
  Stream<String> _sendWithGeminiModel({
    required String modelId,
    required String userMessage,
    required List<ChironMessage> history,
    required String userContext,
    required bool extendedAlreadyLoaded,
    ChironToolInvokedCallback? onToolInvoked,
  }) async* {
    var currentUserContext = userContext;
    var hasExtendedContext = extendedAlreadyLoaded;
    var systemInstruction = '$_systemPrompt\n\n$currentUserContext';
    final toolDeclarations = _toolsForContext(userMessage);

    var contents = _buildMergedContents(history, userMessage);

    var parse = GeminiResponseParse(text: '');
    var fcRound = 0;

    while (true) {
      _enforceRateLimit();
      final responseJson = await _restClient.generateContent(
        modelId: modelId,
        contents: contents,
        systemInstruction: systemInstruction,
        toolDeclarations: toolDeclarations,
        maxOutputTokens: _maxOutputTokens,
        temperature: _temperature,
        thinkingBudget: _thinkingBudget,
      );

      parse = parseGenerateContentResponse(responseJson);

      if (parse.functionCalls.isEmpty) {
        break;
      }

      // Text from rounds with function calls is narration ("let me check...")
      // — discard it. Only text from the final round (no function calls)
      // is the real response.

      fcRound++;
      if (fcRound > _maxFunctionCallingRounds) break;

      final nameToResponse = <MapEntry<String, Map<String, Object?>>>[];
      for (final call in parse.functionCalls) {
        late final Map<String, Object?> result;
        if (call.name == 'requestExtendedHistory') {
          if (hasExtendedContext) {
            result = {
              'success': true,
              'message': 'Extended context was already loaded.',
            };
          } else {
            currentUserContext = await _promptBuilder.build(extended: true);
            systemInstruction = '$_systemPrompt\n\n$currentUserContext';
            hasExtendedContext = true;
            result = {
              'success': true,
              'message':
                  'Extended context loaded with additional workout history.',
            };
          }
        } else {
          result = await _handleFunctionCallByName(call.name, call.args);
        }
        nameToResponse.add(MapEntry(call.name, result));
        final success = result['success'] == true;
        onToolInvoked?.call(
          call.name,
          success,
          result.map((k, v) => MapEntry(k.toString(), v)),
        );
      }

      contents = List<Map<String, dynamic>>.from(contents);
      contents.add({'role': 'model', 'parts': parse.modelParts});
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
    }
  }

  Future<Map<String, Object?>> _handleFunctionCallByName(
    String name,
    Map<String, dynamic> args,
  ) async {
    switch (name) {
      case 'updateBio':
        final bio = args['bio']?.toString();
        if (bio == null || bio.isEmpty) {
          return {'success': false, 'error': 'bio is required'};
        }
        return _handleUpdateBio(bio);
      case 'setInjuries':
        final injuries = args['injuries']?.toString();
        if (injuries == null) {
          return {'success': false, 'error': 'injuries is required'};
        }
        return _handleSetInjuries(injuries);
      case 'updateExperienceLevel':
        final level = args['level']?.toString();
        if (level == null || level.isEmpty) {
          return {'success': false, 'error': 'level is required'};
        }
        return _handleUpdateExperienceLevel(level);
      case 'updateTrainingFrequency':
        final days = args['daysPerWeek'];
        if (days == null) {
          return {'success': false, 'error': 'daysPerWeek is required'};
        }
        return _handleUpdateTrainingFrequency(
          days is int ? days : int.parse(days.toString()),
        );
      case 'updateGender':
        final gender = args['gender']?.toString();
        if (gender == null || gender.isEmpty) {
          return {'success': false, 'error': 'gender is required'};
        }
        return _handleUpdateGender(gender);
      case 'updateTrainsAtGym':
        final value = args['trainsAtGym'];
        if (value == null) {
          return {'success': false, 'error': 'trainsAtGym is required'};
        }
        final boolValue = value is bool
            ? value
            : value.toString().toLowerCase() == 'true';
        return _handleUpdateTrainsAtGym(boolValue);
      case 'updateAvailableMinutes':
        final minutes = args['minutes'];
        if (minutes == null) {
          return {'success': false, 'error': 'minutes is required'};
        }
        return _handleUpdateAvailableMinutes(
          minutes is int ? minutes : int.parse(minutes.toString()),
        );
      case 'updateWorkout':
        return _handleUpdateWorkout(
          args['workoutId'] != null
              ? (args['workoutId'] is int
                    ? args['workoutId'] as int
                    : int.tryParse(args['workoutId'].toString()))
              : null,
          args['name']?.toString(),
          args['description']?.toString(),
          args['exercises'] is List ? args['exercises'] as List? : null,
        );
      case 'registerEquipment':
        final equipName = args['equipmentName']?.toString();
        if (equipName == null || equipName.isEmpty) {
          return {'success': false, 'error': 'equipmentName is required'};
        }
        return _handleRegisterEquipment(equipName);
      case 'removeEquipment':
        final equipName = args['equipmentName']?.toString();
        if (equipName == null || equipName.isEmpty) {
          return {'success': false, 'error': 'equipmentName is required'};
        }
        return _handleRemoveEquipment(equipName);
      case 'createWorkout':
        return _handleCreateWorkout(
          args['name']?.toString() ?? '',
          args['description']?.toString(),
          args['exercises'] is List ? args['exercises'] as List? : null,
        );
      case 'archiveWorkout':
        return _handleArchiveWorkout(
          args['workoutId'] != null
              ? (args['workoutId'] is int
                    ? args['workoutId'] as int
                    : int.tryParse(args['workoutId'].toString()))
              : null,
        );
      case 'setCycle':
        return _handleSetCycle(
          args['steps'] is List ? args['steps'] as List? : null,
        );
      case 'getTrainingState':
        return _handleGetTrainingState();
      case 'setProgressionRules':
        return _handleSetProgressionRules(
          args['programId'] is int
              ? args['programId'] as int
              : int.tryParse(args['programId']?.toString() ?? ''),
          args['rules'] is List ? args['rules'] as List : null,
        );
      case 'createProgram':
        return _handleCreateProgram(args);
      case 'archiveProgram':
        return _handleArchiveProgram(
          args['programId'] is int
              ? args['programId'] as int
              : int.tryParse(args['programId']?.toString() ?? ''),
        );
      case 'setDeloadActive':
        final programId = args['programId'] is int
            ? args['programId'] as int
            : int.tryParse(args['programId']?.toString() ?? '');
        final active = args['active'] is bool
            ? args['active'] as bool
            : args['active']?.toString().toLowerCase() == 'true';
        return _handleSetDeloadActive(programId, active);
      case 'getWeeklyVolume':
        return _handleGetWeeklyVolume();
      case 'getEstimated1RM':
        final exerciseId = args['exerciseId'] is int
            ? args['exerciseId'] as int
            : int.tryParse(args['exerciseId']?.toString() ?? '');
        return _handleGetEstimated1RM(exerciseId);
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
      return {'success': false, 'error': 'Workout name is required'};
    }
    if (exercisesList == null || exercisesList.isEmpty) {
      return {
        'success': false,
        'error': 'Workout requires at least one exercise',
      };
    }

    final workoutExercises = <domain_we.WorkoutExercise>[];
    for (var i = 0; i < exercisesList.length; i++) {
      final item = exercisesList[i];
      if (item is! Map) continue;
      final map = item;
      final exerciseName = map['exerciseName']?.toString().trim();
      if (exerciseName == null || exerciseName.isEmpty) continue;

      final sets = _parseInt(map['sets'], 3);
      final minReps = map['minReps'] != null
          ? _parseInt(map['minReps'], 10)
          : (map['reps'] != null ? _parseInt(map['reps'], 10) : null);
      final maxReps = map['maxReps'] != null
          ? _parseInt(map['maxReps'], minReps ?? 10)
          : minReps;
      final isAmrap =
          map['isAmrap'] == true ||
          map['isAmrap']?.toString().toLowerCase() == 'true';
      final restSeconds = map['restSeconds'] != null
          ? _parseInt(map['restSeconds'], 90)
          : 90;
      final durationSeconds = map['durationSeconds'] != null
          ? _parseInt(map['durationSeconds'], 0)
          : null;
      final notes = map['notes']?.toString().trim();

      final exResult = await _exerciseRepo.findByNameFuzzy(exerciseName);
      if (!exResult.isSuccess) {
        return {
          'success': false,
          'error': 'Failed to lookup exercise "$exerciseName"',
        };
      }
      final exercise = exResult.getOrThrow();
      if (exercise == null) {
        return {
          'success': false,
          'error':
              'Exercise not found in catalog: "$exerciseName". '
              'Check the Catalog section for exact names.',
        };
      }

      workoutExercises.add(
        domain_we.WorkoutExercise(
          workoutId: 0,
          exerciseId: exercise.id,
          order: i,
          sets: sets,
          minReps: minReps,
          maxReps: maxReps,
          isAmrap: isAmrap,
          rest: restSeconds,
          duration: durationSeconds,
          groupId: null,
          notes: (notes != null && notes.isNotEmpty) ? notes : null,
        ),
      );
    }

    if (workoutExercises.isEmpty) {
      return {
        'success': false,
        'error': 'No valid exercises to create workout',
      };
    }

    final workout = domain_workout.Workout(
      id: 0,
      name: name.trim(),
      description: description?.trim().isEmpty ?? true
          ? null
          : description?.trim(),
      createdAt: DateTime.now(),
    );

    final result = await _workoutRepo.create(workout, workoutExercises);
    if (!result.isSuccess) {
      return {'success': false, 'error': 'Failed to save workout'};
    }

    final id = result.getOrThrow();
    return {
      'success': true,
      'workoutId': id,
      'workoutName': workout.name,
      'exerciseCount': workoutExercises.length,
      'hint':
          'Now call setCycle to include this workout in the routine, '
          'then getTrainingState to verify.',
    };
  }

  Future<Map<String, Object?>> _handleArchiveWorkout(int? workoutId) async {
    if (workoutId == null || workoutId <= 0) {
      return {'success': false, 'error': 'Invalid workoutId'};
    }
    final result = await _workoutRepo.archive(workoutId);
    if (!result.isSuccess) {
      return {'success': false, 'error': 'Failed to archive workout'};
    }
    return {
      'success': true,
      'workoutId': workoutId,
      'hint':
          'Now call setCycle without this workout, '
          'then getTrainingState to verify.',
    };
  }

  Future<Map<String, Object?>> _handleSetCycle(List? stepsList) async {
    if (stepsList == null || stepsList.isEmpty) {
      return {
        'success': false,
        'error': 'steps is required and cannot be empty',
      };
    }
    final programResult = await _programRepo.getActive();
    final activeProgram = programResult.isSuccess
        ? programResult.getOrThrow()
        : null;
    if (activeProgram == null) {
      return {'success': false, 'error': 'No active program'};
    }
    final cycleSteps = <TrainingCycleStep>[];
    for (var i = 0; i < stepsList.length; i++) {
      final item = stepsList[i];
      if (item is! Map) continue;
      final map = item;
      final workoutId = map['workoutId'] != null
          ? (map['workoutId'] is int
                ? map['workoutId'] as int
                : int.tryParse(map['workoutId'].toString()))
          : null;
      if (workoutId == null || workoutId <= 0) continue;
      cycleSteps.add(
        TrainingCycleStep(id: 0, orderIndex: i, workoutId: workoutId),
      );
    }
    if (cycleSteps.isEmpty) {
      return {
        'success': false,
        'error': 'No valid steps (each step needs a workoutId)',
      };
    }
    final result = await _cycleRepo.setSteps(cycleSteps, activeProgram.id);
    if (!result.isSuccess) {
      return {'success': false, 'error': 'Failed to persist cycle'};
    }
    return {'success': true, 'stepCount': cycleSteps.length};
  }

  Future<Map<String, Object?>> _handleGetTrainingState() async {
    final activeResult = await _workoutRepo.getActive();
    if (!activeResult.isSuccess) {
      return {'success': false, 'error': 'Failed to load active workouts'};
    }
    final active = activeResult.getOrThrow();

    final programResult = await _programRepo.getActive();
    final activeProgram = programResult.isSuccess
        ? programResult.getOrThrow()
        : null;

    if (activeProgram == null) {
      return {
        'success': true,
        'activeWorkouts': active
            .map((w) => {'id': w.id, 'name': w.name})
            .toList(),
        'cycleSteps': <Map<String, Object?>>[],
      };
    }

    final stepsResult = await _cycleRepo.getSteps(activeProgram.id);
    if (!stepsResult.isSuccess) {
      return {'success': false, 'error': 'Failed to load cycle'};
    }
    final steps = stepsResult.getOrThrow();
    final activeById = {for (final w in active) w.id: w};
    final activeWorkouts = active
        .map((w) => {'id': w.id, 'name': w.name})
        .toList();
    final cycleSteps = <Map<String, Object?>>[];
    for (final s in steps) {
      final w = activeById[s.workoutId];
      cycleSteps.add({
        'workoutId': s.workoutId,
        'workoutName': w?.name ?? 'Workout #${s.workoutId}',
      });
    }
    final result = <String, Object?>{
      'success': true,
      'activeWorkouts': activeWorkouts,
      'cycleSteps': cycleSteps,
    };
    final sessionResult = await _programRepo.getSessionCount(activeProgram.id);
    final sessions = sessionResult.isSuccess ? sessionResult.getOrThrow() : 0;
    final programMap = <String, Object?>{
      'id': activeProgram.id,
      'name': activeProgram.name,
      'focus': activeProgram.focus.name,
      'durationMode': activeProgram.durationMode.name,
      'durationValue': activeProgram.durationValue,
      'completedSessions': sessions,
      'isInDeload': activeProgram.isInDeload,
      if (activeProgram.defaultRestSeconds != null)
        'defaultRestSeconds': activeProgram.defaultRestSeconds,
    };
    if (activeProgram.deloadConfig != null) {
      final dc = activeProgram.deloadConfig!;
      programMap['deloadConfig'] = {
        'strategy': dc.strategy.name,
        'frequency': dc.frequency,
        'volumeMultiplier': dc.volumeMultiplier,
        'intensityMultiplier': dc.intensityMultiplier,
      };
    }
    final rulesResult = await _progressionRuleRepo.getByProgram(
      activeProgram.id,
    );
    if (rulesResult.isSuccess) {
      final rules = rulesResult.getOrThrow();
      if (rules.isNotEmpty) {
        programMap['progressionRules'] = rules
            .map(
              (r) => {
                'exerciseId': r.exerciseId,
                'type': r.type.name,
                'value': r.value,
                'frequency': r.frequency.name,
                if (r.condition != null) 'condition': r.condition!.name,
                if (r.conditionValue != null)
                  'conditionValue': r.conditionValue,
              },
            )
            .toList();
      }
    }
    result['activeProgram'] = programMap;

    final bodyMetricResult = await _bodyMetricRepo.getAll();
    if (bodyMetricResult.isSuccess) {
      final metrics = bodyMetricResult.getOrThrow();
      if (metrics.isNotEmpty) {
        result['bodyWeightTimeline'] = metrics
            .take(30)
            .map(
              (m) => {
                'weight': m.weight,
                if (m.bodyFatPercent != null)
                  'bodyFatPercent': m.bodyFatPercent,
                'recordedAt': m.recordedAt.toIso8601String(),
              },
            )
            .toList();
      }
    }

    return result;
  }

  int _parseInt(dynamic value, int fallback) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.round();
    final parsed = int.tryParse(value.toString());
    return parsed ?? fallback;
  }

  Future<Map<String, Object?>> _handleSetProgressionRules(
    int? programId,
    List? rulesList,
  ) async {
    if (programId == null || programId <= 0) {
      return {'success': false, 'error': 'Invalid programId'};
    }
    if (rulesList == null) {
      return {'success': false, 'error': 'Missing rules list'};
    }
    try {
      final rules = rulesList.map((item) {
        final m = item as Map<String, dynamic>;
        final exerciseId = m['exerciseId'] is int
            ? m['exerciseId'] as int
            : int.parse(m['exerciseId'].toString());
        final type = ProgressionType.values.byName(
          m['type']?.toString() ?? 'incrementWeight',
        );
        final value = (m['value'] is num)
            ? (m['value'] as num).toDouble()
            : double.parse(m['value'].toString());
        final frequency = ProgressionFrequency.values.byName(
          m['frequency']?.toString() ?? 'everySession',
        );
        final condStr = m['condition']?.toString();
        final condition = condStr != null && condStr.isNotEmpty
            ? ProgressionCondition.values.byName(condStr)
            : null;
        final condVal = m['conditionValue'] is num
            ? (m['conditionValue'] as num).toDouble()
            : null;
        return ProgressionRule(
          id: 0,
          programId: programId,
          exerciseId: exerciseId,
          type: type,
          value: value,
          frequency: frequency,
          condition: condition,
          conditionValue: condVal,
        );
      }).toList();

      final result = await _progressionRuleRepo.replaceAllForProgram(
        programId,
        rules,
      );
      result.getOrThrow();
      return {'success': true, 'rulesCount': rules.length};
    } on Exception catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, Object?>> _handleCreateProgram(
    Map<String, dynamic> args,
  ) async {
    final name = args['name']?.toString();
    if (name == null || name.isEmpty) {
      return {'success': false, 'error': 'name is required'};
    }
    try {
      final focus = ProgramFocus.values.byName(
        args['focus']?.toString() ?? 'custom',
      );
      final durationMode = DurationMode.values.byName(
        args['durationMode']?.toString() ?? 'sessions',
      );
      final durationValue = _parseInt(args['durationValue'], 12);
      final defaultRest = args['defaultRestSeconds'] != null
          ? _parseInt(args['defaultRestSeconds'], 0)
          : focus.suggestedRestSeconds;

      final program = TrainingProgram(
        id: 0,
        name: name,
        focus: focus,
        durationMode: durationMode,
        durationValue: durationValue,
        defaultRestSeconds: defaultRest,
        createdAt: DateTime.now(),
      );
      final result = await _programRepo.create(program);
      final id = result.getOrThrow();

      final workoutIds = args['workoutIds'];
      if (workoutIds is List && workoutIds.isNotEmpty) {
        final ids = workoutIds.map((e) => _parseInt(e, 0)).toList();
        var order = 0;
        await _cycleRepo.setSteps(
          ids
              .map(
                (wId) => TrainingCycleStep(
                  id: 0,
                  orderIndex: order++,
                  workoutId: wId,
                ),
              )
              .toList(),
          id,
        );
      }

      await _programRepo.activate(id);
      return {'success': true, 'programId': id};
    } on Exception catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, Object?>> _handleArchiveProgram(int? programId) async {
    if (programId == null || programId <= 0) {
      return {'success': false, 'error': 'Invalid programId'};
    }
    try {
      final result = await _programRepo.archive(programId);
      result.getOrThrow();
      return {'success': true};
    } on Exception catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, Object?>> _handleSetDeloadActive(
    int? programId,
    bool active,
  ) async {
    if (programId == null || programId <= 0) {
      return {'success': false, 'error': 'Invalid programId'};
    }
    try {
      final result = await _programRepo.setDeloadActive(
        programId,
        active: active,
      );
      result.getOrThrow();
      return {'success': true, 'isInDeload': active};
    } on Exception catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, Object?>> _handleGetWeeklyVolume() async {
    try {
      final exercisesResult = await _exerciseRepo.getAll();
      if (!exercisesResult.isSuccess) {
        return {'success': false, 'error': 'Failed to load exercises'};
      }
      final exercises = exercisesResult.getOrThrow();
      final exerciseMap = {for (final e in exercises) e.id: e};

      final execsResult = await _executionRepo.getAll();
      if (!execsResult.isSuccess) {
        return {'success': false, 'error': 'Failed to load executions'};
      }
      final cutoff = DateTime.now().subtract(const Duration(days: 7));
      final recentExecs = execsResult.getOrThrow().where(
        (e) => e.finishedAt != null && e.startedAt.isAfter(cutoff),
      );

      final volume = <String, int>{};
      for (final exec in recentExecs) {
        final setsResult = await _executionRepo.getSets(exec.id);
        if (!setsResult.isSuccess) continue;
        for (final s in setsResult.getOrThrow()) {
          if (!s.isCompleted || s.isWarmup) continue;
          final ex = exerciseMap[s.exerciseId];
          if (ex == null) continue;
          final key = ex.muscleGroup.name;
          volume[key] = (volume[key] ?? 0) + 1;
        }
      }
      return {'success': true, 'weeklyVolume': volume};
    } on Exception catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, Object?>> _handleGetEstimated1RM(int? exerciseId) async {
    if (exerciseId == null || exerciseId <= 0) {
      return {'success': false, 'error': 'Invalid exerciseId'};
    }
    try {
      final exercisesResult = await _exerciseRepo.getAll();
      if (!exercisesResult.isSuccess) {
        return {'success': false, 'error': 'Failed to load exercises'};
      }
      final exercise = exercisesResult
          .getOrThrow()
          .where((e) => e.id == exerciseId)
          .firstOrNull;
      if (exercise == null) {
        return {'success': false, 'error': 'Exercise not found'};
      }

      final metricsResult = await _bodyMetricRepo.getAll();
      final metrics = metricsResult.isSuccess
          ? metricsResult.getOrThrow()
          : <BodyMetric>[];
      final latestWeight = metrics.isEmpty ? null : metrics.first.weight;

      double? profileWeightAtOrBefore(DateTime instant) {
        for (final m in metrics) {
          if (!m.recordedAt.isAfter(instant)) return m.weight;
        }
        return null;
      }

      final setsResult = await _executionRepo
          .getCompletedSetsWithDateForExercise(exerciseId);
      if (!setsResult.isSuccess) {
        return {'success': false, 'error': 'Failed to load sets'};
      }
      final rows = setsResult.getOrThrow();
      if (rows.isEmpty) {
        return {'success': true, 'estimated1RM': null, 'message': 'No data'};
      }

      final execIds = rows.map((r) => r.set.executionId).toSet();
      final weByExecId = <int, domain_we.WorkoutExercise?>{};
      for (final execId in execIds) {
        final execResult = await _executionRepo.getById(execId);
        final exec = execResult.isSuccess ? execResult.getOrThrow() : null;
        if (exec == null) {
          weByExecId[execId] = null;
          continue;
        }
        final wesResult = await _workoutRepo.getExercises(exec.workoutId);
        if (!wesResult.isSuccess) {
          weByExecId[execId] = null;
          continue;
        }
        weByExecId[execId] = wesResult
            .getOrThrow()
            .where((we) => we.exerciseId == exerciseId)
            .firstOrNull;
      }

      double? best1RM;
      double? bestWeight;
      int? bestReps;
      for (final row in rows) {
        final ExecutionSet s = row.set;
        if (s.isWarmup) continue;
        final we = weByExecId[s.executionId];
        final profileAt = profileWeightAtOrBefore(row.date);
        final resolvedBw =
            (s.bodyWeightSnapshot ?? profileAt ?? latestWeight) ?? 0.0;

        for (final probe in strengthEffortsForEstimated1Rm(
          s,
          exercise: exercise,
          workoutExercise: we,
          resolvedBodyWeight: resolvedBw,
        )) {
          final e1rm = estimated1RM(weight: probe.loadKg, reps: probe.reps);
          if (e1rm != null && (best1RM == null || e1rm > best1RM)) {
            best1RM = e1rm;
            bestWeight = probe.loadKg;
            bestReps = probe.reps;
          }
        }
      }
      return {
        'success': true,
        'exerciseId': exerciseId,
        'exerciseName': exercise.name,
        'estimated1RM': best1RM?.toStringAsFixed(1),
        'bestWeight': bestWeight?.toStringAsFixed(1),
        'bestReps': bestReps,
      };
    } on Exception catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static const int _maxBioLength = 500;

  Future<Map<String, Object?>> _handleUpdateBio(String newBio) async {
    final profile = await _getProfile();
    if (profile == null) return {'success': false, 'error': 'No profile'};

    final existing = profile.bio ?? '';
    var combined = existing.isEmpty ? newBio : '$existing; $newBio';

    if (combined.length > _maxBioLength) {
      combined = combined.substring(combined.length - _maxBioLength).trimLeft();
      final firstSep = combined.indexOf('; ');
      if (firstSep != -1 && firstSep < 40) {
        combined = combined.substring(firstSep + 2);
      }
    }

    final result = await _profileRepo.update(
      profile.copyWith(bio: () => combined),
    );
    return result.isSuccess
        ? {'success': true, 'bio': combined}
        : {'success': false, 'error': 'Failed to update bio'};
  }

  Future<Map<String, Object?>> _handleSetInjuries(String injuries) async {
    final profile = await _getProfile();
    if (profile == null) return {'success': false, 'error': 'No profile'};

    final value = injuries.trim().isEmpty ? null : injuries.trim();
    final result = await _profileRepo.update(
      profile.copyWith(injuries: () => value),
    );
    return result.isSuccess
        ? {'success': true, 'injuries': value ?? ''}
        : {'success': false, 'error': 'Failed to update injuries'};
  }

  Future<Map<String, Object?>> _handleUpdateExperienceLevel(
    String level,
  ) async {
    final profile = await _getProfile();
    if (profile == null) return {'success': false, 'error': 'No profile'};

    final parsed = ExperienceLevel.values
        .where((e) => e.name == level)
        .firstOrNull;
    if (parsed == null) {
      return {
        'success': false,
        'error':
            'Invalid level: $level. '
            'Use one of: ${ExperienceLevel.values.map((e) => e.name).join(", ")}',
      };
    }

    final result = await _profileRepo.update(
      profile.copyWith(experienceLevel: () => parsed),
    );
    return result.isSuccess
        ? {'success': true, 'level': parsed.name}
        : {'success': false, 'error': 'Failed to update experience level'};
  }

  Future<Map<String, Object?>> _handleUpdateTrainingFrequency(int days) async {
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

    final parsed = Gender.values.where((e) => e.name == gender).firstOrNull;
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
    String equipmentName,
  ) async {
    final profile = await _getProfile();
    if (profile == null) return {'success': false, 'error': 'No profile'};

    final normalized = chironCanonicalEquipmentName(equipmentName);
    if (normalized.isEmpty) {
      return {'success': false, 'error': 'equipmentName is empty'};
    }

    final current = [...profile.ownedEquipmentNames];
    final exists = current.any(
      (e) => e.trim().toLowerCase() == normalized.trim().toLowerCase(),
    );
    if (exists) {
      return {
        'success': true,
        'equipment': normalized,
        'message': 'Already listed on profile',
      };
    }

    current.add(normalized);
    final result = await _profileRepo.update(
      profile.copyWith(ownedEquipmentNames: current),
    );
    return result.isSuccess
        ? {'success': true, 'equipment': normalized}
        : {'success': false, 'error': 'Failed to update profile'};
  }

  Future<Map<String, Object?>> _handleRemoveEquipment(
    String equipmentName,
  ) async {
    final profile = await _getProfile();
    if (profile == null) return {'success': false, 'error': 'No profile'};

    final normalized = chironCanonicalEquipmentName(equipmentName);
    final next = profile.ownedEquipmentNames
        .where((e) => e.trim().toLowerCase() != normalized.trim().toLowerCase())
        .toList(growable: false);

    if (next.length == profile.ownedEquipmentNames.length) {
      return {'success': false, 'error': 'Not found in profile owned list'};
    }

    final result = await _profileRepo.update(
      profile.copyWith(ownedEquipmentNames: next),
    );
    return result.isSuccess
        ? {'success': true, 'removed': normalized}
        : {'success': false, 'error': 'Failed to update profile'};
  }

  Future<Map<String, Object?>> _handleUpdateTrainsAtGym(bool value) async {
    final profile = await _getProfile();
    if (profile == null) return {'success': false, 'error': 'No profile'};

    final result = await _profileRepo.update(
      profile.copyWith(trainsAtGym: () => value),
    );
    return result.isSuccess
        ? {'success': true, 'trainsAtGym': value}
        : {'success': false, 'error': 'Failed to update trainsAtGym'};
  }

  Future<Map<String, Object?>> _handleUpdateAvailableMinutes(
    int minutes,
  ) async {
    final profile = await _getProfile();
    if (profile == null) return {'success': false, 'error': 'No profile'};

    final clamped = minutes.clamp(10, 300);
    final result = await _profileRepo.update(
      profile.copyWith(availableWorkoutMinutes: () => clamped),
    );
    return result.isSuccess
        ? {'success': true, 'availableMinutes': clamped}
        : {'success': false, 'error': 'Failed to update available minutes'};
  }

  Future<Map<String, Object?>> _handleUpdateWorkout(
    int? workoutId,
    String? newName,
    String? newDescription,
    List? exercisesList,
  ) async {
    if (workoutId == null || workoutId <= 0) {
      return {'success': false, 'error': 'Invalid workoutId'};
    }

    final existingResult = await _workoutRepo.getById(workoutId);
    if (!existingResult.isSuccess) {
      return {'success': false, 'error': 'Failed to load workout'};
    }
    final existing = existingResult.getOrThrow();
    if (existing == null) {
      return {'success': false, 'error': 'Workout not found: $workoutId'};
    }

    final name = (newName != null && newName.trim().isNotEmpty)
        ? newName.trim()
        : existing.name;
    final description = newDescription?.trim();

    List<domain_we.WorkoutExercise> workoutExercises;
    if (exercisesList != null && exercisesList.isNotEmpty) {
      workoutExercises = <domain_we.WorkoutExercise>[];
      for (var i = 0; i < exercisesList.length; i++) {
        final item = exercisesList[i];
        if (item is! Map) continue;
        final map = item;
        final exerciseName = map['exerciseName']?.toString().trim();
        if (exerciseName == null || exerciseName.isEmpty) continue;

        final sets = _parseInt(map['sets'], 3);
        final minReps = map['minReps'] != null
            ? _parseInt(map['minReps'], 10)
            : (map['reps'] != null ? _parseInt(map['reps'], 10) : null);
        final maxReps = map['maxReps'] != null
            ? _parseInt(map['maxReps'], minReps ?? 10)
            : minReps;
        final isAmrap =
            map['isAmrap'] == true ||
            map['isAmrap']?.toString().toLowerCase() == 'true';
        final restSeconds = map['restSeconds'] != null
            ? _parseInt(map['restSeconds'], 90)
            : 90;
        final durationSeconds = map['durationSeconds'] != null
            ? _parseInt(map['durationSeconds'], 0)
            : null;
        final notes = map['notes']?.toString().trim();

        final exResult = await _exerciseRepo.findByNameFuzzy(exerciseName);
        if (!exResult.isSuccess) {
          return {
            'success': false,
            'error': 'Failed to lookup exercise "$exerciseName"',
          };
        }
        final exercise = exResult.getOrThrow();
        if (exercise == null) {
          return {
            'success': false,
            'error':
                'Exercise not found in catalog: "$exerciseName". '
                'Check the Catalog section for exact names.',
          };
        }

        workoutExercises.add(
          domain_we.WorkoutExercise(
            workoutId: workoutId,
            exerciseId: exercise.id,
            order: i,
            sets: sets,
            minReps: minReps,
            maxReps: maxReps,
            isAmrap: isAmrap,
            rest: restSeconds,
            duration: durationSeconds,
            groupId: null,
            notes: (notes != null && notes.isNotEmpty) ? notes : null,
          ),
        );
      }
      if (workoutExercises.isEmpty) {
        return {
          'success': false,
          'error': 'No valid exercises provided for update',
        };
      }
    } else {
      final exResult = await _workoutRepo.getExercises(workoutId);
      if (!exResult.isSuccess) {
        return {'success': false, 'error': 'Failed to load existing exercises'};
      }
      workoutExercises = exResult.getOrThrow();
    }

    final updatedWorkout = domain_workout.Workout(
      id: workoutId,
      name: name,
      description: (description != null && description.isNotEmpty)
          ? description
          : existing.description,
      createdAt: existing.createdAt,
    );

    final result = await _workoutRepo.update(updatedWorkout, workoutExercises);
    if (!result.isSuccess) {
      return {'success': false, 'error': 'Failed to update workout'};
    }
    return {
      'success': true,
      'workoutId': workoutId,
      'workoutName': name,
      'exerciseCount': workoutExercises.length,
    };
  }

  /// Merges consecutive messages from the same role into a single content
  /// entry. This prevents split UI bubbles from inflating the API turn count.
  static List<Map<String, dynamic>> _buildMergedContents(
    List<ChironMessage> history,
    String userMessage,
  ) {
    final contents = <Map<String, dynamic>>[];
    for (final msg in history) {
      final role = msg.role == ChironRole.user ? 'user' : 'model';
      if (contents.isNotEmpty && contents.last['role'] == role) {
        final parts = contents.last['parts'] as List<Map<String, dynamic>>;
        final prevText = parts.last['text'] as String;
        parts.last = {'text': '$prevText\n\n${msg.content}'};
      } else {
        contents.add({
          'role': role,
          'parts': <Map<String, dynamic>>[
            {'text': msg.content},
          ],
        });
      }
    }
    if (contents.isNotEmpty && contents.last['role'] == 'user') {
      final parts = contents.last['parts'] as List<Map<String, dynamic>>;
      final prevText = parts.last['text'] as String;
      parts.last = {'text': '$prevText\n\n$userMessage'};
    } else {
      contents.add({
        'role': 'user',
        'parts': <Map<String, dynamic>>[
          {'text': userMessage},
        ],
      });
    }
    return contents;
  }

  Future<UserProfile?> _getProfile() async {
    final result = await _profileRepo.get();
    return result.isSuccess ? result.getOrThrow() : null;
  }

  void _enforceRateLimit() {
    final now = DateTime.now();
    _timestamps.removeWhere((t) => now.difference(t).inMinutes >= 1);

    if (_timestamps.length >= _maxApiCallsPerMinute) {
      throw const ValidationException('Rate limit exceeded');
    }

    _timestamps.add(now);
  }
}
