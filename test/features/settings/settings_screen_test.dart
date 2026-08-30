import 'package:fantastic_guacamole/features/settings/ui/settings_screen.dart';
import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/state/models/ai_credit_wallet.dart';
import 'package:fantastic_guacamole/state/providers/paywall_provider.dart';
import 'package:fantastic_guacamole/state/providers/settings_ui_provider.dart';
import 'package:fantastic_guacamole/state/services/reflection_reminder_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

  ProviderContainer createContainer() {
    final ValueNotifier<bool?> permissionListenable = ValueNotifier<bool?>(
      true,
    );
    addTearDown(permissionListenable.dispose);

    final ProviderContainer container = ProviderContainer(
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
  });
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
