import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Streams `true` when any network interface is available, `false` when offline.
final networkStatusProvider = StreamProvider<bool>((ref) async* {
  final Connectivity connectivity = Connectivity();
  final List<ConnectivityResult> initial = await connectivity
      .checkConnectivity();
  yield initial.any((result) => result != ConnectivityResult.none);
  yield* connectivity.onConnectivityChanged.map(
    (results) => results.any((result) => result != ConnectivityResult.none),
  );
});

/// Synchronous bool derived from [networkStatusProvider].
/// Returns `false` until an available interface is observed.
final isOnlineProvider = Provider<bool>((ref) {
  return ref
      .watch(networkStatusProvider)
      .when(
        data: (value) => value,
        loading: () => false,
        error: (_, _) => false,
      );
});
