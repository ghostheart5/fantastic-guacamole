/// Allows preference cleanup only in a disposable native-test installation.
/// Physical devices require the separately installed debug test package.
bool isDisposableNativeTestInstallation({
  required bool isPhysicalDevice,
  required bool isDebugBuild,
  required String packageName,
}) {
  if (!isDebugBuild) {
    return false;
  }
  if (packageName == 'com.ghostheart5.chronospark.nativevalidation') {
    return true;
  }
  return !isPhysicalDevice && packageName == 'com.ghostheart5.chronospark';
}
