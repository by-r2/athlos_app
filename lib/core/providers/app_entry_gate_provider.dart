import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/presentation/providers/auth_notifier.dart';
import '../../features/profile/presentation/providers/profile_notifier.dart';
import '../router/app_entry_gate.dart';
import 'session_bootstrap_provider.dart';

part 'app_entry_gate_provider.g.dart';

/// Single source of truth for splash blocking and GoRouter entry redirects.
@Riverpod(keepAlive: true)
AppEntryGate appEntryGate(Ref ref) {
  final authAsync = ref.watch(authProvider);
  final hasProfileAsync = ref.watch(hasProfileProvider);
  final isSessionBootstrapComplete = ref.watch(sessionBootstrapProvider);

  return computeAppEntryGate(
    isAuthLoading: authAsync.isLoading,
    hasAuthUser: authAsync.value != null,
    isProfileAsyncLoading: hasProfileAsync.isLoading,
    hasProfileValue: hasProfileAsync.value ?? false,
    isSessionBootstrapComplete: isSessionBootstrapComplete,
  );
}
