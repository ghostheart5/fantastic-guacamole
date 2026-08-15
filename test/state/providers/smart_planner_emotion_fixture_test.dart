import 'package:fantastic_guacamole/state/providers/emotion_provider.dart';
import 'package:fantastic_guacamole/state/state/emotional_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _account = NotifierProvider<_Account, String?>(_Account.new);

void main() {
  test('emotion is isolated from A through signed-out to B', () {
    final container = ProviderContainer(overrides: [
      emotionProvider.overrideWith(_FixtureEmotionNotifier.new),
    ]);
    addTearDown(container.dispose);
    container.read(_account.notifier).set('A');
    expect(container.read(emotionProvider), EmotionalState.focused);
    container.read(_account.notifier).set(null);
    expect(container.read(emotionProvider), EmotionalState.neutral);
    container.read(_account.notifier).set('B');
    expect(container.read(emotionProvider), EmotionalState.calm);
  });
}

class _Account extends Notifier<String?> { @override String? build() => null; void set(String? value) => state = value; }
class _FixtureEmotionNotifier extends EmotionNotifier { @override EmotionalState build() { switch (ref.watch(_account)) { case 'A': return EmotionalState.focused; case 'B': return EmotionalState.calm; default: return EmotionalState.neutral; } } }
