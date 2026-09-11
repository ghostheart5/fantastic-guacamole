import 'package:flutter_test/flutter_test.dart';

import '../helpers/native_test_installation.dart';

void main() {
  const mainPackage = 'com.ghostheart5.chronospark';
  const isolatedPackage = '$mainPackage.nativevalidation';
  for (final physical in [false, true]) {
    for (final debug in [false, true]) {
      for (final package in [mainPackage, isolatedPackage, 'unrelated.app']) {
        final allowed = <(bool, bool, String)>{
          (false, true, mainPackage),
          (false, true, isolatedPackage),
          (true, true, isolatedPackage),
        }.contains((physical, debug, package));
        test('${allowed ? 'allows' : 'rejects'} physical=$physical '
            'debug=$debug package=$package', () {
          expect(
            isDisposableNativeTestInstallation(
              isPhysicalDevice: physical,
              isDebugBuild: debug,
              packageName: package,
            ),
            allowed,
          );
        });
      }
    }
  }
}
