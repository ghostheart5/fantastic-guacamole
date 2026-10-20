import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/config/backend_mode.dart';
import 'package:fantastic_guacamole/config/launch_containment.dart';
import 'package:fantastic_guacamole/data/services/ai/agents/chat_agent.dart';
import 'package:fantastic_guacamole/config/public_release_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compiled public cloud intent selects reviewed capabilities only', () {
    final enabled =
        PublicReleaseProfile.requested &&
        BackendConfiguration.cloudServicesEnabled;
    expect(Env.externalAiEnabled, enabled);
    expect(Env.creditSpendingEnabled, enabled);
    expect(Env.paidCreditPlansEnabled, enabled);
    expect(Env.subscriptionsEnabled, enabled);
    expect(Env.enableCloudRestore, enabled);
    expect(
      Env.enableCloudSync,
      enabled && const bool.fromEnvironment('CHRONOSPARK_ENABLE_CLOUD_SYNC'),
    );
    expect(const ChatAgent().externalAiEnabled, enabled);
    expect(Env.enableAnalytics, isFalse);
    expect(Env.enableCrashReporting, isFalse);
    expect(LaunchContainment.inferredIdentityEnabled, isFalse);
  });
}
