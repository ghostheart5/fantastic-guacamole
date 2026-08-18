import 'package:flutter/services.dart';

enum AppLocationStatus {
  ready,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  unavailable,
}

enum AppLocationPermission { denied, deniedForever, whileInUse }

class AppLocationSnapshot {
  const AppLocationSnapshot({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.timestamp,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime timestamp;
}

class AppLocationResult {
  const AppLocationResult._({
    required this.status,
    required this.message,
    this.snapshot,
  });

  const AppLocationResult.ready(AppLocationSnapshot snapshot)
    : this._(
        status: AppLocationStatus.ready,
        message: 'Location is ready.',
        snapshot: snapshot,
      );

  const AppLocationResult.serviceDisabled()
    : this._(
        status: AppLocationStatus.serviceDisabled,
        message: 'Location services are disabled on this device.',
      );

  const AppLocationResult.permissionDenied()
    : this._(
        status: AppLocationStatus.permissionDenied,
        message: 'Location permission was denied.',
      );

  const AppLocationResult.permissionDeniedForever()
    : this._(
        status: AppLocationStatus.permissionDeniedForever,
        message:
            'Location permission is permanently denied. Open system settings to enable it.',
      );

  const AppLocationResult.unavailable()
    : this._(
        status: AppLocationStatus.unavailable,
        message: 'Location is unavailable in this runtime.',
      );

  final AppLocationStatus status;
  final String message;
  final AppLocationSnapshot? snapshot;

  bool get isReady => status == AppLocationStatus.ready;
}

abstract class LocationGateway {
  Future<bool> isLocationServiceEnabled();
  Future<AppLocationPermission> checkPermission();
  Future<AppLocationPermission> requestPermission();
  Future<AppLocationSnapshot?> getLastKnownPosition();
  Future<AppLocationSnapshot> getCurrentPosition();
  Future<bool> openAppSettings();
  Future<bool> openLocationSettings();
}

class MethodChannelLocationGateway implements LocationGateway {
  const MethodChannelLocationGateway();

  static const MethodChannel _channel = MethodChannel('chronospark/location');

  @override
  Future<AppLocationPermission> checkPermission() async {
    final String value =
        await _channel.invokeMethod<String>('checkPermission') ?? 'denied';
    return _permissionFromPlatform(value);
  }

  @override
  Future<AppLocationSnapshot> getCurrentPosition() async {
    final Map<Object?, Object?>? raw = await _channel.invokeMethod(
      'getCurrentPosition',
    );
    final AppLocationSnapshot? snapshot = _snapshotFromPlatform(raw);
    if (snapshot == null) {
      throw PlatformException(
        code: 'LOCATION_UNAVAILABLE',
        message: 'No current location returned.',
      );
    }
    return snapshot;
  }

  @override
  Future<AppLocationSnapshot?> getLastKnownPosition() async {
    final Map<Object?, Object?>? raw = await _channel.invokeMethod(
      'getLastKnownPosition',
    );
    return _snapshotFromPlatform(raw);
  }

  @override
  Future<bool> isLocationServiceEnabled() async {
    return await _channel.invokeMethod<bool>('isLocationServiceEnabled') ??
        false;
  }

  @override
  Future<bool> openAppSettings() async {
    return await _channel.invokeMethod<bool>('openAppSettings') ?? false;
  }

  @override
  Future<bool> openLocationSettings() async {
    return await _channel.invokeMethod<bool>('openLocationSettings') ?? false;
  }

  @override
  Future<AppLocationPermission> requestPermission() async {
    final String value =
        await _channel.invokeMethod<String>('requestPermission') ?? 'denied';
    return _permissionFromPlatform(value);
  }
}

class AppLocationService {
  const AppLocationService({LocationGateway? gateway})
    : _gateway = gateway ?? const MethodChannelLocationGateway();

  final LocationGateway _gateway;

  Future<AppLocationResult> checkReadiness() {
    return currentLocation(requestPermission: false, preferCached: true);
  }

  Future<AppLocationResult> requestPermissionAndCurrentLocation() {
    return currentLocation(requestPermission: true);
  }

  Future<AppLocationResult> currentLocation({
    required bool requestPermission,
    bool preferCached = false,
  }) async {
    try {
      final bool serviceEnabled = await _gateway.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const AppLocationResult.serviceDisabled();
      }

      AppLocationPermission permission = await _gateway.checkPermission();
      if (permission == AppLocationPermission.denied && requestPermission) {
        permission = await _gateway.requestPermission();
      }

      if (permission == AppLocationPermission.denied) {
        return const AppLocationResult.permissionDenied();
      }
      if (permission == AppLocationPermission.deniedForever) {
        return const AppLocationResult.permissionDeniedForever();
      }

      if (preferCached) {
        final AppLocationSnapshot? cached = await _gateway
            .getLastKnownPosition();
        if (cached != null) {
          return AppLocationResult.ready(cached);
        }
      }

      final AppLocationSnapshot snapshot = await _gateway.getCurrentPosition();
      return AppLocationResult.ready(snapshot);
    } on Object {
      return const AppLocationResult.unavailable();
    }
  }

  Future<bool> openAppSettings() => _gateway.openAppSettings();

  Future<bool> openLocationSettings() => _gateway.openLocationSettings();
}

AppLocationPermission _permissionFromPlatform(String value) {
  return switch (value) {
    'whileInUse' || 'always' => AppLocationPermission.whileInUse,
    'deniedForever' => AppLocationPermission.deniedForever,
    _ => AppLocationPermission.denied,
  };
}

AppLocationSnapshot? _snapshotFromPlatform(Map<Object?, Object?>? raw) {
  if (raw == null) {
    return null;
  }
  final Object? latitude = raw['latitude'];
  final Object? longitude = raw['longitude'];
  final Object? accuracy = raw['accuracy'];
  final Object? timestamp = raw['timestamp'];
  if (latitude is! num || longitude is! num || accuracy is! num) {
    return null;
  }
  return AppLocationSnapshot(
    latitude: latitude.toDouble(),
    longitude: longitude.toDouble(),
    accuracyMeters: accuracy.toDouble(),
    timestamp: timestamp is int
        ? DateTime.fromMillisecondsSinceEpoch(timestamp)
        : DateTime.now(),
  );
}
