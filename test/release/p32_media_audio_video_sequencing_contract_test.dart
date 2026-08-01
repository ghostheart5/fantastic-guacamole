import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../behavior/_support/source_test_utils.dart';

void main() {
  group('P3-2 media/audio/video sequencing contract', () {
    test('app assets constants keep animation audio and background anchors', () {
      final File assetsFile = File('lib/ui/constants/app_assets.dart');
      expect(assetsFile.existsSync(), isTrue);

      final String text = SourceTestUtils.readText(assetsFile);

      expect(text.contains('static const animFocusPulse'), isTrue);
      expect(text.contains('static const animLevelUp'), isTrue);
      expect(text.contains('static const animSessionComplete'), isTrue);
      expect(text.contains('static const audioAiDecision'), isTrue);
      expect(text.contains('static const audioErrorSoft'), isTrue);
      expect(text.contains('static const audioFocusStart'), isTrue);
      expect(text.contains('static const audioTaskComplete'), isTrue);
      expect(text.contains('static const bgOnboarding'), isTrue);
      expect(text.contains('static const bgSiConsole'), isTrue);
      expect(text.contains('static const overlayNoise'), isTrue);
    });

    test('audio service keeps cooldown and haptic-safe playback boundaries', () {
      final File audioFile = File('lib/system/audio/audio_service.dart');
      expect(audioFile.existsSync(), isTrue);

      final String text = SourceTestUtils.readText(audioFile);

      expect(text.contains('static const Duration _kCreateCooldown'), isTrue);
      expect(text.contains('static const Duration _kSkipCooldown'), isTrue);
      expect(text.contains('static const Duration _kErrorCooldown'), isTrue);
      expect(text.contains('static const Duration _kReminderCooldown'), isTrue);
      expect(text.contains('static Future<void> _safeHaptic'), isTrue);
      expect(text.contains('playCreate('), isTrue);
      expect(text.contains('playSkip('), isTrue);
      expect(text.contains('playError('), isTrue);
      expect(text.contains('playReminderRoutine('), isTrue);
      expect(text.contains('playReminderDaily('), isTrue);
      expect(text.contains('playMilestone('), isTrue);
      expect(text.contains('playAchievement('), isTrue);
    });

    test('typing effect remains throttled and routed through audio service', () {
      final File typingFile = File('lib/ui/widgets/typing_text.dart');
      expect(typingFile.existsSync(), isTrue);

      final String text = SourceTestUtils.readText(typingFile);

      expect(text.contains('Timer.periodic(widget.step'), isTrue);
      expect(text.contains('AudioService.playTyping();'), isTrue);
      expect(text.contains('_cursorTimer = Timer.periodic'), isTrue);
    });

    test('pubspec keeps declared media packages and core asset declarations', () {
      final File pubspecFile = File('pubspec.yaml');
      expect(pubspecFile.existsSync(), isTrue);

      final String text = SourceTestUtils.readText(pubspecFile);

      expect(text.contains('lottie:'), isTrue);
      expect(text.contains('audioplayers:'), isTrue);
      expect(text.contains('flutter_tts:'), isTrue);
      expect(text.contains('speech_to_text:'), isTrue);
      expect(text.contains('vibration:'), isTrue);
      expect(text.contains('- assets/animations/focus_pulse.json'), isTrue);
      expect(text.contains('- assets/audio/ai_decision.wav'), isTrue);
      expect(text.contains('- assets/audio/error_soft.wav'), isTrue);
      expect(text.contains('- assets/audio/focus_start.wav'), isTrue);
      expect(text.contains('- assets/audio/task_complete.wav'), isTrue);
      expect(text.contains('- assets/backgrounds/'), isTrue);
    });
  });
}
