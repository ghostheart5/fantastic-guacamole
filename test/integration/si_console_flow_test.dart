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
  testWidgets(
    'SI V2 preserves consecutive queries and returns valid evidence responses',
    (WidgetTester tester) async {
      final DateTime now = DateTime.utc(2026, 8, 20, 12);
      final SIV2EvidenceSnapshot snapshot = SIV2EvidenceSnapshot(
        accountScopeId: 'account:integration',
        observedAt: now,
        tasks: <SIV2TaskEvidence>[
          SIV2TaskEvidence(
            id: 'task-priority',
            title: 'Finish the release audit',
            createdAt: now.subtract(const Duration(days: 2)),
            priority: 5,
            dueDate: now.add(const Duration(days: 1)),
          ),
        ],
        goals: const <SIV2GoalEvidence>[],
        milestones: const <SIV2MilestoneEvidence>[],
        timeline: const <SIV2TimelineEvidence>[],
      );
      final _RecordingSIV2Port port = _RecordingSIV2Port(
        snapshot: snapshot,
        now: now,
      );
      final ProviderContainer container = ProviderContainer(
        overrides: [
          siV2AvailabilityProvider.overrideWith((Ref ref) async => true),
          siV2QueryServiceProvider.overrideWithValue(port),
          siV2EvidenceSnapshotProvider.overrideWith(
            (Ref ref) async => snapshot,
          ),
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
      await tester.pump(const Duration(milliseconds: 300));

      await _send(tester, 'What should I do now?');
      await _send(tester, 'What should I do now, exactly?');

      expect(port.queries, hasLength(2));
      expect(port.responses, hasLength(2));
      expect(port.queries[0].rawText, 'What should I do now?');
      expect(port.queries[1].rawText, 'What should I do now, exactly?');
      expect(port.queries[1].priorUserTurns, contains('What should I do now?'));
      for (final SIV2Response response in port.responses) {
        expect(response.validate, returnsNormally);
        expect(response.evidenceLinks, isNotEmpty);
      }

      final SIV2Response malformed = await port.analyze(
        SIV2Query(
          rawText: '/malformed ???',
          intent: SIV2Intent.answer,
          sources: <SIV2Source>{SIV2Source.tasks},
          timeRange: SIV2TimeRange.thirtyDays,
        ),
      );
      expect(() => malformed.validate(), returnsNormally);
      expect(malformed.evidenceLinks, isNotEmpty);
      expect(
        malformed.confidence.requiredSignals,
        greaterThanOrEqualTo(malformed.confidence.coveredSignals),
      );
      expect(find.byType(SIConsoleScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _send(WidgetTester tester, String value) async {
  await tester.enterText(find.byKey(const Key('si-query-input')), value);
  await tester.tap(find.byIcon(Icons.send_rounded));
  await tester.pump(const Duration(milliseconds: 300));
}

final class _RecordingSIV2Port implements SIV2QueryPort {
  _RecordingSIV2Port({required this.snapshot, required this.now});

  final SIV2EvidenceSnapshot snapshot;
  final DateTime now;
  final List<SIV2Query> queries = <SIV2Query>[];
  final List<SIV2Response> responses = <SIV2Response>[];

  @override
  Future<SIV2Response> analyze(SIV2Query query) async {
    queries.add(query);
    final SIV2Response response = const SIV2Engine().analyze(
      query: query,
      snapshot: snapshot,
      now: now,
    );
    responses.add(response);
    return response;
  }
}

final class _NoopVoiceService extends VoiceService {
  @override
  Future<void> speak(String text) async {}

  @override
  Future<void> stop() async {}
}
