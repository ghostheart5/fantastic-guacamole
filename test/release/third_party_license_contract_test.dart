import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final manifest = loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
  final lock = loadYaml(File('pubspec.lock').readAsStringSync()) as YamlMap;
  final flutterManifest = manifest['flutter'] as YamlMap;
  final packages = lock['packages'] as YamlMap;
  final licenses = (flutterManifest['licenses'] as YamlList).cast<String>();
  const archivePath =
      'assets/legal/licenses/archive-4.1.0-third-party-notices.txt';
  const imagePath = 'assets/legal/licenses/image-4.9.2-third-party-notices.txt';
  const sourcePath =
      'assets/legal/licenses/fallback-root-certificates-source.txt';
  const platformPath = 'assets/legal/licenses/platform-components-source.txt';
  const interPath = 'assets/legal/licenses/inter-font-OFL.txt';
  const spaceGroteskPath = 'assets/legal/licenses/space-grotesk-font-OFL.txt';
  const jetBrainsMonoPath = 'assets/legal/licenses/jetbrains-mono-font-OFL.txt';
  const materialIconsPath =
      'assets/legal/licenses/material-icons-sdk-notice.txt';

  test('declared additional notices are readable labeled UTF-8 documents', () {
    expect(
      licenses,
      containsAll([
        archivePath,
        imagePath,
        sourcePath,
        platformPath,
        interPath,
        spaceGroteskPath,
        jetBrainsMonoPath,
        materialIconsPath,
      ]),
    );
    expect(licenses.toSet().length, licenses.length);
    for (final path in licenses) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: path);
      final text = utf8.decode(file.readAsBytesSync());
      final sections = text.split('\n\n');
      expect(sections.first.trim(), isNotEmpty, reason: path);
      expect(sections.length, greaterThan(1), reason: path);
      expect(sections.skip(1).join('\n\n').trim(), isNotEmpty, reason: path);
    }
  });

  test(
    'Flutter collected every complete additional notice into NOTICES.Z',
    () async {
      final asset = await rootBundle.load('NOTICES.Z');
      final bundledText = utf8.decode(
        gzip.decode(
          asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes),
        ),
      );
      for (final path in licenses) {
        expect(
          bundledText,
          contains(File(path).readAsStringSync()),
          reason: path,
        );
      }
    },
  );

  test(
    'archive runtime notices retain the reviewed upstream body verbatim',
    () {
      expect((packages['archive'] as YamlMap)['version'], '4.1.0');
      final bytes = File(archivePath).readAsBytesSync();
      const label = 'archive (additional third-party notices)\n\n';
      expect(utf8.decode(bytes), startsWith(label));
      final body = bytes.sublist(utf8.encode(label).length);
      expect(
        sha256.convert(body).toString(),
        'ebe5a199af245d7e3e761673fbf3db341427060407e50713861ab24bb2cb1552',
      );
      final text = utf8.decode(body);
      expect(text, contains('The MIT License'));
      expect(text, contains('ymnk, JCraft,Inc.'));
      expect(text, contains('Redistributions in binary form must reproduce'));
      expect(text, contains('Julian R Seward'));
      expect(text, contains('Altered source versions must be plainly marked'));
      expect(text, contains('The Legion of the Bouncy Castle Inc.'));
    },
  );

  test('image tooling notices retain the reviewed upstream body verbatim', () {
    expect((packages['image'] as YamlMap)['version'], '4.9.2');
    final bytes = File(imagePath).readAsBytesSync();
    const label = 'image (build tooling notices)\n\n';
    expect(utf8.decode(bytes), startsWith(label));
    final body = bytes.sublist(utf8.encode(label).length);
    expect(
      sha256.convert(body).toString(),
      'dea0e9e446e57c0987d241d5471e47e7b66796fb286706ec993c3fa6696cb08e',
    );
    final text = utf8.decode(body);
    expect(text, contains('Apache License, Version 2.0'));
    expect(text, contains('notmasteryet'));
    expect(text, contains('PvrTcCompressor'));
    expect(text, contains('QuickPVR'));
    expect(text, contains('Redistributions in binary form must reproduce'));
  });

  test(
    'certificate source availability identifies the exact bundled SDK source',
    () {
      final text = File(sourcePath).readAsStringSync();
      expect(
        text,
        startsWith('fallback_root_certificates (source availability)\n\n'),
      );
      expect(text, contains('Flutter 3.44.6 / Dart 3.12.2'));
      expect(text, contains('Mozilla Public License 2.0'));
      expect(
        text,
        contains(
          'https://github.com/dart-lang/sdk/tree/d684a576a6aa954ae107a03b2b4e1d61c3bebe93/third_party/fallback_root_certificates',
        ),
      );
      expect(text, contains('does not change the license of ChronoSpark'));
    },
  );

  test(
    'platform component source notices match the resolved package versions',
    () {
      final text = File(platformPath).readAsStringSync();
      for (final entry in const {
        'dbus': '0.7.15',
        'nm': '0.5.0',
        'gtk': '2.2.0',
      }.entries) {
        expect((packages[entry.key] as YamlMap)['version'], entry.value);
        expect(text, contains('${entry.key} ${entry.value} (MPL 2.0)'));
        expect(
          text,
          contains(
            'https://pub.dev/api/archives/${entry.key}-${entry.value}.tar.gz',
          ),
        );
      }
      expect(
        text,
        contains('does not establish executable inclusion on every target'),
      );
      expect(text, contains('does not change the license of ChronoSpark'));
    },
  );

  test(
    'shipped Inter fonts retain the complete pinned upstream OFL notice',
    () {
      final bytes = File(interPath).readAsBytesSync();
      const label = 'Inter (font license)\n\n';
      expect(utf8.decode(bytes), startsWith(label));
      final body = bytes.sublist(utf8.encode(label).length);
      expect(
        sha256.convert(body).toString(),
        '262481e844521b326f5ecd053e59b98c8b2da78c8ee1bdbb6e8174305e54935a',
      );
      expect(utf8.decode(body), contains('SIL OPEN FONT LICENSE Version 1.1'));
      expect(utf8.decode(body), contains('2016 The Inter Project Authors'));
      for (final font in [
        'Inter-Regular.ttf',
        'Inter-Medium.ttf',
        'Inter-Bold.ttf',
      ]) {
        expect(File('assets/fonts/$font').existsSync(), isTrue);
      }
    },
  );

  for (final font in [
    (
      name: 'Space Grotesk',
      notice: spaceGroteskPath,
      source: 'assets/fonts/LICENSE-SpaceGrotesk-OFL.txt',
      asset: 'assets/fonts/SpaceGrotesk-Variable.ttf',
      digest:
          'c6dec685825f73b18c20926fddc65e8315642e12986f15db0699170940a09efc',
    ),
    (
      name: 'JetBrains Mono',
      notice: jetBrainsMonoPath,
      source: 'assets/fonts/LICENSE-JetBrainsMono-OFL.txt',
      asset: 'assets/fonts/JetBrainsMono-Variable.ttf',
      digest:
          'b2fe5e8987594e9ffd1d2ca52a2f5d73eb8335243893c5d6254b5ad69269591d',
    ),
  ]) {
    test('shipped ${font.name} retains its complete reviewed OFL notice', () {
      final bytes = File(font.notice).readAsBytesSync();
      final label = '${font.name} (font license)\n\n';
      expect(utf8.decode(bytes), startsWith(label));
      final body = bytes.sublist(utf8.encode(label).length);
      expect(sha256.convert(body).toString(), font.digest);
      expect(body, File(font.source).readAsBytesSync());
      expect(utf8.decode(body), contains('SIL OPEN FONT LICENSE Version 1.1'));
      expect(
        utf8.decode(body),
        contains('2020 The ${font.name} Project Authors'),
      );
      expect(flutterManifest['assets'], contains(font.asset));
      expect(File(font.asset).existsSync(), isTrue);
    });
  }

  test(
    'Material Icons retains its accompanying SDK notice and attribution',
    () {
      final bytes = File(materialIconsPath).readAsBytesSync();
      final text = utf8.decode(bytes);
      expect(text, startsWith('Material Icons (SDK font notice)\n\n'));
      expect(text, contains('Copyright 2019 Google LLC. All Rights Reserved.'));
      expect(
        text,
        contains('Source: https://github.com/google/material-design-icons'),
      );
      expect(text, contains('Distributed with Flutter 3.44.6.'));
      expect(
        text,
        contains('may subset the font to the glyphs used by the app'),
      );
      expect(
        text,
        contains(
          'https://github.com/google/material-design-icons/blob/master/LICENSE',
        ),
      );
      const bodyMarker = 'Attribution 4.0 International';
      final body = utf8.encode(text.substring(text.indexOf(bodyMarker)));
      expect(
        sha256.convert(body).toString(),
        'be698262aecd042c0de6f886cc0af622f8def446462026992cc530275d8a9e74',
      );
      expect(text, contains('Creative Commons Attribution 4.0 International'));
      expect(flutterManifest['uses-material-design'], isTrue);
    },
  );
}
