import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../behavior/_support/source_test_utils.dart';

void main() {
  group('Deep link release contract', () {
    test(
      'router/deep link source exists when go_router or app_links dependencies are present',
      () {
        final String pubspec = SourceTestUtils.readText(
          File('pubspec.yaml'),
        ).toLowerCase();
        final bool hasDeepLinkDeps =
            pubspec.contains('go_router') || pubspec.contains('app_links');

        final File appRouter = File('lib/app/router/app_router.dart');
        final File deepLinkService = File(
          'lib/app/router/deep_link_service.dart',
        );
        final File appRoot = File('lib/app/app_root.dart');
        final File navigationPolicy = File(
          'lib/app/router/navigation_policy.dart',
        );

        if (!hasDeepLinkDeps) {
          return;
        }

        expect(appRouter.existsSync(), isTrue);
        expect(deepLinkService.existsSync(), isTrue);
        expect(appRoot.existsSync(), isTrue);
        expect(navigationPolicy.existsSync(), isTrue);

        final String routerText = SourceTestUtils.readText(
          appRouter,
        ).toLowerCase();
        final String deepLinkText = SourceTestUtils.readText(
          deepLinkService,
        ).toLowerCase();
        final String appRootText = SourceTestUtils.readText(
          appRoot,
        ).toLowerCase();
        final String policyText = SourceTestUtils.readText(
          navigationPolicy,
        ).toLowerCase();

        expect(
          routerText.contains('redirect') || routerText.contains('gorouter'),
          isTrue,
        );
        expect(
          routerText.contains('error') || routerText.contains('unknown'),
          isTrue,
        );
        expect(
          deepLinkText.contains('uri') || deepLinkText.contains('link'),
          isTrue,
        );
        expect(appRootText.contains('resolvedeeplinklocation'), isTrue);
        expect(policyText.contains('unsupportedlink'), isTrue);
        expect(routerText.contains('routepaths.unsupportedlink'), isTrue);
      },
    );
  });
}
