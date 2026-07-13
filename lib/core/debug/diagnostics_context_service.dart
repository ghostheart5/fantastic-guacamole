import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class DiagnosticsContext {
  const DiagnosticsContext({
    required this.appName,
    required this.packageName,
    required this.version,
    required this.buildNumber,
    required this.platform,
    required this.osVersion,
    required this.model,
    required this.deviceId,
    required this.isPhysicalDevice,
  });

  final String appName;
  final String packageName;
  final String version;
  final String buildNumber;
  final String platform;
  final String osVersion;
  final String model;
  final String deviceId;
  final bool isPhysicalDevice;

  String get appVersionLabel => '$version+$buildNumber';

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'appName': appName,
      'packageName': packageName,
      'appVersion': version,
      'buildNumber': buildNumber,
      'platform': platform,
      'osVersion': osVersion,
      'model': model,
      'deviceId': deviceId,
      'isPhysicalDevice': isPhysicalDevice,
    };
  }
}

class DiagnosticsContextService {
  DiagnosticsContextService._();

  static Future<DiagnosticsContext>? _cachedFuture;

  static Future<DiagnosticsContext> collect() {
    return _cachedFuture ??= _collectInternal();
  }

  static Future<DiagnosticsContext> _collectInternal() async {
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

    String platform = defaultTargetPlatform.name;
    String osVersion = 'unknown';
    String model = 'unknown';
    String deviceId = 'unknown';
    bool isPhysical = true;

    if (kIsWeb) {
      final WebBrowserInfo info = await deviceInfo.webBrowserInfo;
      platform = 'web';
      osVersion = info.appVersion ?? 'web';
      model = info.browserName.name;
      deviceId = info.userAgent ?? 'web';
      isPhysical = true;
    } else {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          final AndroidDeviceInfo info = await deviceInfo.androidInfo;
          platform = 'android';
          osVersion = 'Android ${info.version.release}';
          model = '${info.manufacturer} ${info.model}'.trim();
          deviceId = info.id;
          isPhysical = info.isPhysicalDevice;
          break;
        case TargetPlatform.iOS:
          final IosDeviceInfo info = await deviceInfo.iosInfo;
          platform = 'ios';
          osVersion = '${info.systemName} ${info.systemVersion}';
          model = info.utsname.machine;
          deviceId = info.identifierForVendor ?? 'unknown';
          isPhysical = info.isPhysicalDevice;
          break;
        case TargetPlatform.macOS:
          final MacOsDeviceInfo info = await deviceInfo.macOsInfo;
          platform = 'macos';
          osVersion = info.osRelease;
          model = info.model;
          deviceId = info.systemGUID ?? 'unknown';
          isPhysical = true;
          break;
        case TargetPlatform.windows:
          final WindowsDeviceInfo info = await deviceInfo.windowsInfo;
          platform = 'windows';
          osVersion = info.displayVersion;
          model = info.productName;
          deviceId = info.deviceId;
          isPhysical = true;
          break;
        case TargetPlatform.linux:
          final LinuxDeviceInfo info = await deviceInfo.linuxInfo;
          platform = 'linux';
          osVersion = info.version ?? 'linux';
          model = info.prettyName;
          deviceId = info.machineId ?? 'unknown';
          isPhysical = true;
          break;
        case TargetPlatform.fuchsia:
          platform = 'fuchsia';
          osVersion = 'fuchsia';
          model = 'fuchsia';
          deviceId = 'fuchsia';
          isPhysical = true;
          break;
      }
    }

    return DiagnosticsContext(
      appName: packageInfo.appName,
      packageName: packageInfo.packageName,
      version: packageInfo.version,
      buildNumber: packageInfo.buildNumber,
      platform: platform,
      osVersion: osVersion,
      model: model,
      deviceId: deviceId,
      isPhysicalDevice: isPhysical,
    );
  }
}
