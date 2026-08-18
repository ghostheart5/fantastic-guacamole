import 'package:fantastic_guacamole/system/location/location_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppLocationService', () {
    test('checkReadiness does not request permission implicitly', () async {
      final _FakeLocationGateway gateway = _FakeLocationGateway(
        permission: AppLocationPermission.denied,
      );
      final service = AppLocationService(gateway: gateway);

      final result = await service.checkReadiness();

      expect(result.status, AppLocationStatus.permissionDenied);
      expect(gateway.requestPermissionCalls, 0);
      expect(gateway.currentPositionCalls, 0);
    });

    test('returns serviceDisabled when device location is off', () async {
      final service = AppLocationService(
        gateway: _FakeLocationGateway(serviceEnabled: false),
      );

      final result = await service.requestPermissionAndCurrentLocation();

      expect(result.status, AppLocationStatus.serviceDisabled);
    });

    test(
      'request flow asks for permission and returns deniedForever',
      () async {
        final _FakeLocationGateway gateway = _FakeLocationGateway(
          permission: AppLocationPermission.denied,
          requestedPermission: AppLocationPermission.deniedForever,
        );
        final service = AppLocationService(gateway: gateway);

        final result = await service.requestPermissionAndCurrentLocation();

        expect(result.status, AppLocationStatus.permissionDeniedForever);
        expect(gateway.requestPermissionCalls, 1);
      },
    );

    test(
      'uses cached location for readiness when permission is granted',
      () async {
        final DateTime timestamp = DateTime.utc(2026, 8, 18, 12);
        final service = AppLocationService(
          gateway: _FakeLocationGateway(
            permission: AppLocationPermission.whileInUse,
            lastKnownPosition: _snapshot(timestamp: timestamp),
          ),
        );

        final result = await service.checkReadiness();

        expect(result.status, AppLocationStatus.ready);
        expect(result.snapshot?.latitude, 39.0997);
        expect(result.snapshot?.longitude, -94.5786);
        expect(result.snapshot?.timestamp, timestamp);
      },
    );

    test('requests current location when explicitly enabled', () async {
      final _FakeLocationGateway gateway = _FakeLocationGateway(
        permission: AppLocationPermission.whileInUse,
        currentPosition: _snapshot(latitude: 40.0, longitude: -95.0),
      );
      final service = AppLocationService(gateway: gateway);

      final result = await service.requestPermissionAndCurrentLocation();

      expect(result.status, AppLocationStatus.ready);
      expect(result.snapshot?.latitude, 40.0);
      expect(result.snapshot?.longitude, -95.0);
      expect(gateway.currentPositionCalls, 1);
    });
  });
}

AppLocationSnapshot _snapshot({
  double latitude = 39.0997,
  double longitude = -94.5786,
  DateTime? timestamp,
}) {
  return AppLocationSnapshot(
    latitude: latitude,
    longitude: longitude,
    accuracyMeters: 12,
    timestamp: timestamp ?? DateTime.utc(2026, 8, 18),
  );
}

class _FakeLocationGateway implements LocationGateway {
  _FakeLocationGateway({
    this.serviceEnabled = true,
    this.permission = AppLocationPermission.whileInUse,
    AppLocationPermission? requestedPermission,
    this.lastKnownPosition,
    AppLocationSnapshot? currentPosition,
  }) : requestedPermission = requestedPermission ?? permission,
       currentPosition = currentPosition ?? _snapshot();

  bool serviceEnabled;
  AppLocationPermission permission;
  AppLocationPermission requestedPermission;
  AppLocationSnapshot? lastKnownPosition;
  AppLocationSnapshot currentPosition;
  int requestPermissionCalls = 0;
  int currentPositionCalls = 0;

  @override
  Future<AppLocationPermission> checkPermission() async => permission;

  @override
  Future<AppLocationSnapshot> getCurrentPosition() async {
    currentPositionCalls += 1;
    return currentPosition;
  }

  @override
  Future<AppLocationSnapshot?> getLastKnownPosition() async =>
      lastKnownPosition;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;

  @override
  Future<AppLocationPermission> requestPermission() async {
    requestPermissionCalls += 1;
    permission = requestedPermission;
    return requestedPermission;
  }
}
