import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fantastic_guacamole/core/network/network_status_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an available interface does not claim service reachability', () {
    final NetworkStatus status = NetworkStatus.fromConnectivityResults(
      const <ConnectivityResult>[ConnectivityResult.wifi],
    );

    expect(
      status.interfaceAvailability,
      NetworkInterfaceAvailability.available,
    );
    expect(status.hasAvailableInterface, isTrue);
    expect(status.serviceReachability, ServiceReachability.unverified);
    expect(status.hasVerifiedServiceReachability, isFalse);
  });

  test('an explicit no-interface result is unavailable, not reachable', () {
    final NetworkStatus status = NetworkStatus.fromConnectivityResults(
      const <ConnectivityResult>[ConnectivityResult.none],
    );

    expect(
      status.interfaceAvailability,
      NetworkInterfaceAvailability.unavailable,
    );
    expect(status.hasAvailableInterface, isFalse);
    expect(status.serviceReachability, ServiceReachability.unverified);
  });

  test('an empty observation remains unknown', () {
    final NetworkStatus status = NetworkStatus.fromConnectivityResults(
      const <ConnectivityResult>[],
    );

    expect(status.interfaceAvailability, NetworkInterfaceAvailability.unknown);
    expect(status.serviceReachability, ServiceReachability.unverified);
  });

  test(
    'verified reachability can be copied independently of interface state',
    () {
      const NetworkStatus interfaceOnly = NetworkStatus(
        interfaceAvailability: NetworkInterfaceAvailability.available,
      );

      final NetworkStatus verified = interfaceOnly.copyWith(
        serviceReachability: ServiceReachability.reachable,
      );

      expect(
        verified.interfaceAvailability,
        NetworkInterfaceAvailability.available,
      );
      expect(verified.serviceReachability, ServiceReachability.reachable);
      expect(verified.hasVerifiedServiceReachability, isTrue);
      expect(interfaceOnly.serviceReachability, ServiceReachability.unverified);
    },
  );
}
