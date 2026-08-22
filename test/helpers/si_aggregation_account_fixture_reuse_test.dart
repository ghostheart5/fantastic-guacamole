import 'dart:async';

import 'package:fantastic_guacamole/state/models/si_pipeline_models.dart';
import 'package:fantastic_guacamole/state/providers/si_pipeline_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'si_aggregation_account_fixture.dart';

void main() {
  test(
    'reusable aggregation fixture resolves account A in another test library',
    () async {
      final fixture = SiAggregationAccountFixture();
      final ProviderContainer container = fixture.createContainer();
      addTearDown(container.dispose);
      fixture.activate('A');
      final SIStateAggregation aggregation = await _readProfile(
        container,
        'A_PROFILE',
      );
      expect(aggregation.profile.name, 'A_PROFILE');
    },
  );
}

Future<SIStateAggregation> _readProfile(
  ProviderContainer container,
  String expectedProfile,
) async {
  final Completer<SIStateAggregation> result = Completer<SIStateAggregation>();
  late ProviderSubscription<AsyncValue<SIStateAggregation>> subscription;
  subscription = container.listen(siStateAggregationProvider, (
    _,
    AsyncValue<SIStateAggregation> next,
  ) {
    if (next.hasValue &&
        next.requireValue.profile.name == expectedProfile &&
        !result.isCompleted) {
      result.complete(next.requireValue);
    } else if (next.hasError && !result.isCompleted) {
      result.completeError(next.error!, next.stackTrace);
    }
  }, fireImmediately: true);
  try {
    return await result.future.timeout(const Duration(seconds: 3));
  } finally {
    subscription.close();
  }
}
