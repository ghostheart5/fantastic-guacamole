import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum NetworkInterfaceAvailability { unknown, unavailable, available }

enum ServiceReachability { unverified, unreachable, reachable }

/// Interface state and separately verified service reachability.
///
/// Connectivity results prove only that an interface exists. They do not prove
/// that any remote service can be reached.
@immutable
class NetworkStatus {
  const NetworkStatus({
    required this.interfaceAvailability,
    this.serviceReachability = ServiceReachability.unverified,
  });

  const NetworkStatus.unknown()
    : interfaceAvailability = NetworkInterfaceAvailability.unknown,
      serviceReachability = ServiceReachability.unverified;

  factory NetworkStatus.fromConnectivityResults(
    Iterable<ConnectivityResult> results,
  ) {
    final List<ConnectivityResult> observedResults = results.toList(
      growable: false,
    );
    if (observedResults.isEmpty) {
      return const NetworkStatus.unknown();
    }
    final bool hasInterface = observedResults.any(
      (ConnectivityResult result) => result != ConnectivityResult.none,
    );
    return NetworkStatus(
      interfaceAvailability: hasInterface
          ? NetworkInterfaceAvailability.available
          : NetworkInterfaceAvailability.unavailable,
    );
  }

  final NetworkInterfaceAvailability interfaceAvailability;
  final ServiceReachability serviceReachability;

  bool get hasAvailableInterface =>
      interfaceAvailability == NetworkInterfaceAvailability.available;

  bool get hasVerifiedServiceReachability =>
      serviceReachability == ServiceReachability.reachable;

  NetworkStatus copyWith({
    NetworkInterfaceAvailability? interfaceAvailability,
    ServiceReachability? serviceReachability,
  }) => NetworkStatus(
    interfaceAvailability: interfaceAvailability ?? this.interfaceAvailability,
    serviceReachability: serviceReachability ?? this.serviceReachability,
  );
}

/// Streams interface availability without claiming remote service reachability.
final networkStatusProvider = StreamProvider<NetworkStatus>((ref) async* {
  final Connectivity connectivity = Connectivity();
  final List<ConnectivityResult> initial = await connectivity
      .checkConnectivity();
  yield NetworkStatus.fromConnectivityResults(initial);
  yield* connectivity.onConnectivityChanged.map(
    NetworkStatus.fromConnectivityResults,
  );
});

final networkInterfaceAvailabilityProvider =
    Provider<NetworkInterfaceAvailability>((ref) {
      return ref
          .watch(networkStatusProvider)
          .when(
            data: (NetworkStatus value) => value.interfaceAvailability,
            loading: () => NetworkInterfaceAvailability.unknown,
            error: (_, _) => NetworkInterfaceAvailability.unknown,
          );
    });

final serviceReachabilityProvider = Provider<ServiceReachability>((ref) {
  return ref
      .watch(networkStatusProvider)
      .when(
        data: (NetworkStatus value) => value.serviceReachability,
        loading: () => ServiceReachability.unverified,
        error: (_, _) => ServiceReachability.unverified,
      );
});
