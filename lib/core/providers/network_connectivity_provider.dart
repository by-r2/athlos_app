import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'network_connectivity_provider.g.dart';

/// Whether the device has a route that can reach the internet (best-effort).
@Riverpod(keepAlive: true)
class NetworkConnectivity extends _$NetworkConnectivity {
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  @override
  Future<bool> build() async {
    _subscription?.cancel();
    _subscription = Connectivity().onConnectivityChanged.listen((_) {
      unawaited(_refresh());
    });
    ref.onDispose(() => _subscription?.cancel());
    return _probeInternet();
  }

  Future<void> _refresh() async {
    final hasInternet = await _probeInternet();
    state = AsyncData(hasInternet);
  }

  Future<bool> _probeInternet() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      return false;
    }

    final client = http.Client();
    try {
      final response = await client
          .get(Uri.https('example.com', '/'))
          .timeout(const Duration(seconds: 3));
      return response.statusCode >= 200 && response.statusCode < 500;
    } on Object {
      return false;
    } finally {
      client.close();
    }
  }
}

/// Synchronous best-effort check for sync gating (defaults to false while loading).
@Riverpod(keepAlive: true)
bool isNetworkAvailableForSync(Ref ref) {
  return ref.watch(networkConnectivityProvider).value ?? false;
}

/// Waits until [isNetworkAvailableForSync] is true or [timeout] elapses.
///
/// Used on login so sync is not skipped while the connectivity probe is still
/// loading (which would leave an empty DB after logout wipe).
/// [ref] may be a `Ref` (from generated providers) or a `WidgetRef`.
Future<bool> waitForNetworkAvailableForSync(
  dynamic ref, {
  Duration timeout = const Duration(seconds: 8),
  Duration pollInterval = const Duration(milliseconds: 200),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final available = ref.read(isNetworkAvailableForSyncProvider);
    if (available == true) return true;
    await Future<void>.delayed(pollInterval);
  }
  final available = ref.read(isNetworkAvailableForSyncProvider);
  return available == true;
}
