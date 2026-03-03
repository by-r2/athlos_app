import '../entities/chiron_message.dart';

/// Callback when a tool is invoked during a response. [resultData] contains
/// the tool return (e.g. workoutId for createWorkout).
typedef ChironToolInvokedCallback = void Function(
  String toolName,
  bool success,
  Map<String, dynamic>? resultData,
);

/// Repository for the Chiron AI assistant.
///
/// Unlike request/response repositories that return `Result<T>`,
/// [sendMessage] uses a streaming contract: text chunks are yielded via
/// the stream, and errors propagate as stream errors (caught by
/// `try/catch` around `await for` in the presentation layer). This is
/// the idiomatic Dart pattern for streaming APIs and is functionally
/// equivalent to `Result.failure()` for one-shot operations.
abstract interface class ChironRepository {
  /// Sends [userMessage] to the AI model, yielding text chunks as they arrive.
  ///
  /// Throws [AppException] subtypes through the stream on failure
  /// (e.g. [ValidationException] for rate limiting, or API-specific exceptions
  /// for transient/network errors).
  Stream<String> sendMessage({
    required String userMessage,
    required List<ChironMessage> history,
    ChironToolInvokedCallback? onToolInvoked,
  });
}
