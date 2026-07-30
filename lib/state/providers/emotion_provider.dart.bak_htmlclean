import 'dart:async';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/state/state/emotional_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final emotionProvider = NotifierProvider<EmotionNotifier, EmotionalState>(
  EmotionNotifier.new,
);

class EmotionNotifier extends Notifier<EmotionalState> {
  static const String _emotionKey = 'emotion_state_v1';

  @override
  EmotionalState build() {
    Future<void>.microtask(_restore);
    return EmotionalState.neutral;
  }

  void set(EmotionalState value) {
    unawaited(_setPersisted(value));
  }

  Future<void> _setPersisted(EmotionalState value) async {
    final EmotionalState previous = state;
    state = value;
    try {
      await _persist(value);
    } on Object catch (error) {
      if (ref.mounted) {
        state = previous;
      }
      Logger.error('Failed to persist emotion state.', error);
    }
  }

  Future<void> _restore() async {
    await SharedPrefsService.init();
    final String? stored = SharedPrefsService.load(_emotionKey);
    if (stored == null || stored.trim().isEmpty || !ref.mounted) {
      return;
    }
    for (final EmotionalState candidate in EmotionalState.values) {
      if (candidate.name == stored) {
        state = candidate;
        break;
      }
    }
  }

  Future<void> _persist(EmotionalState value) {
    return SharedPrefsService.save(_emotionKey, value.name);
  }
}
