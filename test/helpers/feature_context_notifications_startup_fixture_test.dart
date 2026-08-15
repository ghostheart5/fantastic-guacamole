import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/models/si_pipeline_models.dart';
import 'package:fantastic_guacamole/state/providers/notification_provider.dart';
import 'package:fantastic_guacamole/state/providers/si_pipeline_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _account = NotifierProvider<_Account, String?>(_Account.new);

void main() {
  test('Nexus notification and startup inputs project A, signed-out, and B', () {
    final container = ProviderContainer(overrides: [
      unreadNotificationsProvider.overrideWith(
        (Ref ref) => _unread(ref.watch(_account)),
      ),
      nexusStartupSummaryProvider.overrideWith(
        (Ref ref) => _startup(ref.watch(_account)),
      ),
    ]);
    addTearDown(container.dispose);

    container.read(_account.notifier).set('A');
    expect(container.read(unreadNotificationsProvider), 7);
    expect(container.read(nexusStartupSummaryProvider).startupDirective, 'A_STARTUP');

    container.read(_account.notifier).set(null);
    expect(container.read(unreadNotificationsProvider), 0);
    expect(
      container.read(nexusStartupSummaryProvider).startupDirective,
      'SIGNED_OUT_STARTUP',
    );

    container.read(_account.notifier).set('B');
    expect(container.read(unreadNotificationsProvider), 2);
    final NexusStartupSummary bStartup = container.read(
      nexusStartupSummaryProvider,
    );
    expect(bStartup.startupDirective, 'B_STARTUP');
    expect(bStartup.profile.name, 'B_PROFILE');
    expect(bStartup.startupDirective, isNot('A_STARTUP'));
  });
}

class _Account extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? value) => state = value;
}

int _unread(String? account) => switch (account) {
  'A' => 7,
  'B' => 2,
  _ => 0,
};

NexusStartupSummary _startup(String? account) {
  final bool signedOut = account == null;
  return NexusStartupSummary(
    profile: ProfileState(
      name: signedOut ? 'signed_out' : '${account}_PROFILE',
      profileReady: !signedOut,
    ),
    energy: signedOut ? 0 : account == 'A' ? .8 : .3,
    fatigue: signedOut ? 0 : account == 'A' ? .1 : .6,
    completedToday: signedOut ? 0 : account == 'A' ? 5 : 1,
    emotionLabel: signedOut ? 'signed_out' : account == 'A' ? 'focused' : 'calm',
    startupDirective: signedOut
        ? 'SIGNED_OUT_STARTUP'
        : account == 'A'
        ? 'A_STARTUP'
        : 'B_STARTUP',
  );
}
