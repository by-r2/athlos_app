import '../../../../core/errors/result.dart';
import '../../../profile/domain/repositories/user_profile_repository.dart';
import '../../../training/domain/repositories/equipment_repository.dart';
import '../../../training/domain/repositories/exercise_repository.dart';
import '../../../training/domain/repositories/workout_execution_repository.dart';
import '../../../training/domain/repositories/workout_repository.dart';

/// Builds a structured context string from user data for the Gemini prompt.
class PromptBuilder {
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
        sections.add(lines.join('\n'));
      }
    }

    // Equipment
    final equipResult = await _equipmentRepo.getByUser();
    if (equipResult.isSuccess) {
      final equipment = equipResult.getOrThrow();
      if (equipment.isNotEmpty) {
        final names = equipment.map((e) => e.name).join(', ');
        sections.add('## Equipamentos Disponíveis\n$names');
      }
    }

    // Workouts
    final workoutResult = await _workoutRepo.getActive();
    if (workoutResult.isSuccess) {
      final workouts = workoutResult.getOrThrow();
      if (workouts.isNotEmpty) {
        final lines = <String>['## Treinos Ativos'];
        for (final w in workouts) {
          final exercisesResult = await _workoutRepo.getExercises(w.id);
          final exerciseCount = exercisesResult.isSuccess
              ? exercisesResult.getOrThrow().length
              : 0;
          lines.add('- ${w.name} ($exerciseCount exercícios)');
        }
        sections.add(lines.join('\n'));
      }
    }

    // Recent executions
    final execResult = await _executionRepo.getAll();
    if (execResult.isSuccess) {
      final executions = execResult.getOrThrow();
      final recent = executions.where((e) => e.isFinished).take(5).toList();
      if (recent.isNotEmpty) {
        final lines = <String>['## Histórico Recente (últimas 5 sessões)'];
        for (final exec in recent) {
          final duration = exec.duration != null
              ? _formatDuration(exec.duration!)
              : 'em andamento';
          lines.add(
            '- ${exec.startedAt.toLocal().toString().substring(0, 10)} '
            '| Duração: $duration',
          );
        }
        sections.add(lines.join('\n'));
      }
    }

    // Exercise catalog size
    final exerciseResult = await _exerciseRepo.getAll();
    if (exerciseResult.isSuccess) {
      final exercises = exerciseResult.getOrThrow();
      sections.add('## Catálogo\n- ${exercises.length} exercícios disponíveis');
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
