import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/release/assistant_release_control.dart';

/// Offline derivation only. The input must first be matched privately to the
/// intended signed-in Supabase account; this utility does not verify ownership.
void main() {
  if (!stdin.hasTerminal) {
    stderr.writeln(
      'Use an interactive terminal with an already verified account ID.',
    );
    exitCode = 64;
    return;
  }
  stdout.write('Paste the privately verified account ID (input hidden): ');
  final bool previousEcho = stdin.echoMode;
  String? raw;
  try {
    stdin.echoMode = false;
    raw = stdin.readLineSync();
  } finally {
    stdin.echoMode = previousEcho;
    stdout.writeln();
  }
  if (raw == null ||
      !RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(raw)) {
    stderr.writeln(
      'A verified, exact Supabase UUID is required. No value was saved.',
    );
    exitCode = 64;
    return;
  }
  final String digest = assistantReleaseAccountDigest(
    AccountStorageScope.authenticated(raw).v2Namespace!,
  );
  final Map<String, dynamic> policy =
      jsonDecode(
            File(
              'tool/internal_testing_assistant_release.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  policy['assistant_release_internal_account_digests'] = digest;
  final List<String> keys = policy.keys.toList()..sort();
  final String canonical = jsonEncode(<String, dynamic>{
    for (final String key in keys) key: policy[key],
  });
  stdout.writeln('Private cohort input: $digest');
  stdout.writeln(
    'Effective single-account policy SHA256: ${sha256.convert(utf8.encode(canonical))}',
  );
  stdout.writeln(
    'No account ID or digest was saved. Do not put the cohort input in build logs.',
  );
}
