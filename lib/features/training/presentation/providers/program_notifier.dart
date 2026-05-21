import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/errors/result.dart';
import '../../data/repositories/training_providers.dart';
import '../../domain/entities/training_program.dart';
import '../../domain/enums/duration_mode.dart';
import 'training_analytics_provider.dart';

part 'program_notifier.g.dart';

/// The currently active program. Should always exist after migration v25.
/// Returns null only transiently during first startup before the default
/// program is created.
@riverpod
Future<TrainingProgram?> activeProgram(Ref ref) async {
  final repo = ref.watch(programRepositoryProvider);
  final result = await repo.getActive();
  return result.getOrThrow();
}

/// All programs (active + archived), newest first.
@riverpod
Future<List<TrainingProgram>> programList(Ref ref) async {
  final repo = ref.watch(programRepositoryProvider);
  final result = await repo.getAll();
  return result.getOrThrow();
}

/// Number of finished sessions for a given program.
@riverpod
Future<int> programSessionCount(Ref ref, String programId) async {
  final repo = ref.watch(programRepositoryProvider);
  final result = await repo.getSessionCount(programId);
  return result.getOrThrow();
}

/// Program progress info: current sessions done vs total planned.
class ProgramProgressInfo {
  final int completedSessions;
  final int totalSessions;

  const ProgramProgressInfo({
    required this.completedSessions,
    required this.totalSessions,
  });

  double get fraction => totalSessions > 0
      ? (completedSessions / totalSessions).clamp(0.0, 1.0)
      : 0;

  bool get isCompleted => completedSessions >= totalSessions;
}

@riverpod
Future<ProgramProgressInfo> programProgress(Ref ref, String programId) async {
  final programs = await ref.watch(programListProvider.future);
  final program = programs.where((p) => p.id == programId).firstOrNull;
  if (program == null) {
    return const ProgramProgressInfo(completedSessions: 0, totalSessions: 1);
  }

  final sessionCount = await ref.watch(
    programSessionCountProvider(programId).future,
  );

  int totalSessions;
  if (program.durationMode == DurationMode.rotations) {
    final steps = await ref.watch(
      cycleStepsForProgramProvider(programId).future,
    );
    totalSessions = steps.isEmpty
        ? program.durationValue
        : program.durationValue * steps.length;
  } else {
    totalSessions = program.durationValue;
  }

  return ProgramProgressInfo(
    completedSessions: sessionCount,
    totalSessions: totalSessions,
  );
}

/// Whether the active program should trigger a deload prompt.
/// Returns true when deload frequency is set and the current rotation count
/// is a multiple of that frequency, and the program is not already in deload.
@riverpod
Future<bool> isDeloadDue(Ref ref) async {
  final repo = ref.watch(programRepositoryProvider);
  final program = (await repo.getActive()).getOrThrow();
  if (program == null || program.isInDeload) return false;
  final config = program.deloadConfig;
  if (config == null || config.frequency == null) return false;

  final steps = await ref.watch(
    cycleStepsForProgramProvider(program.id).future,
  );
  if (steps.isEmpty) return false;

  final sessionCount = await ref.watch(
    programSessionCountProvider(program.id).future,
  );
  final completedRotations = sessionCount ~/ steps.length;

  return completedRotations > 0 && completedRotations % config.frequency! == 0;
}

/// Notifier for program mutations (create, update, activate, archive).
@riverpod
class ProgramActions extends _$ProgramActions {
  @override
  FutureOr<void> build() {}

  Future<String> createProgram(TrainingProgram program) async {
    final repo = ref.read(programRepositoryProvider);
    final result = await repo.create(program);
    return result.getOrThrow();
  }

  Future<void> updateProgram(TrainingProgram program) async {
    final repo = ref.read(programRepositoryProvider);
    final result = await repo.update(program);
    result.getOrThrow();
  }

  Future<void> activateProgram(String programId) async {
    final repo = ref.read(programRepositoryProvider);
    final result = await repo.activate(programId);
    result.getOrThrow();
  }

  Future<void> archiveProgram(String programId) async {
    final repo = ref.read(programRepositoryProvider);
    final result = await repo.archive(programId);
    result.getOrThrow();
  }

  Future<void> deleteProgram(String programId) async {
    final repo = ref.read(programRepositoryProvider);
    final result = await repo.delete(programId);
    result.getOrThrow();
  }

  Future<void> enterDeload(String programId) async {
    final repo = ref.read(programRepositoryProvider);
    final result = await repo.setDeloadActive(programId, active: true);
    result.getOrThrow();
  }

  Future<void> exitDeload(String programId) async {
    final repo = ref.read(programRepositoryProvider);
    final result = await repo.setDeloadActive(programId, active: false);
    result.getOrThrow();
  }
}
