/// Push skipped because a dependency is not synced yet; retry on a later pass.
final class SyncDeferredException implements Exception {
  const SyncDeferredException(this.message);

  final String message;

  @override
  String toString() => 'SyncDeferredException: $message';
}
