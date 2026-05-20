import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
