import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../behavior/_support/source_test_utils.dart';

void main() {
  group('P2-1 core-loop route priority contract', () {
    test('initial location priority order preserves Login -> Creator -> Timeline funnel semantics', () {
      final File routerFile = File('lib/app/router/app_router.dart');
      expect(routerFile.existsSync(), isTrue);

      final String text = SourceTestUtils.readText(routerFile);

      final int unknownGuardIndex = text.indexOf(
        'if (onboardingStatus == OnboardingStatus.unknown) {',
      );
      final int onboardingIncompleteIndex = text.indexOf('if (!onboardingComplete) {');
      final int unauthenticatedIndex = text.indexOf('if (!isAuthenticated) {');
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
    });

    test('redirect priority keeps creator gate ahead of timeline gate for authenticated users', () {
      final File routerFile = File('lib/app/router/app_router.dart');
      expect(routerFile.existsSync(), isTrue);

      final String text = SourceTestUtils.readText(routerFile);

      final int guardStart = text.indexOf(
        'if (isAuthenticated && onboardingComplete && hasValidProfile) {',
      );
      expect(guardStart, greaterThanOrEqualTo(0));

      final int creatorRedirectIndex = text.indexOf(
        'if (location == RoutePaths.home && !hasCreatedFirstItem) {',
      );
      final int timelineRedirectIndex = text.indexOf(
        'if (hasCreatedFirstItem &&\n            !hasCompletedTimelineFirstAction &&\n            location != RoutePaths.timeline) {',
      );

      expect(creatorRedirectIndex, greaterThan(guardStart));
      expect(timelineRedirectIndex, greaterThan(creatorRedirectIndex));
      expect(text.contains('return RoutePaths.creator;'), isTrue);
      expect(text.contains('return RoutePaths.timeline;'), isTrue);
    });

    test('timeline-origin task actions continue to mark first timeline action completion', () {
      final File taskProviderFile = File('lib/state/providers/task_provider.dart');
      expect(taskProviderFile.existsSync(), isTrue);

      final String text = SourceTestUtils.readText(taskProviderFile);

      expect(text.contains("actionSource == 'timeline'"), isTrue);
      expect(
        text.contains('unawaited(_markTimelineFirstActionCompleted());'),
        isTrue,
      );
    });
  });
}
