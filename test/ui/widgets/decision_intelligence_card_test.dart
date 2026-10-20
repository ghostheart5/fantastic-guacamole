import 'package:fantastic_guacamole/domain/operating_system/operating_system_contract.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/ui/widgets/decision_intelligence_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  for (final action in [
    (
      type: OperatingActionType.openTimeline,
      english: 'Review on Schedule',
      spanish: 'Revisar en agenda',
      destination: '/timeline',
    ),
    (
      type: OperatingActionType.openCreator,
      english: 'Add something',
      spanish: 'Añadir algo',
      destination: '/creator',
    ),
    (
      type: OperatingActionType.openProgression,
      english: 'Review recovery in Activity',
      spanish: 'Revisar recuperación en Actividad',
      destination: '/progression',
    ),
  ]) {
    for (final expired in <bool>[false, true]) {
      testWidgets(
        'intelligence answers decision questions for ${action.type.name}${expired ? ' with expired action disabled' : ''}',
        (WidgetTester tester) async {
          final DateTime now = DateTime.now().toUtc().subtract(
            Duration(minutes: expired ? 30 : 0),
          );
          final OperatingSnapshot snapshot = OperatingSnapshot(
            accountScope: 'v2.test',
            observedAt: now,
            sourceRevisions: const <String, String>{'tasks': '1'},
            activeGoalCount: 1,
            actionableCount: 2,
            overdueCount: 1,
            completedToday: 1,
            energy: .7,
            fatigue: .2,
            momentum: 65,
            pressure: 55,
            topActionId: 'task-a',
            topActionLabel: 'Start task A',
            activeRisks: const <String>['One overdue task'],
            evidenceCoverage: 1,
          );
          final OperatingDecisionReceipt decision = OperatingDecisionReceipt(
            subjectId: 'task-a',
            recommendedAction: 'Start task A',
            rationale: 'Task A ranks first.',
            whyItMatters: 'It protects the deadline.',
            consequenceOfDelay: 'Pressure rises.',
            generatedAt: now,
            expiresAt: now.add(const Duration(minutes: 20)),
            confidence: OperatingConfidence.high,
            evidence: const <OperatingEvidence>[],
            actionIntent: OperatingActionIntent(
              id: 'action-a',
              type: action.type,
              label: action.english,
              destination: action.destination,
              targetEntityId: 'task-a',
            ),
            sourceRevisions: const <String, String>{'tasks': '1'},
            modelVersion: 'test-v1',
          );
          final DecisionIntelligence intelligence = DecisionIntelligence(
            snapshot: snapshot,
            delta: const OperatingDeltaEngine().compare(
              previous: null,
              current: snapshot,
              comparedAt: now,
            ),
            decision: decision,
            acknowledgedSnapshotId: null,
          );
          var actionCount = 0;
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: DecisionIntelligenceCard(
                    intelligence: intelligence,
                    topRisk: 'One overdue task',
                    recentProgress:
                        'One task completed since the last intelligence.',
                    onAction: () => actionCount++,
                  ),
                ),
              ),
            ),
          );
          expect(find.text('WHERE YOU ARE'), findsOneWidget);
          expect(find.text('WHAT CHANGED'), findsOneWidget);
          expect(find.text('WHAT MATTERS NEXT'), findsOneWidget);
          expect(find.text('WHY THIS MATTERS'), findsOneWidget);
          expect(find.text('TOP RISK'), findsOneWidget);
          expect(find.text('One overdue task'), findsOneWidget);
          expect(
            find.text('One task completed since the last intelligence.'),
            findsOneWidget,
          );
          expect(find.text('Start task A'), findsOneWidget);
          expect(find.text(action.english), findsOneWidget);

          await tester.pumpWidget(
            MaterialApp(
              locale: const Locale('es'),
              supportedLocales: ChronoSparkLocalizations.supportedLocales,
              localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
                ChronoSparkLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: Scaffold(
                body: SingleChildScrollView(
                  child: DecisionIntelligenceCard(
                    intelligence: intelligence,
                    topRisk: 'One overdue task',
                    recentProgress:
                        'One task completed since the last intelligence.',
                    onAction: () => actionCount++,
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          expect(find.text('DÓNDE ESTÁS'), findsOneWidget);
          expect(find.text('QUÉ IMPORTA AHORA'), findsOneWidget);
          expect(find.text('POR QUÉ IMPORTA'), findsOneWidget);
          expect(find.text(action.spanish), findsOneWidget);
          expect(find.text('Abrir Creador'), findsNothing);
          expect(find.text('Start task A'), findsOneWidget);
          final actionLabel = action.spanish;
          await tester.ensureVisible(find.text(actionLabel));
          expect(decision.isExpired, expired);
          final FilledButton actionButton = tester.widget<FilledButton>(
            find.ancestor(
              of: find.text(actionLabel),
              matching: find.byWidgetPredicate(
                (Widget widget) => widget is FilledButton,
              ),
            ),
          );
          expect(actionButton.onPressed, expired ? isNull : isNotNull);
          await tester.tap(find.text(actionLabel));
          expect(actionCount, expired ? 0 : 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
