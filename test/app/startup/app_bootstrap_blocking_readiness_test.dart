import 'package:fantastic_guacamole/app/startup/app_bootstrap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('blocks dangerous monetization and testing override readiness issues', () {
    const List<String> readinessIssues = <String>[
      'Mock login bypass is enabled.',
      'Global mock mode is enabled.',
      'Paywall-disabled development override is enabled.',
      'Tester full-access override is enabled.',
      'Some informational warning.',
    ];

    final List<String> blocking = blockingProductionReadinessIssues(
      readinessIssues,
    );

    expect(blocking, contains('Mock login bypass is enabled.'));
    expect(blocking, contains('Global mock mode is enabled.'));
    expect(
      blocking,
      contains('Paywall-disabled development override is enabled.'),
    );
    expect(blocking, contains('Tester full-access override is enabled.'));
    expect(blocking, isNot(contains('Some informational warning.')));
  });
}
