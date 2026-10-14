import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

// Exercise visible setup and guidance controls; never mutate providers or
// bypass protected routes. A requested destination can require setup again.
Future<void> settleCurrentUserNavigation(
  PatrolIntegrationTester $, {
  required bool Function() destinationReady,
}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 60));
  var guides = 0;
  var readyFrames = 0;
  while (DateTime.now().isBefore(deadline)) {
    if (find.text('CONTEXTUAL GUIDANCE').hitTestable().evaluate().isNotEmpty &&
        find.text('Not now').hitTestable().evaluate().isNotEmpty) {
      expect(
        guides++,
        lessThan(8),
        reason: 'Repeated guidance must stay bounded.',
      );
      await $('Not now').tap();
      readyFrames = 0;
    } else if (find
        .byKey(const Key('local-profile-continue'))
        .hitTestable()
        .evaluate()
        .isNotEmpty) {
      await $(const Key('local-profile-continue')).tap();
      readyFrames = 0;
    } else if (find
        .text('CONTINUE TO LOGIN')
        .hitTestable()
        .evaluate()
        .isNotEmpty) {
      await $('CONTINUE TO LOGIN').tap();
      readyFrames = 0;
    } else if (find
            .text('FIRST SETUP 3 OF 3')
            .hitTestable()
            .evaluate()
            .isNotEmpty &&
        find.byKey(const Key('first-value-skip')).evaluate().isNotEmpty) {
      await $(const Key('first-value-skip')).scrollTo();
      await $(const Key('first-value-skip')).tap();
      readyFrames = 0;
    } else if (find.text('Pause guide').hitTestable().evaluate().isNotEmpty) {
      await $('Pause guide').tap();
      readyFrames = 0;
    } else if (destinationReady()) {
      if (++readyFrames >= 2) return;
    } else {
      readyFrames = 0;
    }
    await $.pump(const Duration(milliseconds: 250));
  }
  debugPrint(
    'AXIOMARA_BLOCKED_NAVIGATION ${$.tester.widgetList<Text>(find.byType(Text)).map((text) => text.data).toList()}',
  );
  fail(
    'The real destination was not reachable through visible setup/guidance controls.',
  );
}
