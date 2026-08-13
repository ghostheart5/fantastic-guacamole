import 'package:fantastic_guacamole/state/providers/insights_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Insights provider graph loads without an uncommitted production overlay', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(insightsBundleProvider).summary, isNotEmpty);
  });
}
