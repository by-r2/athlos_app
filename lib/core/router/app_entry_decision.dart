import 'route_paths.dart';

String? resolveAppEntryRedirect({
  required String location,
  required bool isAuthLoading,
  required bool isProfileLoading,
  required bool hasAuthUser,
  required bool hasProfile,
}) {
  final isOnSplash = location == RoutePaths.splash;
  final isOnSetup = location == RoutePaths.profileSetup;
  final isOnAuthPrompt = location == RoutePaths.authPrompt;
  final isOnAuthEmail =
      location == RoutePaths.authSignIn || location == RoutePaths.authSignUp;
  final isOnAuthRoute = isOnAuthPrompt || isOnAuthEmail;

  if (isAuthLoading || isProfileLoading) {
    return isOnSplash || isOnAuthRoute ? null : RoutePaths.splash;
  }

  if (isOnSplash) {
    if (!hasAuthUser) return RoutePaths.authPrompt;
    return hasProfile ? RoutePaths.hub : RoutePaths.profileSetup;
  }

  if (!hasAuthUser && !isOnAuthRoute) return RoutePaths.authPrompt;

  if (hasAuthUser && isOnAuthRoute) {
    return hasProfile ? RoutePaths.hub : RoutePaths.profileSetup;
  }

  if (!hasProfile && !isOnSetup && !isOnAuthRoute) {
    return RoutePaths.profileSetup;
  }

  if (hasProfile && isOnSetup) return RoutePaths.hub;

  return null;
}
