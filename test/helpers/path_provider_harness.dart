import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Installs an in-memory `path_provider` for tests that exercise real storage.
///
/// Several chain-level tests drive the real repositories, which reach Hive and
/// therefore `path_provider`. Without a platform implementation that throws
/// `MissingPluginException`, which is why these tests previously only ran on a
/// device — and, because CI never ran them, they failed silently for a long
/// time. Mocking the channel lets them run headless in the normal suite.
///
/// Call from `setUp`; the temp directory is cleaned up automatically.
void useTemporaryPathProvider() {
  late Directory directory;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    directory = await Directory.systemTemp.createTemp('chronospark_test_');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall call) async => directory.path,
        );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );

    if (await directory.exists()) {
      try {
        await directory.delete(recursive: true);
      } on FileSystemException {
        // Best effort. On Windows an open Hive box can still hold a handle
        // when the test ends, and failing cleanup here would mask the real
        // result of the test. The OS reclaims the temp directory anyway.
      }
    }
  });
}
