import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract class AudioInterruptionService {
  Future<void> start({
    required Future<void> Function() onInterruptionBegin,
    required Future<void> Function() onBecomingNoisy,
  });

  Future<void> stop();
}

class PluginAudioInterruptionService implements AudioInterruptionService {
  StreamSubscription<AudioInterruptionEvent>? _interruptionSubscription;
  StreamSubscription<void>? _becomingNoisySubscription;

  @override
  Future<void> start({
    required Future<void> Function() onInterruptionBegin,
    required Future<void> Function() onBecomingNoisy,
  }) async {
    try {
      final AudioSession session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.speech());
      _interruptionSubscription = session.interruptionEventStream.listen((
        AudioInterruptionEvent event,
      ) {
        if (event.begin) {
          unawaited(onInterruptionBegin());
        }
      });
      _becomingNoisySubscription = session.becomingNoisyEventStream.listen((_) {
        unawaited(onBecomingNoisy());
      });
    } on MissingPluginException {
      // No audio session support in this environment (e.g. flutter test).
    } on PlatformException catch (error) {
      debugPrint('AudioInterruptionService unavailable: $error');
    } catch (_) {
      // Never let interruption-listener setup crash app startup.
    }
  }

  @override
  Future<void> stop() async {
    await _interruptionSubscription?.cancel();
    await _becomingNoisySubscription?.cancel();
    _interruptionSubscription = null;
    _becomingNoisySubscription = null;
  }
}
