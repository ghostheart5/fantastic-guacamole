import 'package:fantastic_guacamole/state/providers/explainable_si_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _account = NotifierProvider<_Account, String?>(_Account.new);

void main() {
  test('explainable SI is isolated from A through signed-out to B', () {
    final container = ProviderContainer(overrides: [
      explainableSIProvider.overrideWith((Ref ref) => _state(ref.watch(_account))),
    ]);
    addTearDown(container.dispose);
    container.read(_account.notifier).set('A');
    expect(container.read(explainableSIProvider).primaryReason, 'A_EXPLAINABLE_SI');
    container.read(_account.notifier).set(null);
    expect(container.read(explainableSIProvider).primaryReason, 'SIGNED_OUT_EXPLAINABLE_SI');
    container.read(_account.notifier).set('B');
    final value = container.read(explainableSIProvider);
    expect(value.primaryReason, 'B_EXPLAINABLE_SI');
    expect(value.reasons.single.label, 'shared-explanation');
    expect(value.reasons.single.detail, 'B_EXPLAINABLE_SI');
  });
}

ExplainableSIState _state(String? account) {
  final value = account == null ? 'SIGNED_OUT_EXPLAINABLE_SI' : '${account}_EXPLAINABLE_SI';
  return ExplainableSIState(primaryReason: value, recommendation: value, reasons: [ExplainableSIReason(label: 'shared-explanation', detail: value, severity: ExplainableSISeverity.neutral)]);
}

class _Account extends Notifier<String?> { @override String? build() => null; void set(String? value) => state = value; }
