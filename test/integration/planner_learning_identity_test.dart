import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/planner_learning_identity_scenario.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'confirmed Planner task keeps exact learning identity after storage reopen',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final directory = await Directory.systemTemp.createTemp(
        'cs_learning_identity_',
      );
      Hive.init(directory.path);
      try {
        await verifyPlannerLearningIdentity(
          reopenStorage: () async {
            await Hive.close();
            Hive.init(directory.path);
            await (await SharedPreferences.getInstance()).reload();
          },
        );
      } finally {
        await Hive.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
