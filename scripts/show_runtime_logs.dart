import 'dart:convert';
import 'dart:io';

import 'package:hive/hive.dart';

Future<void> main(List<String> args) async {
  final int limit = args.isNotEmpty ? int.tryParse(args.first) ?? 25 : 25;
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

  final dynamic raw =
      box.get('runtime_state_v3') ?? box.get('runtime_state_v2');
  if (raw is! String || raw.trim().isEmpty) {
    stdout.writeln('No runtime snapshot found in chronospark_runtime box.');
    await box.close();
    return;
  }

  final Map<String, dynamic> decoded = jsonDecode(raw) as Map<String, dynamic>;
  final List<dynamic> logsRaw =
      decoded['logs'] as List<dynamic>? ?? const <dynamic>[];
  if (logsRaw.isEmpty) {
    stdout.writeln('No log entries in runtime snapshot.');
    await box.close();
    return;
  }

  final List<Map<String, dynamic>> logs = logsRaw
      .whereType<Map<dynamic, dynamic>>()
      .map(
        (Map<dynamic, dynamic> e) =>
            e.map((dynamic k, dynamic v) => MapEntry(k.toString(), v)),
      )
      .toList();

  final Iterable<Map<String, dynamic>> recent = logs.take(limit);

  stdout.writeln(
    'Showing ${recent.length} most recent runtime logs (max $limit):',
  );
  for (final Map<String, dynamic> entry in recent) {
    final String ts = entry['timestamp']?.toString() ?? 'unknown-time';
    final String type = entry['type']?.toString() ?? 'unknown-type';
    final int? statusIndex = (entry['status'] as num?)?.toInt();
    final String status = switch (statusIndex) {
      1 => 'success',
      2 => 'warning',
      3 => 'error',
      _ => 'info',
    };
    final String content = entry['content']?.toString() ?? '';
    stdout.writeln('[$ts] [$type/$status] $content');
  }

  await box.close();
}
