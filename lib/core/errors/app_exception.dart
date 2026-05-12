/// Sealed hierarchy of typed application exceptions.
///
/// Used inside [Result.failure] to provide specific error context
/// across all layers. New subtypes can be added as needs grow
/// (e.g. `NetworkException` in V2).
sealed class AppException implements Exception {
  final String message;

  const AppException(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

/// A database operation failed (insert, query, migration, etc.).
final class DatabaseException extends AppException {
  const DatabaseException(super.message);
}

/// The requested entity was not found.
final class NotFoundException extends AppException {
  const NotFoundException(super.message);
}

/// Input data failed validation rules.
final class ValidationException extends AppException {
  final Map<String, String>? fieldErrors;

  const ValidationException(super.message, {this.fieldErrors});
}

/// The operation conflicts with existing data (e.g. duplicate name).
final class ConflictException extends AppException {
  const ConflictException(super.message);
}

/// Authentication or authorization failed.
final class AuthAppException extends AppException {
  const AuthAppException(super.message);
}

/// A remote network/API operation failed.
final class NetworkException extends AppException {
  const NetworkException(super.message);
}
