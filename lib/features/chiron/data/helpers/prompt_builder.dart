import '../../../../core/errors/result.dart';
import '../../../profile/domain/repositories/user_profile_repository.dart';
import '../../../training/domain/repositories/equipment_repository.dart';
import '../../../training/domain/repositories/exercise_repository.dart';
import '../../../training/domain/repositories/workout_execution_repository.dart';
import '../../../training/domain/repositories/workout_repository.dart';

/// Builds a structured context string from user data for the Gemini prompt.
/// Limits list sizes to keep context token-efficient while staying useful.
class PromptBuilder {
  /// Max recent executions to include (keeps progress analysis effective).
  static const int maxRecentExecutions = 25;
  /// Max workouts to include in context.
  static const int maxWorkouts = 25;
  /// Max exercise names to list in catalog snippet (rest is "... and N more").
  static const int maxExerciseNamesInContext = 80;

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

  Future<String> build() async {
    final sections = <String>[];

    // User profile
    final profileResult = await _profileRepo.get();
    if (profileResult.isSuccess) {
      final profile = profileResult.getOrThrow();
      if (profile != null) {
        final lines = <String>['## Perfil do Utilizador'];
        if (profile.name != null) lines.add('- Nome: ${profile.name}');
        if (profile.age != null) lines.add('- Idade: ${profile.age} anos');
        if (profile.weight != null) lines.add('- Peso: ${profile.weight} kg');
        if (profile.height != null) {
          lines.add('- Altura: ${profile.height} cm');
        }
        if (profile.goal != null) {
          lines.add('- Objetivo: ${_humanize(profile.goal!.name)}');
        }
        if (profile.bodyAesthetic != null) {
          lines.add(
              '- Estética corporal: ${_humanize(profile.bodyAesthetic!.name)}');
        }
        if (profile.trainingStyle != null) {
          lines.add(
              '- Estilo de treino: ${_humanize(profile.trainingStyle!.name)}');
        }
        if (profile.experienceLevel != null) {
          lines.add(
              '- Nível de experiência: ${_humanize(profile.experienceLevel!.name)}');
        }
        if (profile.gender != null) {
          lines.add('- Gênero: ${_humanize(profile.gender!.name)}');
        }
        if (profile.trainingFrequency != null) {
          lines.add(
              '- Frequência: ${profile.trainingFrequency}x por semana');
        }
        if (profile.trainsAtGym != null) {
          lines.add(
              '- Treina em academia: ${profile.trainsAtGym! ? "Sim" : "Não"}');
        }
        if (profile.injuries != null && profile.injuries!.isNotEmpty) {
          lines.add('- Lesões/limitações: ${profile.injuries}');
        }
        if (profile.bio != null && profile.bio!.isNotEmpty) {
          lines.add('- Histórico: ${profile.bio}');
        }
        sections.add(lines.join('\n'));
      }
    }

    // Equipment
    final equipResult = await _equipmentRepo.getByUser();
    if (equipResult.isSuccess) {
      final equipment = equipResult.getOrThrow();
      if (equipment.isNotEmpty) {
        final names = equipment.map((e) => e.name).join(', ');
        sections.add('## Equipamentos Registados\n$names');
      } else {
        sections.add('## Equipamentos Registados\nNenhum equipamento registado.');
      }
    }

    // Workouts with exercises and creation date (capped for token efficiency)
    final workoutResult = await _workoutRepo.getActive();
    if (workoutResult.isSuccess) {
      final workouts = workoutResult.getOrThrow();
      final workoutsToShow = workouts.take(maxWorkouts).toList();
      if (workoutsToShow.isNotEmpty) {
        final lines = <String>['## Treinos Ativos'];
        for (final w in workoutsToShow) {
          final age = DateTime.now().difference(w.createdAt).inDays;
          final exercisesResult = await _workoutRepo.getExercises(w.id);
          final exerciseNames = <String>[];
          if (exercisesResult.isSuccess) {
            for (final we in exercisesResult.getOrThrow()) {
              final exResult = await _exerciseRepo.getById(we.exerciseId);
              if (exResult.isSuccess) {
                final ex = exResult.getOrThrow();
                if (ex != null) exerciseNames.add(ex.name);
              }
            }
          }
          final exStr = exerciseNames.isNotEmpty
              ? ' → ${exerciseNames.join(", ")}'
              : '';
          lines.add('- ${w.name} (criado há $age dias, '
              '${exerciseNames.length} exercícios)$exStr');
        }
        sections.add(lines.join('\n'));
      }
    }

    // Recent executions with set details (capped for token efficiency)
    final execResult = await _executionRepo.getAll();
    if (execResult.isSuccess) {
      final executions = execResult.getOrThrow();
      final recent = executions
          .where((e) => e.isFinished)
          .take(maxRecentExecutions)
          .toList();
      if (recent.isNotEmpty) {
        final lines = <String>['## Histórico Recente (últimas ${recent.length} sessões)'];

        // Map workout IDs to names
        final workoutNames = <int, String>{};
        final workoutResult2 = await _workoutRepo.getActive();
        if (workoutResult2.isSuccess) {
          for (final w in workoutResult2.getOrThrow()) {
            workoutNames[w.id] = w.name;
          }
        }

        for (final exec in recent) {
          final duration = exec.duration != null
              ? _formatDuration(exec.duration!)
              : '?';
          final wName = workoutNames[exec.workoutId] ?? 'Treino #${exec.workoutId}';
          final dateFmt = exec.startedAt.toLocal().toString().substring(0, 10);

          final setsResult = await _executionRepo.getSets(exec.id);
          if (setsResult.isSuccess) {
            final sets = setsResult.getOrThrow();
            final exerciseGroups = <int, List<String>>{};
            for (final s in sets.where((s) => s.isCompleted)) {
              final label = s.weight != null
                  ? '${s.weight}kg×${s.reps ?? 0}'
                  : s.duration != null
                      ? '${s.duration}s'
                      : '${s.reps ?? 0} reps';
              exerciseGroups.putIfAbsent(s.exerciseId, () => []).add(label);
            }
            final summary = exerciseGroups.entries.map((e) {
              return 'ex#${e.key}: ${e.value.join(", ")}';
            }).join(' | ');
            lines.add('- $dateFmt — $wName ($duration) [$summary]');
          } else {
            lines.add('- $dateFmt — $wName ($duration)');
          }
        }
        sections.add(lines.join('\n'));
      }
    }

    // Exercise catalog: names for createWorkout (capped to limit tokens)
    final exerciseResult = await _exerciseRepo.getAll();
    if (exerciseResult.isSuccess) {
      final exercises = exerciseResult.getOrThrow();
      final names = exercises.map((e) => e.name).toList();
      final shown = names.take(maxExerciseNamesInContext).toList();
      sections.add(
        '## Catálogo (${names.length} exercícios)\n'
        'Nomes exatos para createWorkout: ${shown.join(", ")}'
        '${names.length > maxExerciseNamesInContext ? " (e mais ${names.length - maxExerciseNamesInContext})" : ""}',
      );
    }

    return sections.isEmpty
        ? 'Nenhum dado disponível ainda.'
        : sections.join('\n\n');
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
