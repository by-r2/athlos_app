import 'app_exception.dart';

/// Represents the outcome of an operation that can fail.
///
/// Repositories and Use Cases return [Result] instead of throwing.
/// Controllers unwrap it into [AsyncValue] at the presentation boundary.
///
/// ```dart
/// final result = await repository.getAll();
/// switch (result) {
///   case Success(:final value): // use value
///   case Failure(:final exception): // handle error
/// }
/// ```
sealed class Result<T> {
  const Result();
}

/// The operation completed successfully with [value].
final class Success<T> extends Result<T> {
  final T value;

  const Success(this.value);
}

/// The operation failed with a typed [exception].
final class Failure<T> extends Result<T> {
  final AppException exception;

  const Failure(this.exception);
}

/// Convenience extensions for working with [Result].
extension ResultX<T> on Result<T> {
  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  /// Unwraps the value or throws the exception.
  ///
  /// Useful in controllers to convert [Result] into [AsyncValue]:
  /// ```dart
  /// state = AsyncData(result.getOrThrow());
  /// ```
  T getOrThrow() => switch (this) {
    Success(:final value) => value,
    Failure(:final exception) => throw exception,
  };
}
