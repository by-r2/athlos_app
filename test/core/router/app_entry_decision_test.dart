import 'package:athlos_app/core/router/app_entry_decision.dart';
import 'package:athlos_app/core/router/route_paths.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveAppEntryRedirect', () {
    test('mantem splash durante bootstrap pos-login', () {
      final redirect = resolveAppEntryRedirect(
        location: RoutePaths.splash,
        isAuthLoading: false,
        isProfileLoading: false,
        isSessionBootstrapping: true,
        hasAuthUser: true,
        hasProfile: false,
      );

      expect(redirect, isNull);
    });

    test('redireciona para splash durante bootstrap fora do splash', () {
      final redirect = resolveAppEntryRedirect(
        location: RoutePaths.authSignIn,
        isAuthLoading: false,
        isProfileLoading: false,
        isSessionBootstrapping: true,
        hasAuthUser: true,
        hasProfile: false,
      );

      expect(redirect, RoutePaths.splash);
    });

    test('mantem rotas de auth durante loading de auth', () {
      final redirect = resolveAppEntryRedirect(
        location: RoutePaths.authSignIn,
        isAuthLoading: true,
        isProfileLoading: false,
        isSessionBootstrapping: false,
        hasAuthUser: false,
        hasProfile: false,
      );

      expect(redirect, isNull);
    });

    test('envia usuario sem sessao para auth', () {
      final redirect = resolveAppEntryRedirect(
        location: RoutePaths.hub,
        isAuthLoading: false,
        isProfileLoading: false,
        isSessionBootstrapping: false,
        hasAuthUser: false,
        hasProfile: true,
      );

      expect(redirect, RoutePaths.authPrompt);
    });

    test('envia usuario autenticado sem perfil para setup', () {
      final redirect = resolveAppEntryRedirect(
        location: RoutePaths.splash,
        isAuthLoading: false,
        isProfileLoading: false,
        isSessionBootstrapping: false,
        hasAuthUser: true,
        hasProfile: false,
      );

      expect(redirect, RoutePaths.profileSetup);
    });

    test('retira usuario autenticado das telas de auth', () {
      final redirect = resolveAppEntryRedirect(
        location: RoutePaths.authSignIn,
        isAuthLoading: false,
        isProfileLoading: false,
        isSessionBootstrapping: false,
        hasAuthUser: true,
        hasProfile: true,
      );

      expect(redirect, RoutePaths.hub);
    });
  });
}
