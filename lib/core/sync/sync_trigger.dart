/// Why authenticated user-owned sync is running.
enum SyncTrigger {
  /// After sign-in / account switch (bootstrap pull).
  sessionChange,

  /// User tapped sync in Profile > Data.
  manual,

  /// Hub entry when [CloudSyncPrefs.isScheduledSyncDue].
  scheduled,

  /// After a workout execution is finished or cancelled (push session tables).
  workoutFinished,

  /// Repository-level push after profile/body metric edits (no UI invalidation).
  mutation,
}
