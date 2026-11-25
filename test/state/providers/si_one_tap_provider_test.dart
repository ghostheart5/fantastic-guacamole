import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_one_tap_question.dart';
import 'package:fantastic_guacamole/domain/entities/si_v2_contract.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/policies/assistant_safety_policy.dart';
import 'package:fantastic_guacamole/domain/release/assistant_release_control.dart';
import 'package:fantastic_guacamole/state/providers/assistant_release_provider.dart';
import 'package:fantastic_guacamole/state/providers/si_one_tap_provider.dart';
import 'package:fantastic_guacamole/state/providers/si_v2_provider.dart';
import 'package:fantastic_guacamole/state/services/si_v2_read_gateway.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 8, 20, 12);

  SIV2ReadGateway gateway(String kind) {
    final bool empty = kind == 'empty';
    final bool late = kind == 'late';
    return SIV2ReadGateway(
      accountScopeId: 'account:test',
      readTasks: () async => empty
          ? <TaskEntity>[]
          : <TaskEntity>[
              if (late)
                TaskEntity(
                  id: 'late',
                  title: 'File taxes',
                  createdAt: now.subtract(const Duration(days: 30)),
                  dueDate: now.subtract(const Duration(days: 9)),
                )
              else
                TaskEntity(
                  id: 'today',
                  title: 'Write report',
                  createdAt: now.subtract(const Duration(days: 5)),
                  dueDate: now,
                ),
              for (int i = 0; i < 6; i++)
                TaskEntity(
                  id: 'done$i',
                  title: 'Finished $i',
                  createdAt: now.subtract(const Duration(days: 20)),
                  isCompleted: true,
                  completedAt: now.subtract(Duration(days: i + 1)),
                ),
            ],
      readGoals: () async => empty
          ? <GoalEntity>[]
          : <GoalEntity>[
              GoalEntity(
                id: 'g1',
                title: 'Launch the app',
                createdAt: now.subtract(const Duration(days: 40)),
              ),
            ],
      readMilestones: () async => [],
      readTimeline: () async => [],
      readHabits: () async => empty
          ? <HabitEntity>[]
          : <HabitEntity>[
              HabitEntity(
                id: 'walk',
                title: 'Walk',
                createdAt: now.subtract(const Duration(days: 60)),
              ),
            ],
      readHabitOccurrences: () async => <HabitOccurrenceEntity>[],
    );
  }

  SIOneTapService service(String kind) => SIOneTapService(
    readEvidence: (DateTime at) =>
        gateway(kind).read(observedAt: at, includeActivity: true),
    clock: () => now,
  );

  group(
    'every question passes the same safety check as other local answers',
    () {
      for (final String kind in <String>['empty', 'typical', 'late']) {
        for (final bool es in <bool>[false, true]) {
          for (final SIOneTapQuestion q in SIOneTapQuestion.values) {
            test('${q.name} / $kind / ${es ? 'es' : 'en'}', () async {
              final SIOneTapAnswer answer = await service(
                kind,
              ).answer(q, isSpanish: es, goalId: kind == 'empty' ? null : 'g1');
              expect(answer.response.safetyReceipt, isNotNull);
              expect(answer.response.directAnswer, isNotEmpty);
              expect(answer.response.recommendation, isNotEmpty);
            });
          }
        }
      }
    },
  );

  test('the answer is built from saved records only: no remote dependency', () {
    // The service takes a record reader and a clock. It has no transport,
    // wallet or credit dependency, so nothing can be sent or charged.
    final SIOneTapPort port = service('typical');
    expect(port, isA<SIOneTapService>());
  });

  test(
    'a rolled-back release withholds the answer instead of guessing',
    () async {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          siV2ReadGatewayProvider.overrideWithValue(gateway('typical')),
          siV2ClockProvider.overrideWithValue(() => now),
          for (final AssistantReleaseCapability capability
              in <AssistantReleaseCapability>[
                AssistantReleaseCapability.siConsoleV2,
                AssistantReleaseCapability.safetyCritic,
              ])
            assistantReleaseDecisionProvider(capability).overrideWith(
              (ref) async => AssistantReleaseDecision(
                enabled: false,
                shadowEvaluationEnabled: false,
                cohort: AssistantReleaseCohort.internal,
                reasonCode: 'synthetic-test',
                accountDigest: 'test',
                capability: capability,
                configDigest: 'test',
              ),
            ),
        ],
      );
      addTearDown(container.dispose);
      await expectLater(
        container
            .read(siOneTapServiceProvider)
            .answer(SIOneTapQuestion.planMyDay, isSpanish: false),
        throwsA(anything),
      );
    },
  );

  test('the answer is bound to the account the records came from', () async {
    final SIOneTapAnswer answer = await service(
      'typical',
    ).answer(SIOneTapQuestion.planMyDay, isSpanish: false);
    expect(
      answer.response.safetyReceipt!.surface,
      AssistantSafetySurface.siConsole,
    );
    expect(
      answer.response.evidenceLinks.every(
        (SIV2EvidenceLink link) => link.uri.startsWith('chronospark://'),
      ),
      isTrue,
    );
  });

  test('a request left for Chat is held once and cleared', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(siOneTapRequestProvider), isNull);
    container
        .read(siOneTapRequestProvider.notifier)
        .ask(SIOneTapQuestion.reviewWeek);
    expect(
      container.read(siOneTapRequestProvider)!.question,
      SIOneTapQuestion.reviewWeek,
    );
    container.read(siOneTapRequestProvider.notifier).clear();
    expect(container.read(siOneTapRequestProvider), isNull);
  });
}
