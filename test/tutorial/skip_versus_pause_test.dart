import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/features/creator/ui/open_creator.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:fantastic_guacamole/state/models/creator_form_data.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _account = 'skip-vs-pause-user';

String get _prefix =>
    'adaptive_guidance_v3.${AccountStorageScope.authenticated(_account).v2Namespace}';

const List<GuidanceLessonId> _core = <GuidanceLessonId>[
  GuidanceLessonId.createFirstItem,
  GuidanceLessonId.scheduleFirstItem,
  GuidanceLessonId.reviewTimeline,
];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('skipping the core guide is stored as a skip, not a pause', () async {
    final ProviderContainer container = _container();
    addTearDown(container.dispose);
    await container.read(adaptiveGuidanceProvider.future);
    await container.read(adaptiveGuidanceProvider.notifier).skipCoreGuide();

    final AdaptiveGuidanceState state = container
        .read(adaptiveGuidanceProvider)
        .requireValue;
    expect(state.skippedLessons, containsAll(_core));
    expect(state.laterLessons, isEmpty);
    expect(state.activeCoreLesson, isNull);
    expect(state.coreGuideStatus, CoreGuideStatus.skipped);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    for (final GuidanceLessonId id in _core) {
      expect(prefs.getBool('$_prefix.skip.${id.name}'), isTrue);
      expect(prefs.containsKey('$_prefix.later.${id.name}'), isFalse);
    }
  });

  test('pausing the guide is reported as paused, not skipped', () async {
    final ProviderContainer container = _container();
    addTearDown(container.dispose);
    await container.read(adaptiveGuidanceProvider.future);
    await container
        .read(adaptiveGuidanceProvider.notifier)
        .later(GuidanceLessonId.createFirstItem);

    final AdaptiveGuidanceState state = container
        .read(adaptiveGuidanceProvider)
        .requireValue;
    expect(state.laterLessons, containsAll(_core));
    expect(state.skippedLessons, isEmpty);
    expect(state.coreGuideStatus, CoreGuideStatus.paused);
  });

  test('a fresh account reports an active guide', () async {
    final ProviderContainer container = _container();
    addTearDown(container.dispose);
    final AdaptiveGuidanceState state = await container.read(
      adaptiveGuidanceProvider.future,
    );
    expect(state.coreGuideStatus, CoreGuideStatus.active);
  });

  test('restart brings the guide back from a skip and from a pause', () async {
    for (final bool skip in <bool>[true, false]) {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final ProviderContainer container = _container();
      addTearDown(container.dispose);
      await container.read(adaptiveGuidanceProvider.future);
      final AdaptiveGuidanceNotifier notifier = container.read(
        adaptiveGuidanceProvider.notifier,
      );
      if (skip) {
        await notifier.skipCoreGuide();
      } else {
        await notifier.later(GuidanceLessonId.createFirstItem);
      }
      await notifier.restartLessons();
      final AdaptiveGuidanceState state = container
          .read(adaptiveGuidanceProvider)
          .requireValue;
      expect(state.activeCoreLesson, GuidanceLessonId.createFirstItem);
      expect(state.coreGuideStatus, CoreGuideStatus.active);
    }
  });

  test('a skip survives reload and later milestones', () async {
    final ProviderContainer first = _container();
    await first.read(adaptiveGuidanceProvider.future);
    await first.read(adaptiveGuidanceProvider.notifier).skipCoreGuide();
    first.dispose();

    final ProviderContainer reloaded = _container();
    addTearDown(reloaded.dispose);
    final AdaptiveGuidanceState state = await reloaded.read(
      adaptiveGuidanceProvider.future,
    );
    expect(state.coreGuideStatus, CoreGuideStatus.skipped);
    await reloaded
        .read(adaptiveGuidanceProvider.notifier)
        .record(GuidanceMilestone.firstItem);
    expect(
      reloaded.read(adaptiveGuidanceProvider).requireValue.activeCoreLesson,
      isNull,
    );
  });

  test(
    'old stored later flags from a skipped setup still load as a pause',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        for (final GuidanceLessonId id in _core)
          '$_prefix.later.${id.name}': true,
        '$_prefix.guidanceDismissed.at': 1700000000000,
        '$_prefix.guidanceDismissed.count': 1,
      });
      final ProviderContainer container = _container();
      addTearDown(container.dispose);
      final AdaptiveGuidanceState state = await container.read(
        adaptiveGuidanceProvider.future,
      );
      expect(state.laterLessons, containsAll(_core));
      expect(state.skippedLessons, isEmpty);
      expect(state.replayLessons, isEmpty);
      expect(state.activeCoreLesson, isNull);
      expect(state.coreGuideStatus, CoreGuideStatus.paused);
      // Loading must not rewrite the old flags or replay onboarding.
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      for (final GuidanceLessonId id in _core) {
        expect(prefs.getBool('$_prefix.later.${id.name}'), isTrue);
        expect(prefs.containsKey('$_prefix.skip.${id.name}'), isFalse);
      }
    },
  );

  test(
    'a finished guide reports complete even with an old later flag',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        '$_prefix.firstItem.at': 1700000000000,
        '$_prefix.firstSchedule.at': 1700000000000,
        '$_prefix.firstTimelineReview.at': 1700000000000,
        '$_prefix.later.reviewTimeline': true,
      });
      final ProviderContainer container = _container();
      addTearDown(container.dispose);
      final AdaptiveGuidanceState state = await container.read(
        adaptiveGuidanceProvider.future,
      );
      expect(state.coreGuideStatus, CoreGuideStatus.complete);
    },
  );

  test(
    'a session pause hides the guide, writes nothing and ends on reload',
    () async {
      final ProviderContainer first = _container();
      await first.read(adaptiveGuidanceProvider.future);
      await first
          .read(adaptiveGuidanceProvider.notifier)
          .pauseCoreGuideForSession();
      final AdaptiveGuidanceState hidden = first
          .read(adaptiveGuidanceProvider)
          .requireValue;
      expect(hidden.activeCoreLesson, isNull);
      expect(hidden.laterLessons, isEmpty);
      expect(hidden.skippedLessons, isEmpty);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys().where((String k) => k.contains('later')), isEmpty);
      expect(prefs.getKeys().where((String k) => k.contains('skip')), isEmpty);
      first.dispose();

      final ProviderContainer second = _container();
      addTearDown(second.dispose);
      expect(
        (await second.read(adaptiveGuidanceProvider.future)).activeCoreLesson,
        GuidanceLessonId.createFirstItem,
      );
    },
  );

  testWidgets('openCreatorForItem does not persist a mute', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = _container(ready: true);
    addTearDown(container.dispose);
    final AdaptiveGuidanceState before = await container.read(
      adaptiveGuidanceProvider.future,
    );
    expect(before.activeCoreLesson, GuidanceLessonId.createFirstItem);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Consumer(
            builder: (BuildContext context, WidgetRef ref, Widget? child) {
              return TextButton(
                onPressed: () =>
                    openCreatorForItem(context, ref, CreatorFormKind.task),
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getKeys().where(
        (String key) =>
            key.contains('.later.') ||
            key.contains('.skip.') ||
            key.contains('guidanceDismissed'),
      ),
      isEmpty,
    );
    final AdaptiveGuidanceState during = container
        .read(adaptiveGuidanceProvider)
        .requireValue;
    expect(during.laterLessons, isEmpty);
    expect(during.skippedLessons, isEmpty);
    // The form is not the tutorial exercise for this visit...
    expect(during.activeCoreLesson, isNull);
    // ...but the guide is still on offer the next time the app opens.
    final ProviderContainer reopened = _container();
    addTearDown(reopened.dispose);
    expect(
      (await reopened.read(adaptiveGuidanceProvider.future)).activeCoreLesson,
      GuidanceLessonId.createFirstItem,
    );
  });
}

ProviderContainer _container({bool ready = false}) {
  return ProviderContainer(
    overrides: [
      accountStorageScopeProvider.overrideWithValue(
        AccountStorageScope.authenticated(_account),
      ),
      domainTaskRepositoryProvider.overrideWithValue(_NoTasks()),
      if (ready) authSessionBoundaryProvider.overrideWith(_ReadyBoundary.new),
    ],
  );
}

class _ReadyBoundary extends AuthSessionBoundaryNotifier {
  @override
  AuthSessionBoundary build() => const AuthSessionBoundary(
    generation: 1,
    userId: _account,
    isTransitioning: false,
    isStorageReady: true,
  );
}

class _NoTasks implements ITaskRepository {
  @override
  Future<List<TaskEntity>> getAllTasks() async => <TaskEntity>[];
  @override
  Future<TaskEntity?> getTaskById(String id) async => null;
  @override
  Future<void> saveTask(TaskEntity task) async {}
  @override
  Future<void> deleteTask(String id) async {}
}
