import 'package:fantastic_guacamole/state/providers/identity_evolution_provider.dart';
import 'package:fantastic_guacamole/state/providers/memory_intelligence_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MemoryGraphNode {
  const MemoryGraphNode({
    required this.title,
    required this.type,
    required this.connection,
  });

  final String title;
  final String type;
  final String connection;
}

class MemoryGraphState {
  const MemoryGraphState({required this.nodes});

  final List<MemoryGraphNode> nodes;
}

final memoryGraphProvider = Provider<MemoryGraphState>((ref) {
  final memory = ref.watch(memoryIntelligenceProvider);
  final evolution = ref.watch(identityEvolutionProvider);

  return MemoryGraphState(
    nodes: <MemoryGraphNode>[
      MemoryGraphNode(
        title: memory.recurringWin,
        type: 'win',
        connection: evolution.trait,
      ),
      MemoryGraphNode(
        title: memory.recurringFriction,
        type: 'friction',
        connection: evolution.stage,
      ),
      MemoryGraphNode(
        title: memory.lesson,
        type: 'lesson',
        connection: evolution.nextEvolution,
      ),
      MemoryGraphNode(
        title: memory.focusSuggestion,
        type: 'focus',
        connection: evolution.trait,
      ),
    ],
  );
});
