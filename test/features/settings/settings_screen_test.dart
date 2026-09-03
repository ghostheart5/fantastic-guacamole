import 'package:fantastic_guacamole/features/settings/ui/settings_screen.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/data/repositories/person_context_repository.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/person_context.dart';
import 'package:fantastic_guacamole/domain/entities/decision_outcome_entity.dart';
import 'package:fantastic_guacamole/state/models/ai_credit_wallet.dart';
import 'package:fantastic_guacamole/state/providers/paywall_provider.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/person_context_provider.dart';
import 'package:fantastic_guacamole/state/providers/decision_outcome_provider.dart';
import 'package:fantastic_guacamole/state/providers/settings_ui_provider.dart';
import 'package:fantastic_guacamole/state/services/reflection_reminder_service.dart';
import 'package:fantastic_guacamole/theme/app_theme.dart';
import 'package:fantastic_guacamole/ui/constants/app_assets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/golden_harness.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await loadAppFontsForGolden();
  });
  test('account deletion messages distinguish server and local outcomes', () {
    expect(
      accountDeletionOutcomeMessage(const AccountDeletionResult.completed()),
      'Account deletion completed.',
    );
    expect(
      accountDeletionOutcomeMessage(
        const AccountDeletionResult.pending(serverState: 'requested'),
      ),
      contains('Server cleanup is still in progress'),
    );
    expect(
      accountDeletionOutcomeMessage(
        const AccountDeletionResult.pending(
          serverState: 'requested',
          statusTrackingAvailable: false,
        ),
      ),
      contains('status tracking could not be saved'),
    );
    expect(
      accountDeletionOutcomeMessage(
        const AccountDeletionResult.completed(localCleanupCompleted: false),
      ),
      contains('could not clear all local account data'),
    );
  });

  ProviderContainer createContainer({
    PersonContextSpine? personContext,
    AccountStorageScope? accountScope,
    Object? personContextError,
    PersonContextRepository? personContextRepository,
    List<DecisionOutcomeEntity>? decisionOutcomes,
    bool? learningPaused,
  }) {
    final ValueNotifier<bool?> permissionListenable = ValueNotifier<bool?>(
      true,
    );
    addTearDown(permissionListenable.dispose);

    final ProviderContainer container = ProviderContainer(
      retry: (int retryCount, Object error) => null,
      overrides: [
        aiCreditWalletProvider.overrideWith(
          (Ref ref) async => AiCreditWallet(
            balance: 20,
            tier: 'free',
            allowance: 20,
            resetAt: DateTime(2026, 9),
            updatedAt: DateTime(2026, 8, 20),
          ),
        ),
        settingsUiActionsProvider.overrideWith(
          (Ref ref) => _FakeSettingsUiActions(ref),
        ),
        notificationPermissionListenableProvider.overrideWithValue(
          permissionListenable,
        ),
        if (decisionOutcomes != null)
          decisionOutcomesProvider.overrideWith(
            (Ref ref) async => decisionOutcomes,
          ),
        if (learningPaused != null)
          learningPausedProvider.overrideWith(
            (Ref ref) async => learningPaused,
          ),
        if (accountScope != null)
          accountStorageScopeProvider.overrideWithValue(accountScope),
        if (personContextRepository != null)
          personContextRepositoryProvider.overrideWithValue(
            personContextRepository,
          ),
        if (personContext != null)
          personContextClockProvider.overrideWithValue(
            () => personContext.updatedAt,
          ),
        personContextSpineProvider.overrideWith((Ref ref) {
          if (personContextError != null) throw personContextError;
          return personContext;
        }),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  void useTallSurface(WidgetTester tester) {
    tester.platformDispatcher.views.first
      ..physicalSize = const Size(1200, 2400)
      ..devicePixelRatio = 1.0;
    addTearDown(() {
      tester.platformDispatcher.views.first
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });
  }

  Future<void> invokeNavTile(WidgetTester tester, String label) async {
    final Finder tile = find.ancestor(
      of: find.text(label),
      matching: find.byType(GestureDetector),
    );
    expect(tile, findsOneWidget);
    tester.widget<GestureDetector>(tile).onTap!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('hides plans and credits while subscriptions are contained', (
    WidgetTester tester,
  ) async {
    useTallSurface(tester);
    final ProviderContainer container = createContainer();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('SETTINGS'), findsOneWidget);
    expect(find.text('PREFERENCES & ACCOUNT'), findsOneWidget);
    expect(find.text('PLAN & CREDITS'), findsNothing);
    expect(find.text('SUBSCRIPTION'), findsNothing);
    expect(find.text('20 of 20 available'), findsNothing);
    expect(find.text('Manage plan'), findsNothing);
    expect(find.text('View credits'), findsNothing);

    expect(find.text('Appearance & permissions'), findsOneWidget);
    expect(find.text('Planning & guidance'), findsOneWidget);
    expect(find.text('Data & account'), findsOneWidget);
    expect(find.text('Help & legal'), findsOneWidget);
    expect(find.text('Developer & diagnostics'), findsOneWidget);
    expect(find.text('APPEARANCE & PERMISSIONS'), findsNothing);

    await tester.tap(find.text('Appearance & permissions'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('APPEARANCE & PERMISSIONS'), findsOneWidget);
  });

  testWidgets('external AI is disclosed as unavailable instead of enabled', (
    WidgetTester tester,
  ) async {
    useTallSurface(tester);
    final ProviderContainer container = createContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('Planning & guidance'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('External AI assistance'), findsOneWidget);
    expect(
      find.text(
        'Unavailable while privacy, safety, and cost gates are completed.',
      ),
      findsOneWidget,
    );
    expect(find.text('Allow external AI assistance'), findsNothing);
    expect(find.text('PERSON CONTEXT'), findsOneWidget);
    expect(find.text('Person context unavailable'), findsOneWidget);
    expect(
      find.text(
        'A verified signed-in account is required. No personal context will be invented.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Context entry opens its governance controls directly', (
    WidgetTester tester,
  ) async {
    useTallSurface(tester);
    final AccountStorageScope scope = AccountStorageScope.authenticated(
      'context-entry-account',
    );
    final ProviderContainer container = createContainer(
      accountScope: scope,
      personContext: PersonContextSpine(
        accountScopeId: scope.v2Namespace!,
        updatedAt: DateTime.utc(2026, 9, 2),
        signals: const <PersonContextSignal>[],
      ),
    );
    container.read(personContextSettingsEntryProvider.notifier).request();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('PERSON CONTEXT'), findsOneWidget);
    expect(find.text('Add person context'), findsOneWidget);
    expect(container.read(personContextSettingsEntryProvider), isFalse);
  });

  testWidgets('separates user-authored identity context from current state', (
    WidgetTester tester,
  ) async {
    useTallSurface(tester);
    final DateTime now = DateTime.utc(2026, 8, 30, 12);
    final AccountStorageScope scope = AccountStorageScope.authenticated(
      'settings-account',
    );
    final PersonContextSpine spine = PersonContextSpine(
      accountScopeId: scope.v2Namespace!,
      updatedAt: now,
      signals: <PersonContextSignal>[
        PersonContextSignal(
          id: 'role-parent',
          kind: PersonContextKind.role,
          value: 'Parent',
          source: PersonContextSource.userAuthored,
          consent: PersonContextConsent.granted,
          consentedAt: now,
          purpose: PersonContextPurpose.decisionSupport,
          surfaceScopes: const <PersonContextSurface>{
            PersonContextSurface.smartPlanner,
          },
          recordedAt: now,
          freshUntil: now.add(const Duration(days: 30)),
          expiresAt: now.add(const Duration(days: 60)),
          exportBehavior: PersonContextExportBehavior.include,
          deletionBehavior: PersonContextDeletionBehavior.userRemovable,
        ),
      ],
    );
    final ProviderContainer container = createContainer(
      personContext: spine,
      accountScope: scope,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.scrollUntilVisible(
      find.text('Planning & guidance'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Planning & guidance'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('About you'), findsOneWidget);
    expect(find.text('1 reviewable item'), findsOneWidget);
    expect(find.text('Right now'), findsOneWidget);
    expect(find.text('Not provided'), findsOneWidget);
    expect(
      find.text(
        'Stored only on this device. Person Context is excluded from backup and sync, and will not be restored after reinstalling ChronoSpark or changing devices.',
      ),
      findsOneWidget,
    );

    await invokeNavTile(tester, 'Add person context');

    expect(find.text('Add person context'), findsNWidgets(2));
    expect(
      find.text(
        'Before you opt in: Person Context is stored only on this device, excluded from backup and sync, and will not be restored after reinstalling ChronoSpark or changing devices.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Settings review is administrative and does not require behavioral consent.',
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    container.dispose();
  });

  testWidgets(
    'corrupt Person Context recovery requires confirmation and preserves other data',
    (WidgetTester tester) async {
      useTallSurface(tester);
      final AccountStorageScope scope = AccountStorageScope.authenticated(
        'corrupt-settings-account',
      );
      final _MemoryStore store = _MemoryStore();
      final PersonContextRepository repository = PersonContextRepository(
        store,
        scope,
      );
      store.values[repository.storageKey!] = '{corrupt-active';
      store.values[repository.corruptionKey!] = '{recoverable-copy';
      store.values['tasks-sentinel'] = 'tasks stay';
      store.values['goals-sentinel'] = 'goals stay';
      store.values['timeline-sentinel'] = 'Timeline stays';
      final ProviderContainer container = createContainer(
        accountScope: scope,
        personContextError: const PersonContextCorruptionException(),
        personContextRepository: repository,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.scrollUntilVisible(
        find.text('Planning & guidance'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await invokeNavTile(tester, 'Planning & guidance');

      expect(find.text('Person context unavailable'), findsOneWidget);
      expect(find.text('Clear corrupt Person Context data'), findsOneWidget);

      await invokeNavTile(tester, 'Clear corrupt Person Context data');

      expect(
        find.text('Permanently clear corrupt Person Context?'),
        findsOneWidget,
      );
      expect(
        find.text(
          'This permanently clears only recoverable or corrupt Person Context payloads stored on this device. Tasks, goals, and Timeline items are unaffected. This cannot be undone.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(store.values[repository.storageKey!], '{corrupt-active');
      expect(store.values[repository.corruptionKey!], '{recoverable-copy');

      await invokeNavTile(tester, 'Clear corrupt Person Context data');
      await tester.tap(
        find.byKey(const Key('person-context-confirm-clear-corrupt')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(store.values[repository.storageKey!], isNull);
      expect(store.values[repository.corruptionKey!], isNull);
      expect(store.values['tasks-sentinel'], 'tasks stay');
      expect(store.values['goals-sentinel'], 'goals stay');
      expect(store.values['timeline-sentinel'], 'Timeline stays');
      expect(find.text('Corrupt Person Context data cleared.'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      container.dispose();
    },
  );

  testWidgets('transient Person Context errors never offer deletion', (
    WidgetTester tester,
  ) async {
    useTallSurface(tester);
    final ProviderContainer container = createContainer(
      accountScope: AccountStorageScope.authenticated('transient-account'),
      personContextError: StateError('storage temporarily unavailable'),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Planning & guidance'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Person context temporarily unavailable'), findsOneWidget);
    expect(find.text('Retry person context'), findsOneWidget);
    expect(find.text('Clear corrupt Person Context data'), findsNothing);
    expect(find.textContaining('Permanently clear'), findsNothing);
  });

  testWidgets('shows a reviewable user-controlled learning ledger', (
    WidgetTester tester,
  ) async {
    useTallSurface(tester);
    final DateTime now = DateTime.utc(2026, 9, 2, 12);
    final ProviderContainer container = createContainer(
      decisionOutcomes: <DecisionOutcomeEntity>[
        for (int index = 0; index < 3; index += 1)
          DecisionOutcomeEntity(
            decisionId: 'decision-$index',
            kind: DecisionOutcomeKind.accepted,
            surface: 'smart_planner',
            situation: 'bounded planning choice',
            recordedAt: now.subtract(Duration(days: index)),
            modelVersion: 'predictive-planning-v2',
            recommendationConfidence: .64,
            optionChosen: 'minimum',
            optionSizeMinutes: 10,
            recommendationHelped: true,
          ),
      ],
      learningPaused: false,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: appTheme, home: const SettingsScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.runAsync(
      () => precacheImage(
        const AssetImage(AppAssets.bgSettingsControlPlane),
        tester.element(find.byType(SettingsScreen)),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Planning & guidance'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.scrollUntilVisible(
      find.text('WHAT CHANGED FROM YOUR FEEDBACK'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('WHAT CHANGED FROM YOUR FEEDBACK'), findsOneWidget);
    expect(find.text('Use feedback for learning'), findsOneWidget);
    final Finder learningSwitch = find.descendant(
      of: find.byKey(const Key('learning-feedback-toggle')),
      matching: find.byType(Switch),
    );
    expect(tester.widget<Switch>(learningSwitch).value, isTrue);
    expect(find.text('Reviewable observations'), findsOneWidget);
    expect(find.textContaining('maximum 256'), findsOneWidget);
    expect(find.text('RECENT RAW OBSERVATIONS'), findsOneWidget);
    expect(find.text('Export'), findsOneWidget);
    expect(find.text('Delete all'), findsOneWidget);
    expect(find.textContaining('not facts about you'), findsOneWidget);

    await expectLater(
      find.byType(SettingsScreen),
      matchesGoldenFile('goldens/settings_learning_ledger.png'),
    );
  });

  testWidgets(
    'learning controls remain reachable at 320px and 200 percent text',
    (WidgetTester tester) async {
      tester.platformDispatcher.views.first
        ..physicalSize = const Size(320, 568)
        ..devicePixelRatio = 1;
      addTearDown(() {
        tester.platformDispatcher.views.first
          ..resetPhysicalSize()
          ..resetDevicePixelRatio();
      });
      final ProviderContainer container = createContainer(
        decisionOutcomes: <DecisionOutcomeEntity>[
          DecisionOutcomeEntity(
            decisionId: 'small-screen',
            kind: DecisionOutcomeKind.accepted,
            surface: 'smart_planner',
            situation: 'bounded planning choice',
            recordedAt: DateTime.utc(2026, 9, 2),
            modelVersion: 'decision-v1',
            recommendationConfidence: .6,
            optionChosen: 'minimum',
            optionSizeMinutes: 10,
            recommendationHelped: true,
          ),
        ],
        learningPaused: false,
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MediaQuery(
            data: MediaQueryData(
              size: Size(320, 568),
              textScaler: TextScaler.linear(2),
            ),
            child: MaterialApp(home: SettingsScreen()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.scrollUntilVisible(
        find.text('Planning & guidance'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await invokeNavTile(tester, 'Planning & guidance');
      await tester.scrollUntilVisible(
        find.text('Use feedback for learning'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      expect(find.text('Use feedback for learning'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.scrollUntilVisible(
        find.text('Export'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      expect(find.text('Export'), findsOneWidget);
      expect(find.text('Delete all'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _FakeSettingsUiActions extends SettingsUiActions {
  _FakeSettingsUiActions(super.ref);

  @override
  ReflectionReminderPrefs loadReflectionReminderPrefs() {
    return const ReflectionReminderPrefs(
      enabled: false,
      time: TimeOfDay(hour: 20, minute: 0),
    );
  }

  @override
  Future<bool> setReflectionReminderEnabled({
    required bool enabled,
    required TimeOfDay time,
  }) async {
    return enabled;
  }

  @override
  Future<void> setReflectionReminderTime({required TimeOfDay time}) async {}

  @override
  Future<bool> requestNotificationPermission() async => true;

  @override
  Future<bool> requestVoicePermission() async => true;

  @override
  Future<bool> openSystemAppSettings() async => true;
}

class _MemoryStore implements SharedPrefsStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> init() async {}

  @override
  String? load(String key) => values[key];

  @override
  Future<void> save(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<void> clear() async => values.clear();
}
