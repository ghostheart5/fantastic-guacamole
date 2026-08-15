import 'feature_context_account_fixture.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _accountProvider = NotifierProvider<_AccountNotifier, String?>(
  _AccountNotifier.new,
);

final _sharedContextProvider = FutureProvider<List<String>>((Ref ref) async {
  final String? account = ref.watch(_accountProvider);
  if (account == null) return const <String>[];
  return <String>[
    FeatureContextAccountFixture.sentinel(account, 'TASK'),
    FeatureContextAccountFixture.sentinel(account, 'PROFILE'),
    FeatureContextAccountFixture.sentinel(account, 'TRAJECTORY'),
  ];
});

void main() {
  test('shared feature context resolves A, clears signed-out, then resolves B',
      () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(_accountProvider.notifier).set('A');
    final List<String> a = await listenUntilData(
      container,
      _sharedContextProvider,
      accept: (List<String> value) => value.contains('A_TASK'),
    );
    expect(a, containsAll(<String>['A_TASK', 'A_PROFILE', 'A_TRAJECTORY']));

    container.read(_accountProvider.notifier).set(null);
    final List<String> signedOut = await listenUntilData(
      container,
      _sharedContextProvider,
      accept: (List<String> value) => value.isEmpty,
    );
    expect(signedOut, isEmpty);

    container.read(_accountProvider.notifier).set('B');
    final List<String> b = await listenUntilData(
      container,
      _sharedContextProvider,
      accept: (List<String> value) => value.contains('B_TASK'),
    );
    expect(b, containsAll(<String>['B_TASK', 'B_PROFILE', 'B_TRAJECTORY']));
    expectNoForeignAccountContext(b, currentAccount: 'B');
  });
}

class _AccountNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? account) => state = account;
}
