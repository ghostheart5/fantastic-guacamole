import 'package:fantastic_guacamole/state/models/progression_state.dart';
import 'package:fantastic_guacamole/state/providers/progression_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _account = NotifierProvider<_Account, String?>(_Account.new);

void main() {
  test('typed progression override follows A, signed-out, and B', () {
    final ProviderContainer container = ProviderContainer(overrides: [
      progressionProvider.overrideWith((Ref ref) {
        final String? account = ref.watch(_account);
        return account == null
            ? ProgressionState.initial()
            : ProgressionState(
                progress: ProgressionState.initial().progress,
                loading: false,
                error: '${account}_PROGRESSION',
              );
      }),
    ]);
    addTearDown(container.dispose);
    container.read(_account.notifier).set('A');
    expect(container.read(progressionProvider).error, 'A_PROGRESSION');
    container.read(_account.notifier).set(null);
    expect(container.read(progressionProvider).error, isNull);
    container.read(_account.notifier).set('B');
    expect(container.read(progressionProvider).error, 'B_PROGRESSION');
  });
}

class _Account extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? value) => state = value;
}
