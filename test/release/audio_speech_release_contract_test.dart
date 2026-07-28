import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../behavior/_support/source_test_utils.dart';

void main() {
  group('Audio speech release contract', () {
    test('audio and speech dependencies have source boundaries', () {
      final String pubspec = SourceTestUtils.readText(File('pubspec.yaml')).toLowerCase();
      final bool hasAudioDeps = pubspec.contains('audio_session') || pubspec.contains('just_audio') || pubspec.contains('audioplayers');
      final bool hasSpeechDeps = pubspec.contains('speech_to_text') || pubspec.contains('flutter_tts');

      if (!hasAudioDeps && !hasSpeechDeps) {
        return;
      }

      final String libText = SourceTestUtils.readAllConcatenated('lib').toLowerCase();

      if (hasAudioDeps) {
        expect(libText.contains('audio_session') || libText.contains('audioservice') || libText.contains('voice_service'), isTrue);
      }

      if (hasSpeechDeps) {
        expect(libText.contains('speech_to_text') || libText.contains('flutter_tts') || libText.contains('voice'), isTrue);
        expect(libText.contains('permission'), isTrue, reason: 'Speech/TTS deps found but permission rationale path not found.');
      }
    });

    test('widgets do not create uncancelled audio or speech loops in build', () {
      final List<String> offenders = <String>[];
      for (final File file in SourceTestUtils.dartFilesUnder('lib')) {
        final String path = SourceTestUtils.normalizePath(file.path).toLowerCase();
        if (!path.contains('/ui/') && !path.contains('/widgets/')) {
          continue;
        }

        final String text = SourceTestUtils.readText(file);
        final int buildIndex = text.indexOf('Widget build(');
        if (buildIndex < 0) {
          continue;
        }

        final String buildBody = text.substring(buildIndex).toLowerCase();
        if (buildBody.contains('speech_to_text') || buildBody.contains('flutter_tts') || buildBody.contains('audio_player') || buildBody.contains('justaudio')) {
          offenders.add(path);
        }
      }

      expect(offenders, isEmpty, reason: 'Audio/speech objects should not be instantiated in build: $offenders');
    });
  });
}
