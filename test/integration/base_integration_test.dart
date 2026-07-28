import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('base integration coverage', () {
    test('navigation shell wires primary screens', () {
      final String navigationSource = File(
        'lib/app/navigation_shell.dart',
      ).readAsStringSync();

      expect(navigationSource, contains('NavigationShell'));
      expect(navigationSource, contains('NexusScreen'));
      expect(navigationSource, contains('ProfileScreen'));
      expect(navigationSource, contains('SettingsScreen'));
    });

    test('navigation shell includes offline and scheduler surfaces', () {
      final String navigationSource = File(
        'lib/app/navigation_shell.dart',
      ).readAsStringSync();
      final String offlineBannerSource = File(
        'lib/ui/widgets/offline_banner.dart',
      ).readAsStringSync();

      expect(navigationSource, contains('OfflineBanner'));
      expect(navigationSource, contains('SystemScheduler'));
      expect(offlineBannerSource, contains('class OfflineBanner'));
    });
  });
}
