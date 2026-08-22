import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../behavior/_support/source_test_utils.dart';

void main() {
  group('P2-1 core-loop route priority contract', () {
    test(
      'initial location priority order preserves Login -> Creator -> Timeline funnel semantics',
      () {
        final File routerFile = File('lib/app/router/app_router.dart');
        expect(routerFile.existsSync(), isTrue);

        final String text = SourceTestUtils.readText(routerFile);

        final int unknownGuardIndex = text.indexOf(
          'if (onboardingStatus == OnboardingStatus.unknown) {',
        );
        final int onboardingIncompleteIndex = text.indexOf(
          'if (!onboardingComplete) {',
        );
        final int unauthenticatedIndex = text.indexOf(
          'if (!isAuthenticated) {',
        );
        final int invalidProfileIndex = text.indexOf('if (!hasValidProfile) {');
        final int firstItemIndex = text.indexOf('if (!hasCreatedFirstItem) {');
        final int firstTimelineActionIndex = text.indexOf(
          'if (!hasCompletedTimelineFirstAction) {',
        );

        expect(unknownGuardIndex, greaterThanOrEqualTo(0));
        expect(onboardingIncompleteIndex, greaterThan(unknownGuardIndex));
        expect(unauthenticatedIndex, greaterThan(onboardingIncompleteIndex));
        expect(invalidProfileIndex, greaterThan(unauthenticatedIndex));
        expect(firstItemIndex, greaterThan(invalidProfileIndex));
        expect(firstTimelineActionIndex, greaterThan(firstItemIndex));

        expect(
          text.contains(
            'return isAuthenticated ? RoutePaths.creator : RoutePaths.onboarding;',
          ),
          isTrue,
        );
        expect(text.contains('return RoutePaths.login;'), isTrue);
        expect(text.contains('return RoutePaths.creator;'), isTrue);
        expect(text.contains('return RoutePaths.timeline;'), isTrue);
        expect(text.contains('return RoutePaths.home;'), isTrue);
      },
    );

    test(
      'redirect priority keeps creator gate ahead of timeline gate for authenticated users',
      () {
        final File routerFile = File('lib/app/router/app_router.dart');
        expect(routerFile.existsSync(), isTrue);

        final String text = SourceTestUtils.readText(routerFile);

        final int redirectStart = text.indexOf(
          'redirect: (BuildContext context, GoRouterState state) {',
        );
        final int authenticationGateIndex = text.indexOf(
          'if (!isAuthenticated) {',
          redirectStart,
        );
        expect(authenticationGateIndex, greaterThanOrEqualTo(0));

        final int creatorRedirectIndex = text.indexOf(
          'if (location == RoutePaths.home && !hasCreatedFirstItem) {',
        );
        final int timelineRedirectIndex = text.indexOf(
          '!hasCompletedTimelineFirstAction &&',
        );

        expect(creatorRedirectIndex, greaterThan(authenticationGateIndex));
        expect(timelineRedirectIndex, greaterThan(creatorRedirectIndex));
        expect(text.contains('return RoutePaths.creator;'), isTrue);
        expect(text.contains('return RoutePaths.timeline;'), isTrue);
      },
    );

    test(
      'auth callback routes are allowed before startup onboarding redirects',
      () {
        final File routerFile = File('lib/app/router/app_router.dart');
        final File policyFile = File('lib/app/router/navigation_policy.dart');
        final String routerText = SourceTestUtils.readText(routerFile);
        final String policyText = SourceTestUtils.readText(policyFile);
        final int callbackRouteIndex = policyText.indexOf(
          'isAuthCallbackLoginRoute',
        );
        final int unknownGuardIndex = policyText.indexOf(
          'if (onboardingStatus == OnboardingStatus.unknown) {',
        );

        expect(policyFile.existsSync(), isTrue);
        expect(routerText.contains('resolveStartupRouteGate'), isTrue);
        expect(callbackRouteIndex, greaterThanOrEqualTo(0));
        expect(unknownGuardIndex, greaterThan(callbackRouteIndex));
        expect(policyText.contains("mode == 'recovery'"), isTrue);
        expect(policyText.contains("mode == 'verify-email'"), isTrue);
        expect(policyText.contains("mode == 'auth-callback'"), isTrue);
      },
    );

    test(
      'completion event inspector route requires debug mode or admin access',
      () {
        final File routerFile = File('lib/app/router/app_router.dart');
        final File policyFile = File('lib/app/router/navigation_policy.dart');
        final String routerText = SourceTestUtils.readText(routerFile);
        final String policyText = SourceTestUtils.readText(policyFile);

        expect(
          routerText.contains('ref.read(adminAccessGuardProvider)'),
          isTrue,
        );
        expect(
          routerText.contains('_ref.listen(intelligenceStateProvider'),
          isTrue,
        );
        expect(
          routerText.contains('shouldRegisterCompletionEventsRoute'),
          isTrue,
        );
        expect(
          routerText.contains('path: RoutePaths.completionEvents'),
          isTrue,
        );
        expect(policyFile.existsSync(), isTrue);
        expect(policyText.contains('!isReleaseMode || hasAdminAccess'), isTrue);
      },
    );

    test(
      'timeline-origin task actions continue to mark first timeline action completion',
      () {
        final File taskProviderFile = File(
          'lib/state/providers/task_provider.dart',
        );
        expect(taskProviderFile.existsSync(), isTrue);

        final String text = SourceTestUtils.readText(taskProviderFile);

        expect(text.contains("actionSource == 'timeline'"), isTrue);
        expect(
          text.contains('await _markTimelineFirstActionCompleted();'),
          isTrue,
        );
      },
    );
  });
}
