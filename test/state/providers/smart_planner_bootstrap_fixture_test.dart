import 'dart:async';

import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _account = NotifierProvider<_Account, String?>(_Account.new);

void main() {
  test('Smart Planner bootstrap settles for A, signed-out, and B', () async {
    final container = ProviderContainer(
      overrides: [
        extendedDomainBootstrapProvider.overrideWith((Ref ref) async {
          ref.watch(_account);
        }),
      ],
    );
    addTearDown(container.dispose);

    for (final String? account in <String?>['A', null, 'B']) {
      container.read(_account.notifier).set(account);
      await _settleBootstrap(container);
      expect(container.read(_account), account);
    }
  });
}

Future<void> _settleBootstrap(ProviderContainer container) async {
  final completer = Completer<void>();
  late ProviderSubscription<AsyncValue<void>> subscription;
  subscription = container.listen(extendedDomainBootstrapProvider, (_, next) {
    if (next.hasValue && !completer.isCompleted) completer.complete();
    if (next.hasError && !completer.isCompleted) {
      completer.completeError(next.error!, next.stackTrace);
    }
  }, fireImmediately: true);
  try {
    await completer.future.timeout(const Duration(seconds: 2));
  } finally {
    subscription.close();
  }
}

class _Account extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? value) => state = value;
}
