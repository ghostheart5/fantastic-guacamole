import 'package:fantastic_guacamole/domain/entities/si_v2_contract.dart';
import 'package:fantastic_guacamole/engine/si/si_v2_engine.dart';
import 'package:fantastic_guacamole/features/si_console/ui/si_console_screen.dart';
import 'package:fantastic_guacamole/state/controllers/voice_controller.dart';
import 'package:fantastic_guacamole/state/providers/si_v2_provider.dart';
import 'package:fantastic_guacamole/system/voice/voice_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 8, 20, 12);
  final SIV2EvidenceSnapshot snapshot = SIV2EvidenceSnapshot(
    accountScopeId: 'account:test',
    observedAt: now,
    tasks: <SIV2TaskEvidence>[
      SIV2TaskEvidence(
        id: 'task',
        title: 'Prepare release',
        createdAt: now.subtract(const Duration(days: 2)),
        priority: 5,
        dueDate: now.add(const Duration(days: 1)),
      ),
    ],
    goals: const <SIV2GoalEvidence>[],
    milestones: const <SIV2MilestoneEvidence>[],
    timeline: const <SIV2TimelineEvidence>[],
  );

  testWidgets('TalkBack semantics and 200 percent text stay recoverable', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final SemanticsHandle semantics = tester.ensureSemantics();
    final _RecordingPort port = _RecordingPort(snapshot: snapshot, now: now);
    final ProviderContainer container = ProviderContainer(
      overrides: [
        siV2QueryServiceProvider.overrideWithValue(port),
        siV2EvidenceSnapshotProvider.overrideWith((Ref ref) async => snapshot),
        voiceServiceProvider.overrideWithValue(_NoopVoiceService()),
      ],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    });
    try {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(360, 1000),
                textScaler: TextScaler.linear(2),
              ),
              child: SIConsoleScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      expect(find.bySemanticsLabel('Back to Nexus'), findsOneWidget);
      expect(find.bySemanticsLabel('Send SI query'), findsOneWidget);
      expect(find.byKey(const Key('si-query-input')), findsOneWidget);
      expect(find.text('What needs attention?'), findsOneWidget);
      expect(find.text('Why is this goal at risk?'), findsOneWidget);
      expect(find.text('What should I do next?'), findsOneWidget);
      expect(find.byKey(const Key('si-v2-entity-filter')), findsNothing);
      expect(find.byKey(const Key('si-v2-assumption')), findsNothing);

      await tester.enterText(
        find.byKey(const Key('si-query-input')),
        'What needs attention?',
      );
      await tester.tap(find.bySemanticsLabel('Send SI query'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(port.calls, 1);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('query builder produces a complete structured SI V2 response', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final _RecordingPort port = _RecordingPort(snapshot: snapshot, now: now);
    final ProviderContainer container = ProviderContainer(
      overrides: [
        siV2QueryServiceProvider.overrideWithValue(port),
        siV2EvidenceSnapshotProvider.overrideWith((Ref ref) async => snapshot),
        voiceServiceProvider.overrideWithValue(_NoopVoiceService()),
      ],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SIConsoleScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byKey(const Key('si-query-input')), findsOneWidget);
    expect(find.text('What needs attention?'), findsOneWidget);
    expect(find.text('Why is this goal at risk?'), findsOneWidget);
    expect(find.text('What should I do next?'), findsOneWidget);
    expect(find.text('Advanced'), findsOneWidget);
    expect(find.byKey(const Key('si-v2-intent-forecast')), findsNothing);

    await tester.tap(find.byKey(const Key('si-v2-advanced')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.byKey(const Key('si-v2-intent-forecast')));
    await tester.pump();

    expect(find.text('SI V2 QUERY BUILDER'), findsOneWidget);
    expect(find.byKey(const Key('si-v2-intent-forecast')), findsOneWidget);
    expect(find.byKey(const Key('si-v2-source-tasks')), findsOneWidget);
    expect(find.byKey(const Key('si-v2-range-thirtyDays')), findsOneWidget);

    final SegmentedButton<SIV2Intent> intentControl = tester.widget(
      find.ancestor(
        of: find.byKey(const Key('si-v2-intent-forecast')),
        matching: find.byType(SegmentedButton<SIV2Intent>),
      ),
    );
    intentControl.onSelectionChanged!(<SIV2Intent>{SIV2Intent.forecast});
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('si-v2-assumption')),
      'A single work block is available.',
    );
    await tester.enterText(
      find.byKey(const Key('si-query-input')),
      'What happens if I defer Prepare release?',
    );
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(port.calls, 1);
    expect(port.lastQuery?.intent, SIV2Intent.forecast);
    expect(
      port.lastQuery?.assumptions,
      contains('A single work block is available.'),
    );
    expect(find.byKey(const Key('si-v2-response')), findsOneWidget);
    expect(find.text('DIRECT ANSWER', skipOffstage: false), findsOneWidget);
    expect(find.text('RECOMMENDATION', skipOffstage: false), findsOneWidget);
    expect(find.text('OBSERVED FACTS'), findsNothing);

    await tester.tap(find.byKey(const Key('si-v2-response-advanced')));
    await tester.pump(const Duration(milliseconds: 300));

    for (final String section in <String>[
      'OBSERVED FACTS',
      'DETERMINISTIC CALCULATIONS',
      'INFERENCES',
      'MISSING OR CONFLICTING INFORMATION',
      'SCENARIOS',
      'SCENARIO ASSUMPTIONS',
      'CONFIDENCE ANATOMY',
      'EVIDENCE LINKS',
    ]) {
      expect(find.text(section, skipOffstage: false), findsOneWidget);
    }
    expect(
      find.textContaining('Coverage:', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.textContaining('% confident'), findsNothing);
  });

  testWidgets('empty input never reaches the read-only analyzer', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final _RecordingPort port = _RecordingPort(snapshot: snapshot, now: now);
    final ProviderContainer container = ProviderContainer(
      overrides: [
        siV2QueryServiceProvider.overrideWithValue(port),
        siV2EvidenceSnapshotProvider.overrideWith((Ref ref) async => snapshot),
        voiceServiceProvider.overrideWithValue(_NoopVoiceService()),
      ],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SIConsoleScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(find.byKey(const Key('si-query-input')), '   ');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();

    expect(port.calls, 0);
  });
}

final class _RecordingPort implements SIV2QueryPort {
  _RecordingPort({required this.snapshot, required this.now});

  final SIV2EvidenceSnapshot snapshot;
  final DateTime now;
  int calls = 0;
  SIV2Query? lastQuery;

  @override
  Future<SIV2Response> analyze(SIV2Query query) async {
    calls += 1;
    lastQuery = query;
    return const SIV2Engine().analyze(
      query: query,
      snapshot: snapshot,
      now: now,
    );
  }
}

final class _NoopVoiceService extends VoiceService {
  @override
  Future<void> speak(String text) async {}

  @override
  Future<void> stop() async {}
}
