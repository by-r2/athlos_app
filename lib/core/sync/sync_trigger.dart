/// Why authenticated user-owned sync is running.
enum SyncTrigger {
  sessionChange,
  resume,
  mutation,
  connectivity,
}
