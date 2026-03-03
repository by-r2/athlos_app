import 'dart:async';
import 'dart:math';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/result.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../../profile/domain/enums/experience_level.dart';
import '../../../profile/domain/enums/gender.dart';
import '../../../profile/domain/repositories/user_profile_repository.dart';
import '../../../training/domain/entities/cycle_step.dart';
import '../../../training/domain/entities/workout.dart' as domain_workout;
import '../../../training/domain/entities/workout_exercise.dart' as domain_we;
import '../../../training/domain/repositories/cycle_repository.dart';
import '../../../training/domain/repositories/equipment_repository.dart';
import '../../../training/domain/repositories/exercise_repository.dart';
import '../../../training/domain/repositories/workout_repository.dart';
import '../../domain/entities/chiron_message.dart';
import '../../domain/repositories/chiron_repository.dart';
import '../helpers/prompt_builder.dart';
import '../seeds/chiron_context_seed.dart';
import '../services/gemini_models_loader.dart';
import '../services/gemini_rest_client.dart';

/// Fallback when the API list is unavailable. Use only "-latest" aliases
/// so Google can change the underlying version without app updates.
const List<String> _geminiModelIdsFallback = [
  'gemini-flash-latest',
  'gemini-1.5-flash-latest',
  'gemini-1.5-flash-8b-latest',
];
const List<Duration> _geminiRetryBackoff = [
  Duration(seconds: 1),
  Duration(seconds: 2),
];
const int _geminiRetryJitterMaxMs = 400;

class ChironRepositoryImpl implements ChironRepository {
  ChironRepositoryImpl({
    required String apiKey,
    required UserProfileRepository profileRepo,
    required EquipmentRepository equipmentRepo,
    required WorkoutRepository workoutRepo,
    required ExerciseRepository exerciseRepo,
    required CycleRepository cycleRepo,
    required PromptBuilder promptBuilder,
    GeminiModelsLoader? modelsLoader,
  })  : _profileRepo = profileRepo,
        _equipmentRepo = equipmentRepo,
        _workoutRepo = workoutRepo,
        _exerciseRepo = exerciseRepo,
        _cycleRepo = cycleRepo,
        _promptBuilder = promptBuilder,
        _modelsLoader = modelsLoader ?? GeminiModelsLoader(apiKey: apiKey),
        _restClient = GeminiRestClient(apiKey: apiKey);

  final UserProfileRepository _profileRepo;
  final GeminiRestClient _restClient;
  final EquipmentRepository _equipmentRepo;
  final WorkoutRepository _workoutRepo;
  final ExerciseRepository _exerciseRepo;
  final CycleRepository _cycleRepo;
  final PromptBuilder _promptBuilder;
  final GeminiModelsLoader _modelsLoader;

  static const _maxMessagesPerMinute = 10;
  /// Max conversation turns (user+assistant pairs) sent to the API to save tokens.
  static const int _maxHistoryTurns = 12;
  static final Random _random = Random();
  final _timestamps = <DateTime>[];

  static const _systemPrompt = r'''You are Quiron (Chiron), the Athlos AI training assistant. Persona: mentor centaur, concise and motivational.

Rules:
- Always answer in Brazilian Portuguese. Focus on training, exercises, basic nutrition, and recovery. No medical advice; recommend a professional when appropriate. Use Markdown when useful.

Missing profile fields: if gender, injuries, experienceLevel, or trainingFrequency are missing in context, ask naturally and save with the available tools. Avoid interrogation style. Bio should be enriched over time with updateBio (append only, never erase).

Gender and training: for female profiles, prioritize legs/glutes and proportional volume; for male profiles, prioritize classic splits (push/pull/legs etc.). Adapt aesthetics (athletic/bulky/robust) according to gender.

Equipment: when building workouts, use only registered equipment. If a required item is missing, ask "Do you have [X]?"; if yes, call registerEquipment and include it; if no, suggest an alternative. For injuries use updateInjuries to append new info (concatenate with "; ").

Progress: use execution history to suggest workout swaps, progression, and rest. Compare weights/reps across sessions.

Workouts — never delete: there is no delete function. You can only create (createWorkout) and archive (archiveWorkout). To replace a plan, create the new workout and then archive old ones with archiveWorkout(workoutId). Context lists active workouts with id=X; use those ids to archive.

Cycle (routine): after creating new workouts and archiving old ones, define cycle order with setCycle(steps). steps is an ordered list where each item is { type: "workout", workoutId: N } or { type: "rest" }. Include only active workoutIds (newly created or kept). Example: [ { type: "workout", workoutId: 5 }, { type: "rest" }, { type: "workout", workoutId: 6 } ]. This persists the routine and prevents outdated plans from staying active.

Final review: after all changes (create, archive, setCycle), call getTrainingState(). Compare return values (activeWorkouts and cycleSteps) with intended result. If correct, confirm to the user. If anything differs (for example: an old workout still active, outdated cycle), report what failed and suggest checking the Training module.

Available time: if context includes "Available workout time: X min", build workouts that fit this limit (estimate: sets x (reps or duration) + rest). Do not suggest workouts that exceed this time.

Two scenarios:
1) User with no active workouts: focus on creating the first plan. Use createWorkout with name and exercises (exerciseName, sets, reps, restSeconds). Then call setCycle with the created workouts. Finally call getTrainingState and confirm.
2) User with active workouts: analyze current plan, sessions, and progression. Explain whether it is better to keep, add, replace, or modify workout/cycle. If replacing, use createWorkout for the new plan, archiveWorkout for old ones, setCycle with the new order (only active workouts + rests), then getTrainingState for verification.

Function usage: use createWorkout and archiveWorkout as above; call setCycle after workout changes; call getTrainingState at the end for verification. Use updateBio, updateInjuries, updateExperienceLevel, updateGender, updateTrainingFrequency when you have concrete information; batch updates when possible. Use registerEquipment/removeEquipment when user confirms.

Adaptive context: when you need long-term trend/evolution/comparison analysis and context appears too short, call requestExtendedHistory() before replying.
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
    _enforceRateLimit();

    final maxHistoryMessages = _maxHistoryTurns * 2;
    final trimmedHistory = history.length > maxHistoryMessages
        ? history.sublist(history.length - maxHistoryMessages)
        : history;
    final shouldStartExtended = _needsExtendedContext(userMessage);
    final initialUserContext =
        await _promptBuilder.build(extended: shouldStartExtended);

    final modelIds =
        await _modelsLoader.getModelIdsForChat() ?? _geminiModelIdsFallback;
    final uniqueModelIds = modelIds.toSet().toList();

    Object? lastError;
    for (final modelId in uniqueModelIds) {
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
          final shouldRetryOnSameModel = _isRetryableError(e) &&
              attempt < _geminiRetryBackoff.length;
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

    while (true) {
      final responseJson = await _restClient.generateContent(
        modelId: modelId,
        contents: contents,
        systemInstruction: systemInstruction,
        toolDeclarations: toolDeclarations,
      );

      parse = parseGenerateContentResponse(responseJson);

      if (parse.functionCalls.isEmpty) {
        break;
      }

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
              'message': 'Extended context loaded with additional workout history.',
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
      return {'success': false, 'error': 'Workout requires at least one exercise'};
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
      final notes = map['notes']?.toString().trim();

      final exResult = await _exerciseRepo.findByName(exerciseName);
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
          'error': 'Exercise not found in catalog: "$exerciseName". '
              'Use the exact exercise name.',
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
          notes: (notes != null && notes.isNotEmpty) ? notes : null,
        ),
      );
    }

    if (workoutExercises.isEmpty) {
      return {'success': false, 'error': 'No valid exercises to create workout'};
    }

    final workout = domain_workout.Workout(
      id: 0,
      name: name.trim(),
      description: description?.trim().isEmpty ?? true ? null : description?.trim(),
      createdAt: DateTime.now(),
    );

    final result = await _workoutRepo.create(workout, workoutExercises);
    if (!result.isSuccess) {
      return {'success': false, 'error': 'Failed to save workout'};
    }

    final id = result.getOrThrow();
    final cycleResult = await _cycleRepo.appendWorkoutToCycle(id);
    if (!cycleResult.isSuccess) {
      return {
        'success': true,
        'workoutId': id,
        'workoutName': workout.name,
        'exerciseCount': workoutExercises.length,
        'warning': 'Workout created but failed to append into cycle',
      };
    }
    return {
      'success': true,
      'workoutId': id,
      'workoutName': workout.name,
      'exerciseCount': workoutExercises.length,
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
    final cycleResult = await _cycleRepo.removeWorkoutFromCycle(workoutId);
    if (!cycleResult.isSuccess) {
      return {
        'success': true,
        'workoutId': workoutId,
        'warning': 'Workout archived but failed to remove from cycle',
      };
    }
    return {'success': true, 'workoutId': workoutId};
  }

  Future<Map<String, Object?>> _handleSetCycle(List? stepsList) async {
    if (stepsList == null || stepsList.isEmpty) {
      return {'success': false, 'error': 'steps is required and cannot be empty'};
    }
    final cycleSteps = <TrainingCycleStep>[];
    for (var i = 0; i < stepsList.length; i++) {
      final item = stepsList[i];
      if (item is! Map) continue;
      final map = item;
      final typeStr = map['type']?.toString().toLowerCase();
      if (typeStr == 'rest') {
        cycleSteps.add(TrainingCycleStep(
          id: 0,
          orderIndex: i,
          type: CycleStepType.rest,
          workoutId: null,
        ));
      } else if (typeStr == 'workout') {
        final workoutId = map['workoutId'] != null
            ? (map['workoutId'] is int
                ? map['workoutId'] as int
                : int.tryParse(map['workoutId'].toString()))
            : null;
        if (workoutId == null || workoutId <= 0) continue;
        cycleSteps.add(TrainingCycleStep(
          id: 0,
          orderIndex: i,
          type: CycleStepType.workout,
          workoutId: workoutId,
        ));
      }
    }
    if (cycleSteps.isEmpty) {
      return {
        'success': false,
        'error': 'No valid steps (use type: workout with workoutId or type: rest)',
      };
    }
    final result = await _cycleRepo.setSteps(cycleSteps);
    if (!result.isSuccess) {
      return {'success': false, 'error': 'Failed to persist cycle'};
    }
    return {
      'success': true,
      'stepCount': cycleSteps.length,
    };
  }

  Future<Map<String, Object?>> _handleGetTrainingState() async {
    final activeResult = await _workoutRepo.getActive();
    if (!activeResult.isSuccess) {
      return {'success': false, 'error': 'Failed to load active workouts'};
    }
    final active = activeResult.getOrThrow();
    final stepsResult = await _cycleRepo.getSteps();
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
      if (s.type == CycleStepType.rest) {
        cycleSteps.add({'type': 'rest'});
      } else if (s.workoutId != null) {
        final w = activeById[s.workoutId];
        cycleSteps.add({
          'type': 'workout',
          'workoutId': s.workoutId,
          'workoutName': w?.name ?? 'Workout #${s.workoutId}',
        });
      }
    }
    return {
      'success': true,
      'activeWorkouts': activeWorkouts,
      'cycleSteps': cycleSteps,
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
      throw const ValidationException('Rate limit exceeded');
    }

    _timestamps.add(now);
  }
}
