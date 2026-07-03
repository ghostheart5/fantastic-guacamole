import 'package:fantastic_guacamole/features/emotion/emotional_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final emotionProvider = NotifierProvider<EmotionNotifier, EmotionalState>(
  EmotionNotifier.new,
);

class EmotionNotifier extends Notifier<EmotionalState> {
  @override
  EmotionalState build() => EmotionalState.neutral;

  void set(EmotionalState value) => state = value;
}
