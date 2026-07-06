// lib/engine/si/si_synthetic_memory_echo_layer.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/si_synthetic_memory_topology.dart';

class MemoryEcho {
  const MemoryEcho({
    required this.content,
    required this.echoStrength,
    required this.matches,
    required this.reason,
  });

  final String content;
  final double echoStrength;
  final List<MemoryRecord> matches;
  final String reason;
}

class MemoryEchoResult {
  const MemoryEchoResult({
    required this.echoes,
    required this.primaryEcho,
    required this.memory,
  });

  final List<MemoryEcho> echoes;
  final MemoryEcho? primaryEcho;
  final SIMemoryStore memory;
}

class SISyntheticMemoryEchoLayer {
  const SISyntheticMemoryEchoLayer();

  MemoryEchoResult detect({
    required SIMemoryStore memory,
    required SIContext context,
    MemoryTopology? topology,
    DateTime? now,
  }) {
    final DateTime t = now ?? DateTime.now();
    final String input = siClean(context.input.text).toLowerCase();
    final List<MemoryRecord> records = <MemoryRecord>[
      ...memory.tiered.shortTerm,
      ...memory.tiered.midTerm,
      ...memory.tiered.longTerm,
    ];

    final List<MemoryEcho> echoes = <MemoryEcho>[];

    for (final MemoryRecord r in records.take(80)) {
      final double lexical = _lexical(input, r.content);
      final double topologyBoost = _topologyBoost(r, topology);
      final double strength = siClamp01(
        (lexical * 0.65) + (r.score(t) * 0.25) + (topologyBoost * 0.1),
      );
      if (strength >= 0.38) {
        echoes.add(
          MemoryEcho(
            content: r.content,
            echoStrength: strength,
            matches: <MemoryRecord>[r],
            reason: 'Similar recent/meaningful memory surfaced.',
          ),
        );
      }
    }

    echoes.sort(
      (MemoryEcho a, MemoryEcho b) => b.echoStrength.compareTo(a.echoStrength),
    );
    final MemoryEcho? primary = echoes.isEmpty ? null : echoes.first;

    final SIMemoryStore nextMemory = memory
        .pushRecord(
          MemoryTier.shortTerm,
          MemoryRecord(
            content:
                'memory_echo|count=${echoes.length}|primary=${primary?.content ?? 'none'}',
            timestamp: t,
            relevance: primary?.echoStrength ?? 0.2,
            confidence: primary == null ? 0.35 : 0.68,
            emotionalWeight: siClamp01(context.userState.stress),
            reinforcement: primary != null ? 1 : 0,
          ),
        )
        .dedupe()
        .decay(t);

    return MemoryEchoResult(
      echoes: List<MemoryEcho>.unmodifiable(echoes.take(8)),
      primaryEcho: primary,
      memory: nextMemory,
    );
  }

  String applyEchoHint(String message, MemoryEcho? echo) {
    if (echo == null || echo.echoStrength < 0.55) return siClean(message);
    return '${siClean(message)}\n\nThis connects to a recent pattern: ${_short(echo.content)}';
  }

  double _lexical(String a, String b) {
    final Set<String> x = a
        .split(RegExp(r'[^a-z0-9_]+'))
        .where((String s) => s.length > 3)
        .toSet();
    final Set<String> y = b
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9_]+'))
        .where((String s) => s.length > 3)
        .toSet();
    if (x.isEmpty || y.isEmpty) return 0;
    return siClamp01(x.intersection(y).length / x.union(y).length);
  }

  double _topologyBoost(MemoryRecord record, MemoryTopology? topology) {
    if (topology == null) return 0;
    final String content = record.content.toLowerCase();
    final bool linked = topology.nodes.values.any(
      (MemoryNode n) => content.contains(n.label.toLowerCase()),
    );
    return linked ? 0.5 : 0;
  }

  String _short(String value) {
    final String clean = siClean(value);
    return clean.length <= 96 ? clean : '${clean.substring(0, 93)}...';
  }
}
