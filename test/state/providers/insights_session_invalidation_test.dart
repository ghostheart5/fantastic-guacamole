import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/state/models/insight_model.dart';
import 'package:fantastic_guacamole/state/models/insights_models.dart';
import 'package:fantastic_guacamole/state/providers/identity_account_provider.dart';
import 'package:fantastic_guacamole/state/providers/insights_provider.dart';
import 'package:fantastic_guacamole/state/services/insights_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _invalidateInsightsForTestProvider = Provider<void>((Ref ref) {
  invalidateInsightsSessionState(ref);
});

void main() {
  test('invalidation clears derived session state, repeats safely, and allows B rebuild', () {
    final _CountingInsightsService service = _CountingInsightsService();
    final ProviderContainer container = ProviderContainer(
      overrides: [insightsServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    expect(container.read(insightsBundleProvider).summary, 'derived-1');
    container.read(identityAccountProvider.notifier).synchronizeAuthenticatedUser(
      const User(id: 'user-a', emailVerified: false),
    );
    container.read(_invalidateInsightsForTestProvider);
    expect(container.read(insightsBundleProvider).summary, 'derived-2');
    container.invalidate(_invalidateInsightsForTestProvider);
    container.read(_invalidateInsightsForTestProvider);
    expect(container.read(insightsBundleProvider).summary, 'derived-3');
    container.read(identityAccountProvider.notifier).synchronizeAuthenticatedUser(
      const User(id: 'user-b', emailVerified: false),
    );
    expect(container.read(identityAccountProvider)!.id, 'user-b');
    expect(service.buildCount, 3);
  });
}

class _CountingInsightsService extends InsightsService {
  int buildCount = 0;

  @override
  InsightsBundle build(SIState state) {
    buildCount++;
    return InsightsBundle(
      items: const <Insight>[],
      summary: 'derived-$buildCount',
      healthScore: 0.5,
    );
  }
}
