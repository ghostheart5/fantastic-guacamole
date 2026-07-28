import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app entrypoint boots through AppBootstrapper', () {
    final String mainSource = File('lib/main.dart').readAsStringSync();
    expect(mainSource, contains('AppBootstrapper'));
    expect(mainSource, contains('.run()'));
  });

  test('navigation shell exposes a nexus default view', () {
    final String navigationSource = File(
      'lib/app/navigation_shell.dart',
    ).readAsStringSync();
    expect(navigationSource, contains('initialView = AppView.nexus'));
  });
}
