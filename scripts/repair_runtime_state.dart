import 'dart:convert';
import 'dart:io';

import 'package:hive/hive.dart';

Map<String, dynamic>? _decodeIfValid(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  try {
    final dynamic decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map(
        (dynamic k, dynamic v) => MapEntry(k.toString(), v),
      );
    }
  } catch (_) {
    // Try salvage path below.
  }
  return null;
}

List<String> _extractBalancedJsonObjects(String raw) {
  final List<String> out = <String>[];
  int depth = 0;
  int start = -1;
  bool inString = false;
  bool escaped = false;

  for (int i = 0; i < raw.length; i++) {
    final String ch = raw[i];

    if (escaped) {
      escaped = false;
      continue;
    }

    if (ch == r'\' && inString) {
      escaped = true;
      continue;
    }

    if (ch == '"') {
      inString = !inString;
      continue;
    }

    if (inString) continue;

    if (ch == '{') {
      if (depth == 0) start = i;
      depth++;
    } else if (ch == '}') {
      if (depth > 0) {
        depth--;
        if (depth == 0 && start >= 0) {
          out.add(raw.substring(start, i + 1));
          start = -1;
        }
      }
    }
  }

  return out;
}

Map<String, dynamic>? _bestCandidateFromCorrupt(String raw) {
  final List<String> candidates = _extractBalancedJsonObjects(raw);
  Map<String, dynamic>? best;
  int bestScore = -1;

  for (final String c in candidates) {
    final Map<String, dynamic>? decoded = _decodeIfValid(c);
    if (decoded == null) continue;

    int score = 0;
    if (decoded.containsKey('schemaVersion')) score += 2;
    if (decoded.containsKey('tasks')) score += 2;
    if (decoded.containsKey('logs')) score += 2;
    final List<dynamic> logs = decoded['logs'] as List<dynamic>? ?? <dynamic>[];
    score += logs.length;

    if (score > bestScore) {
      bestScore = score;
      best = decoded;
    }
  }

  return best;
}

Future<void> main() async {
  final String userProfile = Platform.environment['USERPROFILE'] ?? '';
  if (userProfile.isEmpty) {
    stderr.writeln('USERPROFILE is not set.');
    exitCode = 1;
    return;
  }

  final String documentsPath = '$userProfile\\Documents';
  Hive.init(documentsPath);

  late final Box<dynamic> box;
  try {
    box = await Hive.openBox<dynamic>('chronospark_runtime');
  } catch (error) {
    stderr.writeln('Failed to open Hive box chronospark_runtime: $error');
    exitCode = 1;
    return;
  }

  final dynamic rawPrimary = box.get('runtime_state_v3');
  final dynamic rawBackup = box.get('runtime_state_v3_backup');

  Map<String, dynamic>? recovered;
  String recoveredFrom = 'none';

  if (rawPrimary is String) {
    recovered = _decodeIfValid(rawPrimary) ?? _bestCandidateFromCorrupt(rawPrimary);
    if (recovered != null) recoveredFrom = 'runtime_state_v3';
  }

  if (recovered == null && rawBackup is String) {
    recovered = _decodeIfValid(rawBackup) ?? _bestCandidateFromCorrupt(rawBackup);
    if (recovered != null) recoveredFrom = 'runtime_state_v3_backup';
  }

  if (recovered == null) {
    stderr.writeln('No recoverable runtime snapshot found in primary or backup state.');
    await box.close();
    exitCode = 1;
    return;
  }

  final String cleaned = jsonEncode(recovered);
  await box.put('runtime_state_v3', cleaned);
  await box.put('runtime_state_v3_backup', cleaned);

  final List<dynamic> logs = recovered['logs'] as List<dynamic>? ?? <dynamic>[];
  stdout.writeln('Recovered runtime snapshot from $recoveredFrom.');
  stdout.writeln('Schema: ${recovered['schemaVersion']}, tasks: ${(recovered['tasks'] as List<dynamic>? ?? <dynamic>[]).length}, logs: ${logs.length}');
  stdout.writeln('Saved cleaned snapshot to runtime_state_v3 and runtime_state_v3_backup.');

  await box.close();
}
