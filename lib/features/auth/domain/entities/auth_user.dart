/// Authenticated app user.
class AuthUser {
  final String id;
  final String? email;
  final String? displayName;

  const AuthUser({required this.id, this.email, this.displayName});
}
