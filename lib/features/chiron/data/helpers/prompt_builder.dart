import '../../../../core/errors/result.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../../profile/domain/repositories/user_profile_repository.dart';
import '../../../training/domain/entities/equipment.dart';
import '../../../training/domain/entities/exercise.dart';
import '../../../training/domain/entities/workout.dart';
import '../../../training/domain/entities/workout_execution.dart';
import '../../../training/domain/repositories/equipment_repository.dart';
import '../../../training/domain/repositories/exercise_repository.dart';
import '../../../training/domain/repositories/workout_execution_repository.dart';
import '../../../training/domain/repositories/workout_repository.dart';
import '../seeds/chiron_context_seed.dart';

/// Builds a structured context string from user data for the Gemini prompt.
/// Limits list sizes to keep context token-efficient while staying useful.
class PromptBuilder {
  static const int maxRecentExecutions = chironDefaultRecentExecutionsLimit;
  static const int maxRecentExecutionsExtended =
      chironExtendedRecentExecutionsLimit;
  static const int maxWorkouts = chironDefaultWorkoutsLimit;
  static const int maxWorkoutsExtended = chironExtendedWorkoutsLimit;
  static const int maxExerciseNamesInContext = 100;

  final UserProfileRepository _profileRepo;
  final EquipmentRepository _equipmentRepo;
  final WorkoutRepository _workoutRepo;
  final WorkoutExecutionRepository _executionRepo;
  final ExerciseRepository _exerciseRepo;

  const PromptBuilder({
    required UserProfileRepository profileRepo,
    required EquipmentRepository equipmentRepo,
    required WorkoutRepository workoutRepo,
    required WorkoutExecutionRepository executionRepo,
    required ExerciseRepository exerciseRepo,
  })  : _profileRepo = profileRepo,
        _equipmentRepo = equipmentRepo,
        _workoutRepo = workoutRepo,
        _executionRepo = executionRepo,
        _exerciseRepo = exerciseRepo;

  Future<String> build({bool extended = false}) async {
    final recentExecutionsLimit =
        extended ? maxRecentExecutionsExtended : maxRecentExecutions;
    final workoutsLimit = extended ? maxWorkoutsExtended : maxWorkouts;

    // Parallel fetch of all independent data sources
    final futures = await Future.wait([
      _profileRepo.get(),
      _equipmentRepo.getByUser(),
      _workoutRepo.getActive(),
      _executionRepo.getAll(),
      _exerciseRepo.getAll(),
    ]);

    final profileResult = futures[0] as Result<UserProfile?>;
    final equipResult = futures[1] as Result<List<Equipment>>;
    final workoutResult = futures[2] as Result<List<Workout>>;
    final execResult = futures[3] as Result<List<WorkoutExecution>>;
    final exerciseResult = futures[4] as Result<List<Exercise>>;

    // Pre-build exercise ID → name map (avoids N+1 later)
    final exerciseMap = <int, String>{};
    var allExercises = <Exercise>[];
    if (exerciseResult.isSuccess) {
      allExercises = exerciseResult.getOrThrow();
      for (final ex in allExercises) {
        exerciseMap[ex.id] = ex.name;
      }
    }

    final sections = <String>[];

    // --- Profile ---
    _buildProfile(profileResult, sections);

    // --- Equipment ---
    _buildEquipment(equipResult, sections);

    // --- Active Workouts (with exercises, no N+1) ---
    await _buildWorkouts(
      workoutResult,
      exerciseMap,
      sections,
      maxItems: workoutsLimit,
    );

    // --- Recent Executions (with set details, no N+1) ---
    await _buildExecutions(
      execResult,
      workoutResult,
      exerciseMap,
      sections,
      maxItems: recentExecutionsLimit,
    );

    // --- Exercise catalog names ---
    _buildCatalog(allExercises, sections);

    return sections.isEmpty
        ? 'No data available yet.'
        : sections.join('\n\n');
  }

  void _buildProfile(
    Result<UserProfile?> profileResult,
    List<String> sections,
  ) {
    if (!profileResult.isSuccess) return;
    final profile = profileResult.getOrThrow();
    if (profile == null) return;

    final lines = <String>['## User Profile'];
    if (profile.name != null) lines.add('- Name: ${profile.name}');
    if (profile.age != null) lines.add('- Age: ${profile.age} years');
    if (profile.weight != null) lines.add('- Weight: ${profile.weight} kg');
    if (profile.height != null) lines.add('- Height: ${profile.height} cm');
    if (profile.goal != null) {
      lines.add('- Goal: ${_humanize(profile.goal!.name)}');
    }
    if (profile.bodyAesthetic != null) {
      lines.add('- Body aesthetic: ${_humanize(profile.bodyAesthetic!.name)}');
    }
    if (profile.trainingStyle != null) {
      lines.add('- Training style: ${_humanize(profile.trainingStyle!.name)}');
    }
    if (profile.experienceLevel != null) {
      lines.add(
          '- Experience level: ${_humanize(profile.experienceLevel!.name)}');
    }
    if (profile.gender != null) {
      lines.add('- Gender: ${_humanize(profile.gender!.name)}');
    }
    if (profile.trainingFrequency != null) {
      lines.add('- Frequency: ${profile.trainingFrequency}x per week');
    }
    if (profile.availableWorkoutMinutes != null) {
      lines.add(
          '- Available workout time: ${profile.availableWorkoutMinutes} min');
    }
    if (profile.trainsAtGym != null) {
      lines.add('- Trains at gym: ${profile.trainsAtGym! ? "Yes" : "No"}');
    }
    if (profile.injuries != null && profile.injuries!.isNotEmpty) {
      lines.add('- Injuries/limitations: ${profile.injuries}');
    }
    if (profile.bio != null && profile.bio!.isNotEmpty) {
      lines.add('- History: ${profile.bio}');
    }
    sections.add(lines.join('\n'));
  }

  void _buildEquipment(
    Result<List<Equipment>> equipResult,
    List<String> sections,
  ) {
    if (!equipResult.isSuccess) return;
    final equipment = equipResult.getOrThrow();
    if (equipment.isNotEmpty) {
      final names = equipment.map((e) => e.name).join(', ');
      sections.add('## Registered Equipment\n$names');
    } else {
      sections.add('## Registered Equipment\nNo equipment registered.');
    }
  }

  Future<void> _buildWorkouts(
    Result<List<Workout>> workoutResult,
    Map<int, String> exerciseMap,
    List<String> sections,
    {required int maxItems}
  ) async {
    if (!workoutResult.isSuccess) return;
    final workouts = workoutResult.getOrThrow();
    final workoutsToShow = workouts.take(maxItems).toList();
    if (workoutsToShow.isEmpty) return;

    // Fetch exercises for all workouts in parallel
    final exerciseResults = await Future.wait(
      workoutsToShow.map((w) => _workoutRepo.getExercises(w.id)),
    );

    final lines = <String>['## Active Workouts'];
    for (var i = 0; i < workoutsToShow.length; i++) {
      final w = workoutsToShow[i];
      final age = DateTime.now().difference(w.createdAt).inDays;
      final exNames = <String>[];
      final exResult = exerciseResults[i];
      if (exResult.isSuccess) {
        for (final we in exResult.getOrThrow()) {
          final name = exerciseMap[we.exerciseId];
          if (name != null) exNames.add(name);
        }
      }
      final exStr = exNames.isNotEmpty ? ' → ${exNames.join(", ")}' : '';
      lines.add('- id=${w.id} ${w.name} (${age}d, '
          '${exNames.length} ex)$exStr');
    }
    sections.add(lines.join('\n'));
  }

  Future<void> _buildExecutions(
    Result<List<WorkoutExecution>> execResult,
    Result<List<Workout>> workoutResult,
    Map<int, String> exerciseMap,
    List<String> sections,
    {required int maxItems}
  ) async {
    if (!execResult.isSuccess) return;
    final executions = execResult.getOrThrow();
    final recent = executions
        .where((e) => e.isFinished)
        .take(maxItems)
        .toList();
    if (recent.isEmpty) return;

    // Reuse workout names from the already-fetched workouts result
    final workoutNames = <int, String>{};
    if (workoutResult.isSuccess) {
      for (final w in workoutResult.getOrThrow()) {
        workoutNames[w.id] = w.name;
      }
    }

    // Fetch all sets in parallel
    final setResults = await Future.wait(
      recent.map((exec) => _executionRepo.getSets(exec.id)),
    );

    final lines = <String>['## Recent History (${recent.length} sessions)'];
    for (var i = 0; i < recent.length; i++) {
      final exec = recent[i];
      final duration = exec.duration != null
          ? _formatDuration(exec.duration!)
          : '?';
      final wName = workoutNames[exec.workoutId] ?? 'Workout #${exec.workoutId}';
      final dateFmt =
          exec.startedAt.toLocal().toString().substring(0, 10);

      final setsResult = setResults[i];
      if (setsResult.isSuccess) {
        final sets = setsResult.getOrThrow();
        final exerciseGroups = <int, List<String>>{};
        for (final s in sets.where((s) => s.isCompleted)) {
          final label = s.weight != null
              ? '${s.weight}kg×${s.reps ?? 0}'
              : s.duration != null
                  ? '${s.duration}s'
                  : '${s.reps ?? 0} reps';
          exerciseGroups
              .putIfAbsent(s.exerciseId, () => [])
              .add(label);
        }
        final summary = exerciseGroups.entries.map((e) {
          final exName = exerciseMap[e.key] ?? 'ex#${e.key}';
          return '$exName: ${e.value.join(", ")}';
        }).join(' | ');
        lines.add('- $dateFmt $wName ($duration) [$summary]');
      } else {
        lines.add('- $dateFmt $wName ($duration)');
      }
    }
    sections.add(lines.join('\n'));
  }

  void _buildCatalog(List<Exercise> allExercises, List<String> sections) {
    if (allExercises.isEmpty) return;
    final names = allExercises.map((e) => e.name).toList();
    final shown = names.take(maxExerciseNamesInContext).toList();
    final overflow = names.length > maxExerciseNamesInContext
        ? ' (+${names.length - maxExerciseNamesInContext})'
        : '';
    sections.add(
      '## Catalog (${names.length} exercises)\n'
      'Exact names for createWorkout: ${shown.join(", ")}$overflow',
    );
  }

  String _humanize(String enumName) =>
      enumName.replaceAllMapped(RegExp(r'[A-Z]'), (m) => ' ${m[0]}').trim();

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h${m > 0 ? ' ${m}min' : ''}';
    return '${m}min';
  }
}
