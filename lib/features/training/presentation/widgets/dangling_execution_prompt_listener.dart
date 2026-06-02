import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/workout_execution.dart';
import '../helpers/workout_execution_launch.dart';
import '../providers/active_execution_notifier.dart';
import '../providers/dangling_execution_dialog_session.dart';
import '../providers/workout_execution_notifier.dart';

/// Listens for an unfinished workout and shows the resume/discard dialog.
///
/// Mount on [HubScreen] (app entry) and [TrainingShell] (any training tab).
class DanglingExecutionPromptListener extends ConsumerStatefulWidget {
  const DanglingExecutionPromptListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DanglingExecutionPromptListener> createState() =>
      _DanglingExecutionPromptListenerState();
}

class _DanglingExecutionPromptListenerState
    extends ConsumerState<DanglingExecutionPromptListener> {
  late final DanglingExecutionDialogSession _dialogSession;
  bool _didScheduleInitialCheck = false;
  Timer? _retryTimer;
  int _refreshAttempt = 0;

  @override
  void initState() {
    super.initState();
    _dialogSession = ref.read(danglingExecutionDialogSessionProvider.notifier);
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    final session = _dialogSession;
    Future.microtask(session.cancelHomePrompt);
    super.dispose();
  }

  void _deferDialogSessionUpdate(void Function() update) {
    Future.microtask(update);
  }

  void _onDanglingExecutionChanged(AsyncValue<WorkoutExecution?> next) {
    if (!mounted) return;
    // Never prompt while an in-memory execution is active (starting a workout
    // creates an unfinished DB row, which would otherwise look "dangling").
    if (ref.read(activeExecutionProvider) != null) return;
    next.when(
      data: (execution) {
        if (execution == null) {
          _deferDialogSessionUpdate(_dialogSession.clear);
          return;
        }
        if (!_dialogSession.shouldShowHomePrompt(execution.id)) {
          return;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          showDanglingExecutionHomeDialogIfNeeded(context, ref, execution);
        });
      },
      loading: () {},
      error: (_, _) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final danglingAsync = ref.watch(danglingExecutionProvider);

    if (!_didScheduleInitialCheck) {
      _didScheduleInitialCheck = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        try {
          final execution = await ref.read(danglingExecutionProvider.future);
          if (!mounted) return;
          _onDanglingExecutionChanged(AsyncValue.data(execution));
        } on Exception catch (e, st) {
          if (!mounted) return;
          _onDanglingExecutionChanged(AsyncValue.error(e, st));
        }
      });

      // Defensive: some boot sequences may resolve `danglingExecution` to null
      // before the local DB/user session is fully ready. Retry a few times so
      // the dialog appears without requiring a manual invalidation elsewhere.
      _scheduleRetryRefreshes();
    }

    ref.listen(danglingExecutionProvider, (prev, next) {
      if (prev?.isLoading == true && next.hasValue) {
        _onDanglingExecutionChanged(next);
        return;
      }
      if (prev?.value?.id != next.value?.id ||
          prev?.hasValue != next.hasValue) {
        _onDanglingExecutionChanged(next);
      }
    });

    // Keep dependency on async state so rebuilds track loading → data.
    danglingAsync.whenOrNull();

    return widget.child;
  }

  void _scheduleRetryRefreshes() {
    const delays = <Duration>[
      Duration(milliseconds: 250),
      Duration(milliseconds: 750),
      Duration(seconds: 2),
      Duration(seconds: 4),
    ];
    if (_refreshAttempt >= delays.length) return;

    _retryTimer?.cancel();
    final delay = delays[_refreshAttempt];
    _retryTimer = Timer(delay, () async {
      if (!mounted) return;
      _refreshAttempt++;
      try {
        await refreshDanglingExecution(ref);
      } catch (e, st) {
        debugPrint('[DanglingExecution] listener: retry refresh failed: $e\n$st');
      }

      // If still no value, schedule next retry.
      if (!mounted) return;
      final current = ref.read(danglingExecutionProvider);
      final hasDangling = current is AsyncData && current.value != null;
      if (!hasDangling) _scheduleRetryRefreshes();
    });
  }
}
