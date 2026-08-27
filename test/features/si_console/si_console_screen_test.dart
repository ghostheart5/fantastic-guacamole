import 'dart:async';

import 'package:fantastic_guacamole/domain/entities/si_v2_contract.dart';
import 'package:fantastic_guacamole/engine/si/api.dart';
import 'package:fantastic_guacamole/features/si_console/ui/si_console_screen.dart';
import 'package:fantastic_guacamole/state/controllers/voice_controller.dart';
import 'package:fantastic_guacamole/state/providers/si_v2_provider.dart';
import 'package:fantastic_guacamole/system/voice/voice_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 8, 20, 12);
  final SIV2EvidenceSnapshot snapshot = _snapshot(now);

  testWidgets('malformed empty input is ignored without analysis', (
    WidgetTester tester,
  ) async {
    final _RecordingPort port = _RecordingPort(snapshot: snapshot, now: now);
    final ProviderContainer container = _container(port, snapshot);
    addTearDown(() => _dispose(tester, container));
    await _pumpScreen(tester, container);

    await tester.enterText(find.byKey(const Key('si-query-input')), '    ');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();

    expect(port.calls, 0);
    expect(find.textContaining('SI V2 could not validate'), findsNothing);
  });

  testWidgets('contract failure displays a safe no-mutation response', (
    WidgetTester tester,
  ) async {
    final _ThrowingPort port = _ThrowingPort();
    final ProviderContainer container = _container(port, snapshot);
    addTearDown(() => _dispose(tester, container));
    await _pumpScreen(tester, container);

    await tester.enterText(
      find.byKey(const Key('si-query-input')),
      'show unknown malformed module',
    );
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(port.calls, 1);
    expect(
      find.textContaining('SI V2 could not validate', skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.textContaining('Nothing was changed', skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('send is disabled while a request is in flight', (
    WidgetTester tester,
  ) async {
    final _SlowPort port = _SlowPort();
    final ProviderContainer container = _container(port, snapshot);
    addTearDown(() => _dispose(tester, container));
    await _pumpScreen(tester, container);

    await tester.enterText(
      find.byKey(const Key('si-query-input')),
      'summarize today',
    );
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.hourglass_top_rounded));
    await tester.pump();

    expect(port.calls, 1);
    port.complete(
      const SIV2Engine().analyze(
        query: SIV2Query(
          rawText: 'summarize today',
          intent: SIV2Intent.answer,
          sources: <SIV2Source>{SIV2Source.tasks},
          timeRange: SIV2TimeRange.thirtyDays,
        ),
        snapshot: snapshot,
        now: now,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('si-v2-response')), findsOneWidget);
  });

  testWidgets('assistant response identifies read-only on-device provenance', (
    WidgetTester tester,
  ) async {
    final _RecordingPort port = _RecordingPort(snapshot: snapshot, now: now);
    final ProviderContainer container = _container(port, snapshot);
    addTearDown(() => _dispose(tester, container));
    await _pumpScreen(tester, container);

    await tester.enterText(
      find.byKey(const Key('si-query-input')),
      'what should I do',
    );
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('On device', skipOffstage: false), findsOneWidget);
    expect(
      find.textContaining(
        'SI V2 read-only evidence revision',
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(find.text('External AI', skipOffstage: false), findsNothing);
  });

  testWidgets(
    'a crisis phrase prefixed with a slash shortcut opens the crisis dialog',
    (WidgetTester tester) async {
      final _RecordingPort port = _RecordingPort(snapshot: snapshot, now: now);
      final ProviderContainer container = _container(port, snapshot);
      addTearDown(() => _dispose(tester, container));
      await _pumpScreen(tester, container);

      await tester.enterText(
        find.byKey(const Key('si-query-input')),
        '/tasks i want to kill myself',
      );
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();

      expect(find.text("You're not alone"), findsOneWidget);
      expect(port.calls, 0);
      expect(find.textContaining('SI QUERY SHORTCUTS'), findsNothing);
    },
  );

  testWidgets('shortcut arguments reach SI V2 without modification', (
    WidgetTester tester,
  ) async {
    final _RecordingPort port = _RecordingPort(snapshot: snapshot, now: now);
    final ProviderContainer container = _container(port, snapshot);
    addTearDown(() => _dispose(tester, container));
    await _pumpScreen(tester, container);

    const String query = '/tasks explain THIS exact  task';
    await tester.enterText(find.byKey(const Key('si-query-input')), query);
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(port.calls, 1);
    expect(port.lastQuery?.rawText, query);
    expect(port.lastQuery?.sources, <SIV2Source>{SIV2Source.tasks});
    expect(find.textContaining('TASKS SNAPSHOT'), findsNothing);
  });

  testWidgets('unsupported and unknown shortcut input fails explicitly', (
    WidgetTester tester,
  ) async {
    final _RecordingPort port = _RecordingPort(snapshot: snapshot, now: now);
    final ProviderContainer container = _container(port, snapshot);
    addTearDown(() => _dispose(tester, container));
    await _pumpScreen(tester, container);

    await tester.enterText(
      find.byKey(const Key('si-query-input')),
      '/status extra',
    );
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(
      find.textContaining('does not accept extra text', skipOffstage: false),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('si-query-input')),
      '/not-real preserve this',
    );
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(
      find.textContaining('Unknown shortcut', skipOffstage: false),
      findsOneWidget,
    );
    expect(port.calls, 0);
  });

  testWidgets('autocomplete suggestions are generated from typed prefix', (
    WidgetTester tester,
  ) async {
    final _RecordingPort port = _RecordingPort(snapshot: snapshot, now: now);
    final ProviderContainer container = _container(port, snapshot);
    addTearDown(() => _dispose(tester, container));
    await _pumpScreen(tester, container);

    await tester.enterText(find.byKey(const Key('si-query-input')), '/ta');
    await tester.pump();
    final Finder suggestion = find.byKey(
      const ValueKey<String>('si-shortcut-autocomplete-tasks'),
    );
    expect(suggestion, findsOneWidget);

    await tester.tap(suggestion);
    await tester.pump();
    final TextField field = tester.widget<TextField>(
      find.byKey(const Key('si-query-input')),
    );
    expect(field.controller?.text, '/tasks ');
    expect(port.calls, 0);
  });
}

ProviderContainer _container(
  SIV2QueryPort port,
  SIV2EvidenceSnapshot snapshot,
) {
  return ProviderContainer(
    overrides: [
      siV2QueryServiceProvider.overrideWithValue(port),
      siV2EvidenceSnapshotProvider.overrideWith((Ref ref) async => snapshot),
      voiceServiceProvider.overrideWithValue(_NoopVoiceService()),
    ],
  );
}

Future<void> _pumpScreen(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: SIConsoleScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> _dispose(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(const SizedBox.shrink());
  container.dispose();
}

SIV2EvidenceSnapshot _snapshot(DateTime now) {
  return SIV2EvidenceSnapshot(
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

final class _ThrowingPort implements SIV2QueryPort {
  int calls = 0;

  @override
  Future<SIV2Response> analyze(SIV2Query query) async {
    calls += 1;
    throw StateError('simulated evidence failure');
  }
}

final class _SlowPort implements SIV2QueryPort {
  final Completer<SIV2Response> _completer = Completer<SIV2Response>();
  int calls = 0;

  @override
  Future<SIV2Response> analyze(SIV2Query query) {
    calls += 1;
    return _completer.future;
  }

  void complete(SIV2Response response) => _completer.complete(response);
}

final class _NoopVoiceService extends VoiceService {
  @override
  Future<void> speak(String text) async {}

  @override
  Future<void> stop() async {}
}
