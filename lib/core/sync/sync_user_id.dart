/// Shared helpers for validating a “sync user id”.
///
/// Training/profile sync uses UUID-first tables and expects a real user id
/// (auth.users.id). During onboarding / legacy migrations, some local rows may
/// have empty `user_id` values — those must never be used to build remote
/// payloads or queries.
bool isValidSyncUserId(String? userId) {
  final v = userId?.trim();
  return v != null && v.isNotEmpty;
}

