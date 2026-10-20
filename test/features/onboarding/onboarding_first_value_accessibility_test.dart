import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/features/onboarding/ui/onboarding_screen.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const List<({String name, Size size, double textScale})> surfaces =
      <({String name, Size size, double textScale})>[
        (
          name: 'small phone at 200 percent text',
          size: Size(320, 568),
          textScale: 2,
        ),
        (name: 'large phone', size: Size(430, 932), textScale: 1),
        (name: 'tablet', size: Size(800, 1280), textScale: 1),
        (
          name: 'landscape keyboard surface',
          size: Size(1280, 720),
          textScale: 1,
        ),
      ];

  testWidgets('Go to Today completes setup with the core guide paused', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      onboardingWelcomeCompleteStorageKey: true,
    });
    final container = ProviderContainer(
      overrides: [
        domainTaskRepositoryProvider.overrideWithValue(_SetupTasks()),
        accountStorageScopeProvider.overrideWithValue(
          AccountStorageScope.authenticated('calm-skip-setup-user'),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(onboardingWelcomeCompleteProvider.notifier).set(true);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: OnboardingScreen()),
      ),
    );
    await tester.pump();
    final exit = find.byKey(const Key('first-value-skip-top'));
    expect(exit.hitTestable(), findsOneWidget);
    await tester.tap(exit);
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(container.read(onboardingCompleteProvider), isTrue);
    final guidance = await container.read(adaptiveGuidanceProvider.future);
    expect(guidance.activeCoreLesson, isNull);
    expect(
      guidance.laterLessons,
      containsAll([
        GuidanceLessonId.createFirstItem,
        GuidanceLessonId.scheduleFirstItem,
        GuidanceLessonId.reviewTimeline,
      ]),
    );
    expect(tester.takeException(), isNull);
  });

  for (final surface in surfaces) {
    testWidgets('first-value setup remains reachable on ${surface.name}', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = surface.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues(<String, Object>{
        onboardingWelcomeCompleteStorageKey: true,
      });
      final ProviderContainer container = ProviderContainer(
        overrides: [
          accountStorageScopeProvider.overrideWithValue(
            AccountStorageScope.authenticated('phase-6-accessibility-user'),
          ),
        ],
      );
      container.read(onboardingWelcomeCompleteProvider.notifier).set(true);
      addTearDown(container.dispose);
      final SemanticsHandle semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                textScaler: TextScaler.linear(surface.textScale),
                disableAnimations: true,
                accessibleNavigation: true,
              ),
              child: const OnboardingScreen(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.bySemanticsLabel('First setup, step 3 of 3'), findsOneWidget);
      semantics.dispose();
      expect(find.byKey(const Key('first-value-question')), findsOneWidget);

      final Finder quickExit = find.byKey(const Key('first-value-skip-top'));
      await tester.ensureVisible(quickExit);
      expect(tester.getSize(quickExit).height, greaterThanOrEqualTo(48));

      final Finder primary = find.byKey(const Key('first-value-show-choice'));
      await tester.ensureVisible(primary);
      await tester.pump();
      expect(primary, findsOneWidget);
      expect(tester.getSize(primary).height, greaterThanOrEqualTo(48));
      expect(find.byKey(const Key('first-value-skip')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

class _SetupTasks implements ITaskRepository {
  @override
  Future<List<TaskEntity>> getAllTasks() async => [];
  @override
  Future<TaskEntity?> getTaskById(String id) async => null;
  @override
  Future<void> saveTask(TaskEntity task) async {}
  @override
  Future<void> deleteTask(String id) async {}
}
