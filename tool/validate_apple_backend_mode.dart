import 'dart:convert';
import 'dart:io';

import 'package:fantastic_guacamole/config/backend_mode.dart';

/// Apple native plugins can initialize Firebase before Dart application code.
/// Until equivalent native isolation is supported, only cloud Apple builds are
/// permitted. Android has its own mode-linked native registration boundary.
String? appleBackendModeIssue(String encodedDefines) {
  String? configuredMode;
  try {
    for (final String entry in encodedDefines.split(',')) {
      if (entry.isEmpty) continue;
      final String decoded = utf8.decode(base64.decode(entry));
      final int separator = decoded.indexOf('=');
      if (separator <= 0) {
        return 'Invalid Flutter DART_DEFINES entry; expected KEY=VALUE.';
      }
      if (decoded.substring(0, separator) != 'CHRONOSPARK_BACKEND_MODE') {
        continue;
      }
      final String value = decoded.substring(separator + 1);
      if (configuredMode != null && configuredMode != value) {
        return 'Conflicting CHRONOSPARK_BACKEND_MODE values.';
      }
      configuredMode = value;
    }
  } on FormatException {
    return 'Invalid base64 or UTF-8 in Flutter DART_DEFINES.';
  }

  return switch (BackendConfiguration.parse(configuredMode ?? 'cloud')) {
    BackendMode.cloud => null,
    BackendMode.local =>
      'Local production currently supports Android only. Apple native service isolation is not implemented; this build is blocked before Firebase registration.',
    null => 'CHRONOSPARK_BACKEND_MODE must be cloud or local.',
  };
}

void main() {
  final String? issue = appleBackendModeIssue(
    Platform.environment['DART_DEFINES'] ?? '',
  );
  if (issue != null) {
    stderr.writeln('error: $issue');
    exitCode = 1;
  }
}
