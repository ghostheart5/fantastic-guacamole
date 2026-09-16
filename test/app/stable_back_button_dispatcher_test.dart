import 'package:fantastic_guacamole/app/router/stable_back_button_dispatcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('retries one transient unmounted route after the next frame', (
    WidgetTester tester,
  ) async {
    final StableBackButtonDispatcher dispatcher = StableBackButtonDispatcher();
    int attempts = 0;
    Future<bool> onBack() async {
      attempts++;
      if (attempts == 1) {
        throw AssertionError(
          "'package:flutter/src/widgets/routes.dart': Failed assertion: "
          "'scope != null': is not true.",
        );
      }
      return true;
    }

    dispatcher.addCallback(onBack);
    final Future<bool> first = dispatcher.didPopRoute();
    final Future<bool> second = dispatcher.didPopRoute();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(await first, isTrue);
    expect(await second, isTrue);
    expect(attempts, 3);
    dispatcher.removeCallback(onBack);
  });

  testWidgets('continues queued back requests after a retry also fails', (
    WidgetTester tester,
  ) async {
    final StableBackButtonDispatcher dispatcher = StableBackButtonDispatcher();
    int attempts = 0;
    Future<bool> onBack() async {
      attempts++;
      if (attempts <= 2) {
        throw AssertionError(
          "'package:flutter/src/widgets/routes.dart': Failed assertion: "
          "'scope != null': is not true.",
        );
      }
      return true;
    }

    dispatcher.addCallback(onBack);
    final Future<bool> first = dispatcher.didPopRoute();
    final Future<void> firstError = expectLater(
      first,
      throwsA(isA<AssertionError>()),
    );
    final Future<bool> second = dispatcher.didPopRoute();
    await tester.pump();
    await tester.pumpAndSettle();
    await firstError;
    expect(await second, isTrue);
    expect(attempts, 3);
    dispatcher.removeCallback(onBack);
  });
}
