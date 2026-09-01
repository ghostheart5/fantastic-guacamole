// ignore_for_file: deprecated_member_use_from_same_package

import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/engine/si/ai_response.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_ecosystem_layer.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_evolution_timeline.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_micro_pattern_engine.dart';
import 'package:fantastic_guacamole/engine/si/si_engine.dart';
import 'package:fantastic_guacamole/engine/si/synthetic_intelligence_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 8, 19, 15);

  group('SICognitiveMicroPatternEngine', () {
    const SICognitiveMicroPatternEngine engine =
        SICognitiveMicroPatternEngine();

    test('reports empty evidence honestly when history is insufficient', () {
      final MicroPatternReport report = engine.detect(
        context: _context(),
        memory: const SIMemoryStore(),
      );

      expect(report.patterns, isEmpty);
      expect(report.predictionSignals, isEmpty);
      expect(report.hasStrongPattern, isFalse);
      expect(report.summary, 'No strong micro-patterns detected yet.');
    });

    test(
      'derives momentum, fatigue, affinity, topics, and load from evidence',
      () {
        final SIMemoryStore memory = SIMemoryStore(
          snapshots: <SISnapshot>[
            _snapshot(now, completed: 2, skipped: 0, taskId: 'deep-work'),
            _snapshot(
              now.subtract(const Duration(hours: 1)),
              completed: 2,
              skipped: 0,
              taskId: 'deep-work',
            ),
            _snapshot(
              now.subtract(const Duration(hours: 2)),
              completed: 1,
              skipped: 0,
              taskId: 'deep-work',
            ),
          ],
          tiered: SITieredMemory(
            shortTerm: <MemoryRecord>[
              _record('planning review planning', now),
              _record('planning checklist planning', now),
            ],
          ),
        );

        final MicroPatternReport report = engine.detect(
          context: _context(load: 0.9, stress: 0.8),
          memory: memory,
        );

        expect(
          report.patterns.map((MicroPattern value) => value.type),
          containsAll(<MicroPatternType>[
            MicroPatternType.completionMomentum,
            MicroPatternType.fatigueDrift,
            MicroPatternType.taskAffinity,
            MicroPatternType.repeatedTopic,
            MicroPatternType.highLoadLoop,
          ]),
        );
        expect(report.predictionSignals['momentum_bias'], greaterThan(0));
        expect(report.predictionSignals['fatigue_bias'], greaterThan(0));
        expect(report.predictionSignals['task:deep-work'], 1);
        expect(report.predictionSignals['topic:planning'], greaterThan(0));
        expect(report.predictionSignals['load_risk'], greaterThan(0));
        expect(report.hasStrongPattern, isTrue);
        expect(
          report.patterns.first.toJson()['strength'],
          inInclusiveRange(0, 1),
        );

        final SIMemoryStore updated = engine.writeToMemory(
          memory: memory,
          report: report,
          now: now,
        );
        expect(updated.tiered.midTerm, isNotEmpty);
        expect(updated.tiered.midTerm.first.content, startsWith('pattern|'));
      },
    );

    test('distinguishes resistance and a stable attention window', () {
      final MicroPatternReport report = engine.detect(
        context: _context(
          load: 0.3,
          stress: 0.2,
          engagement: 0.85,
          fatigue: 0.2,
        ),
        memory: SIMemoryStore(
          snapshots: <SISnapshot>[
            _snapshot(now, completed: 0, skipped: 2, energy: 0.9, fatigue: 0.1),
            _snapshot(
              now.subtract(const Duration(hours: 1)),
              completed: 0,
              skipped: 2,
              energy: 0.9,
              fatigue: 0.1,
            ),
          ],
        ),
      );

      expect(
        report.patterns.map((MicroPattern value) => value.type),
        containsAll(<MicroPatternType>[
          MicroPatternType.skipResistance,
          MicroPatternType.stableAttention,
        ]),
      );
      expect(report.predictionSignals['resistance_bias'], greaterThan(0));
      expect(report.predictionSignals['attention_bias'], greaterThan(0));
    });
  });

  group('SICognitiveEcosystemLayer', () {
    const SICognitiveEcosystemLayer layer = SICognitiveEcosystemLayer();

    test('links mood, state, intent, action, task, and evidence patterns', () {
      const SIIntent intent = SIIntent(
        primary: IntentCandidate(label: 'plan', score: 0.8, why: 'request'),
        predictedNext: 'execute',
        chain: <String>['plan', 'execute'],
      );
      final SIDecision decision = SIDecision(
        action: 'schedule',
        task: Task(
          id: 'task-1',
          title: 'Write proposal',
          priority: 4,
          difficulty: 3,
          energyRequired: 3,
        ),
        score: 0.84,
        reasoning: 'Matches the stated goal.',
        ethics: const EthicsAssessment(
          safe: true,
          flags: <String>[],
          adjustments: <String>[],
        ),
        policyApplied: true,
      );
      const MicroPatternReport patterns = MicroPatternReport(
        patterns: <MicroPattern>[
          MicroPattern(
            type: MicroPatternType.completionMomentum,
            label: 'Completion momentum is forming',
            strength: 0.8,
            confidence: 0.7,
            evidence: <String>['completed=4'],
          ),
        ],
        predictionSignals: <String, double>{'momentum_bias': 0.8},
        summary: 'Completion momentum is forming',
      );

      final EcosystemUpdate first = layer.observe(
        current: const SIEcosystemState(),
        memory: const SIMemoryStore(),
        context: _context(stress: 0.5),
        intent: intent,
        decision: decision,
        patterns: patterns,
        now: now,
      );

      expect(first.state.nodes, hasLength(6));
      expect(first.state.edges, hasLength(5));
      expect(
        first.attentionNodes.first.label,
        'Completion momentum is forming',
      );
      expect(
        first.attentionNodes.map((EcosystemNode value) => value.label),
        contains('Write proposal'),
      );
      expect(first.summary, contains('Active ecosystem nodes'));
      expect(
        first.memory.tiered.midTerm.single.content,
        startsWith('ecosystem|'),
      );

      final EcosystemUpdate second = layer.observe(
        current: first.state,
        memory: first.memory,
        context: _context(stress: 0.5),
        intent: intent,
        decision: decision,
        patterns: patterns,
        now: now.add(const Duration(minutes: 5)),
      );

      expect(second.state.node('task:write proposal')!.hits, 2);
      expect(
        second.state.edges['action:schedule->task:write proposal']!.hits,
        2,
      );

      final EcosystemNode decayedNode = second.state.nodes.values.first.decay(
        now.add(const Duration(days: 1)),
        0.2,
      );
      final EcosystemEdge decayedEdge = second.state.edges.values.first.decay(
        now.add(const Duration(days: 1)),
        0.2,
      );
      expect(decayedNode.hits, second.state.nodes.values.first.hits);
      expect(
        decayedNode.weight,
        lessThan(second.state.nodes.values.first.weight),
      );
      expect(decayedEdge.hits, second.state.edges.values.first.hits);
      expect(decayedEdge.id, '${decayedEdge.from}->${decayedEdge.to}');
    });
  });

  group('SICognitiveEvolutionTimelineEngine', () {
    const SICognitiveEvolutionTimelineEngine engine =
        SICognitiveEvolutionTimelineEngine();

    test(
      'records regression, pattern, ecosystem, and safe milestone evidence',
      () {
        const MicroPatternReport patterns = MicroPatternReport(
          patterns: <MicroPattern>[
            MicroPattern(
              type: MicroPatternType.highLoadLoop,
              label: 'High-load loop detected',
              strength: 0.86,
              confidence: 0.7,
              evidence: <String>['load=0.90'],
            ),
          ],
          predictionSignals: <String, double>{'load_risk': 0.86},
          summary: 'High-load loop detected',
        );
        const SIDecision decision = SIDecision(
          action: 'reduce_scope',
          score: 0.9,
          reasoning: 'Load is elevated.',
          ethics: EthicsAssessment(
            safe: true,
            flags: <String>[],
            adjustments: <String>[],
          ),
          policyApplied: true,
        );
        final SIEcosystemState ecosystem = SIEcosystemState(
          nodes: <String, EcosystemNode>{
            'state:elevated': EcosystemNode(
              id: 'state:elevated',
              type: EcosystemNodeType.state,
              label: 'elevated',
              weight: 0.8,
              lastSeen: now,
            ),
          },
          edges: <String, EcosystemEdge>{},
          updatedAt: now,
        );

        final EvolutionTimelineUpdate update = engine.track(
          current: const EvolutionTimeline(),
          memory: const SIMemoryStore(),
          context: _context(load: 0.9, stress: 0.8),
          patterns: patterns,
          ecosystem: ecosystem,
          decision: decision,
          now: now,
        );

        expect(update.timeline.events, hasLength(4));
        expect(
          update.timeline.events.map((EvolutionEvent value) => value.type),
          containsAll(<EvolutionEventType>[
            EvolutionEventType.regression,
            EvolutionEventType.pattern,
            EvolutionEventType.ecosystem,
            EvolutionEventType.milestone,
          ]),
        );
        expect(update.summary, contains('High-confidence safe decision'));
        expect(update.memory.tiered.longTerm, isNotEmpty);
      },
    );

    test('separates stable engagement from a neutral state', () {
      final EvolutionTimelineUpdate stable = engine.track(
        current: const EvolutionTimeline(),
        memory: const SIMemoryStore(),
        context: _context(engagement: 0.8, fatigue: 0.2),
        now: now,
      );
      final EvolutionTimelineUpdate neutral = engine.track(
        current: stable.timeline,
        memory: stable.memory,
        context: _context(engagement: 0.4, fatigue: 0.5),
        now: now.add(const Duration(minutes: 1)),
      );

      expect(stable.timeline.events.first.label, 'Stable engagement state');
      expect(neutral.timeline.events.first.label, 'Neutral state update');
      expect(neutral.timeline.events, hasLength(2));
    });

    test('caps retained history at the configured maximum', () {
      EvolutionTimeline timeline = const EvolutionTimeline();
      for (int i = 0; i < 130; i += 1) {
        timeline = timeline.push(
          EvolutionEvent(
            type: EvolutionEventType.stabilization,
            label: 'event-$i',
            timestamp: now.add(Duration(minutes: i)),
            strength: 0.5,
            details: const <String, dynamic>{},
          ),
        );
      }
      expect(timeline.events, hasLength(120));
      expect(timeline.events.first.label, 'event-129');
    });
  });

  group('SyntheticIntelligenceEngine compatibility boundary', () {
    test(
      'merges evidence inputs and preserves explicit runtime control',
      () async {
        final SyntheticIntelligenceEngine engine =
            SyntheticIntelligenceEngine();
        final Task task = Task(
          id: 'task-compat',
          title: 'Prepare launch notes',
          priority: 4,
          difficulty: 3,
          energyRequired: 2,
        );
        const AIResponse seed = AIResponse(
          message: 'Start with the launch risks.',
          confidence: 0.8,
          emotion: 'focused',
          taskTitle: 'Prepare launch notes',
        );

        final SIFinalOutputBundle output = await engine.build(
          input: 'I am stuck and confused, but ready to move.',
          now: now,
          personality: _UnencodableValue(),
          response: seed,
          policy: const <String, dynamic>{'pressure': 'low'},
          appState: 'creator',
          platform: 'android',
          history: const <String>['We identified the launch risks.'],
          metadata: const <String, dynamic>{
            'goal': 'Ship safely',
            'goals': <String>['Document rollback'],
            'completed': 1,
          },
          context: const <String, dynamic>{
            'goal': 'Protect user data',
            'goals': <String>['Ship safely'],
          },
          nonText: const SINonTextInputs(
            behaviorPatterns: <String>['long pause before submit'],
          ),
          task: task,
          goals: const <String>['Finish release review'],
        );

        expect(output.provenance.generationMode, 'deterministic_local');
        expect(output.provenance.evidenceSources, contains('task:task-compat'));
        expect(engine.runtime.memory.snapshots, isNotEmpty);

        final AIResponse response = await engine.buildAIResponse(
          input: '',
          now: now.add(const Duration(minutes: 1)),
          nonText: const SINonTextInputs(voiceToText: 'Ready to continue'),
        );
        expect(response.message, isNotEmpty);
        expect(response.confidence, inInclusiveRange(0, 1));

        const SIEngineRuntimeState replacement = SIEngineRuntimeState();
        engine.replaceRuntime(replacement);
        expect(engine.runtime, same(replacement));
        engine.replaceMemory(output.memory);
        expect(engine.memory.snapshots, isNotEmpty);

        final SIFinalOutputBundle packetOutput = await engine.buildFromPacket(
          packet: const SIInputPacket(text: 'Continue with one safe step.'),
          goals: const <String>['Keep changes reversible'],
        );
        expect(packetOutput.message, isNotEmpty);

        engine.clear();
        expect(engine.memory.snapshots, isEmpty);
      },
    );
  });
}

SIContext _context({
  double load = 0.4,
  double stress = 0.4,
  double engagement = 0.5,
  double fatigue = 0.75,
}) {
  return SIContext(
    input: const SIInputPacket(text: 'Help me choose the next step.'),
    userState: SIUserState(
      emotion: 'focused',
      cognitiveLoad: load,
      stress: stress,
      motivation: 0.7,
      engagement: engagement,
      fatigue: fatigue,
      frustration: 0.2,
      excitement: 0.4,
      stability: 'steady',
    ),
  );
}

SISnapshot _snapshot(
  DateTime timestamp, {
  required int completed,
  required int skipped,
  String? taskId,
  double energy = 0.3,
  double fatigue = 0.8,
}) {
  return SISnapshot(
    timestamp: timestamp,
    energy: energy,
    fatigue: fatigue,
    completed: completed,
    skipped: skipped,
    taskId: taskId,
  );
}

MemoryRecord _record(String content, DateTime timestamp) {
  return MemoryRecord(
    content: content,
    timestamp: timestamp,
    relevance: 0.8,
    confidence: 0.8,
  );
}

class _UnencodableValue {
  @override
  String toString() => 'custom-personality';
}
