import 'package:fantastic_guacamole/state/models/si_pipeline_models.dart';
import 'package:fantastic_guacamole/state/providers/si_pipeline_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'si_aggregation_account_fixture.dart';

void main() {
  test('reusable aggregation fixture resolves account A in another test library', () async {
    final fixture = SiAggregationAccountFixture();
    final ProviderContainer container = fixture.createContainer();
    addTearDown(container.dispose);
    fixture.activate('A');
    final SIStateAggregation aggregation = await container.read(siStateAggregationProvider.future);
    expect(aggregation.profile.name, 'A_PROFILE');
  });
}
