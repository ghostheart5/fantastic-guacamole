import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/state/services/session_recovery_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() async {
    await SharedPrefsService.init();
    await SharedPrefsService.clear();
  });

  test('recovery state is isolated by captured user scope', () async {
    final SessionRecoveryService userA = SessionRecoveryService(
      storageScope: 'user_a',
    );
    final SessionRecoveryService userB = SessionRecoveryService(
      storageScope: 'user_b',
    );

    await userA.saveState(lastRoute: '/a', activeTaskId: 'task-a');

    expect((await userA.loadState())?.lastRoute, '/a');
    expect(await userB.loadState(), isNull);

    await userB.saveState(lastRoute: '/b');
    expect((await userA.loadState())?.lastRoute, '/a');
    expect((await userB.loadState())?.lastRoute, '/b');
  });

  test('signed-out scope is separate and construction is non-destructive', () async {
    final SessionRecoveryService signedOut = SessionRecoveryService(
      storageScope: 'signed_out',
    );
    await signedOut.saveState(draftTaskTitle: 'draft');

    final SessionRecoveryService recreated = SessionRecoveryService(
      storageScope: 'signed_out',
    );
    final SessionRecoveryService userA = SessionRecoveryService(
      storageScope: 'user_a',
    );

    expect((await recreated.loadState())?.draftTaskTitle, 'draft');
    expect(await userA.loadState(), isNull);
  });
}
