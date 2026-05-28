import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dangling_execution_dialog_session.g.dart';

/// Tracks home-tab resume/discard prompt state across tab switches.
///
/// Avoids duplicate dialogs while a prompt is open and remembers which
/// execution the user already resolved until it is cleared from the DB.
@Riverpod(keepAlive: true)
class DanglingExecutionDialogSession extends _$DanglingExecutionDialogSession {
  @override
  DanglingExecutionDialogSessionState build() =>
      const DanglingExecutionDialogSessionState();

  bool shouldShowHomePrompt(String executionId) =>
      state.resolvedExecutionId != executionId &&
      state.openPromptExecutionId != executionId;

  /// Atomically claims the prompt for [executionId]. Returns false if already
  /// showing or resolved.
  bool tryBeginHomePrompt(String executionId) {
    if (!shouldShowHomePrompt(executionId)) return false;
    state = state.copyWith(openPromptExecutionId: executionId);
    return true;
  }

  void beginHomePrompt(String executionId) {
    state = state.copyWith(openPromptExecutionId: executionId);
  }

  void completeHomePrompt(String executionId) {
    state = state.copyWith(
      resolvedExecutionId: executionId,
      openPromptExecutionId: null,
    );
  }

  void cancelHomePrompt() {
    state = state.copyWith(openPromptExecutionId: null);
  }

  void clear() {
    state = const DanglingExecutionDialogSessionState();
  }
}

class DanglingExecutionDialogSessionState {
  const DanglingExecutionDialogSessionState({
    this.resolvedExecutionId,
    this.openPromptExecutionId,
  });

  final String? resolvedExecutionId;
  final String? openPromptExecutionId;

  DanglingExecutionDialogSessionState copyWith({
    String? resolvedExecutionId,
    String? openPromptExecutionId,
    bool clearOpenPrompt = false,
    bool clearResolved = false,
  }) => DanglingExecutionDialogSessionState(
    resolvedExecutionId: clearResolved
        ? null
        : (resolvedExecutionId ?? this.resolvedExecutionId),
    openPromptExecutionId: clearOpenPrompt
        ? null
        : (openPromptExecutionId ?? this.openPromptExecutionId),
  );
}
