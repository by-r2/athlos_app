/// Snapshot of async entry preconditions shared by GoRouter and [SplashScreen].
class AppEntryGate {
  const AppEntryGate({
    required this.isAuthLoading,
    required this.isProfileLoading,
    required this.isSessionBootstrapping,
    required this.hasAuthUser,
    required this.hasProfile,
  });

  final bool isAuthLoading;
  final bool isProfileLoading;
  final bool isSessionBootstrapping;
  final bool hasAuthUser;
  final bool hasProfile;

  /// Whether the splash should keep showing a loading indicator.
  bool get blocksSplash =>
      isAuthLoading || isProfileLoading || isSessionBootstrapping;
}

AppEntryGate computeAppEntryGate({
  required bool isAuthLoading,
  required bool hasAuthUser,
  required bool isProfileAsyncLoading,
  required bool hasProfileValue,
  required bool isSessionBootstrapComplete,
}) {
  final isSessionBootstrapping = hasAuthUser && !isSessionBootstrapComplete;
  final isProfileLoading = hasAuthUser && isProfileAsyncLoading;
  final hasProfile = !isSessionBootstrapping && hasProfileValue;

  return AppEntryGate(
    isAuthLoading: isAuthLoading,
    isProfileLoading: isProfileLoading,
    isSessionBootstrapping: isSessionBootstrapping,
    hasAuthUser: hasAuthUser,
    hasProfile: hasProfile,
  );
}
