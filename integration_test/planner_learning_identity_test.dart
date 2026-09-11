import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/helpers/native_test_installation.dart';
import '../test/helpers/planner_learning_identity_scenario.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Planner task and its exact outcome survive native storage reopen', (
    tester,
  ) async {
    // Runs in the disposable integration-test installation. This uses the real
    // Android preferences plugin; it must never target a personal installation.
    expect(Platform.isAndroid, isTrue);
    expect(
      isDisposableNativeTestInstallation(
        isPhysicalDevice:
            (await DeviceInfoPlugin().androidInfo).isPhysicalDevice,
        isDebugBuild: kDebugMode,
        packageName: (await PackageInfo.fromPlatform()).packageName,
      ),
      isTrue,
      reason:
          'Preference cleanup requires a debug emulator installation or the '
          'separate nativevalidation debug package; never the personal phone app.',
    );
    final preferences = await SharedPreferences.getInstance();
    await preferences.clear();
    final directory = await Directory.systemTemp.createTemp(
      'cs_learning_native_',
    );
    await Hive.close();
    Hive.init(directory.path);
    try {
      await verifyPlannerLearningIdentity(
        reopenStorage: () async {
          await Hive.close();
          Hive.init(directory.path);
          await preferences.reload();
        },
      );
      expect(tester.takeException(), isNull);
    } finally {
      await Hive.close();
      await directory.delete(recursive: true);
    }
  });
}
