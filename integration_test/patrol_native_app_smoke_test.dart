import 'package:fantastic_guacamole/app/app_root.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

const bool _runNativePatrol = bool.fromEnvironment(
  'RUN_NATIVE_PATROL',
  defaultValue: false,
);

void main() {
  if (!_runNativePatrol) {
    test(
      'native patrol app smoke is opt-in',
      () => expect(true, isTrue),
      skip: 'Run with Patrol CLI and --dart-define=RUN_NATIVE_PATROL=true.',
    );
    return;
  }

  patrolTest('native patrol app root flow boots', ($) async {
    await $.pumpWidgetAndSettle(
      const ProviderScope(
        child: AppRoot(),
      ),
    );

    expect(find.byType(AppRoot), findsOneWidget);
  });
}
