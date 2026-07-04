import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Streams `true` when any network interface is available, `false` when offline.
/// Defaults to `true` (optimistic) while the first event is pending.
final networkStatusProvider = StreamProvider<bool>((ref) {
  return Connectivity().onConnectivityChanged.map(
    (results) => results.any((r) => r != ConnectivityResult.none),
  );
});

/// Synchronous bool derived from [networkStatusProvider].
/// Returns `true` if online or the status is not yet known.
final isOnlineProvider = Provider<bool>((ref) {
  return ref
      .watch(networkStatusProvider)
      .when(data: (v) => v, loading: () => true, error: (_, _) => true);
});
