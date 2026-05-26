import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/training/presentation/providers/active_execution_notifier.dart';
import '../../features/training/presentation/providers/workout_execution_notifier.dart';

part 'workout_sync_guard.g.dart';

/// Whether a full cloud sync must be deferred (active or dangling workout).
@riverpod
bool isWorkoutSessionBlockingCloudSync(Ref ref) {
  if (ref.watch(activeExecutionProvider) != null) return true;

  final dangling = ref.watch(danglingExecutionProvider);
  return switch (dangling) {
    AsyncData(:final value) => value != null,
    _ => false,
  };
}
