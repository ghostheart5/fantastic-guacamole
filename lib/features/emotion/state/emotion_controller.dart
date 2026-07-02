import 'package:fantastic_guacamole/features/emotion/state/emotion_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EmotionController extends Notifier<EmotionState> {
  @override
  EmotionState build() => EmotionState.initial();
}
