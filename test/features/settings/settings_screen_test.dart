import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/tutorial/guidance_catalogue.dart';
import 'package:fantastic_guacamole/tutorial/guide_hint_place.dart';
import 'package:fantastic_guacamole/config/env.dart';
import 'package:flutter/rendering.dart';
import 'package:fantastic_guacamole/data/services/mock_auth_service.dart';
import 'package:fantastic_guacamole/state/providers/auth_provider.dart';
import 'package:fantastic_guacamole/features/settings/ui/settings_screen.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/data/repositories/person_context_repository.dart';
import 'package:fantastic_guacamole/data/services/sync_service.dart';
import 'package:fantastic_guacamole/state/providers/sync_provider.dart'
    show CloudBackupAttention;
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/person_context.dart';
import 'package:fantastic_guacamole/domain/entities/decision_outcome_entity.dart';
import 'package:fantastic_guacamole/state/models/ai_credit_wallet.dart';
import 'package:fantastic_guacamole/state/providers/paywall_provider.dart';
import 'package:fantastic_guacamole/state/providers/access_provider.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/person_context_provider.dart';
import 'package:fantastic_guacamole/state/providers/decision_outcome_provider.dart';
import 'package:fantastic_guacamole/state/providers/settings_ui_provider.dart';
import 'package:fantastic_guacamole/state/services/reflection_reminder_service.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
import 'package:fantastic_guacamole/theme/app_theme.dart';
import 'package:fantastic_guacamole/ui/constants/app_assets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fantastic_guacamole/state/providers/personalization_provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';

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

  test('destructive settings copy covers Spanish outcomes and recovery', () {
    const SettingsSafetyCopy copy = SettingsSafetyCopy(isSpanish: true);

    expect(copy.clearDeviceTitle, '¿Borrar los datos de este dispositivo?');
    expect(copy.localRemovalDisclosure, contains('no se puede deshacer'));
    expect(copy.deletedCloudCannotRestore, contains('no se pueden restaurar'));
    expect(copy.subscriptionNotCanceled, contains('Google Play'));
    expect(copy.deletionCouldNotComplete, contains('solicitud de soporte'));
    expect(
      copy.friendlyDeleteError('wrong-password'),
      'La contraseña es incorrecta.',
    );
    expect(
      copy.friendlyDeleteError('network-request-failed'),
      copy.deletionCouldNotComplete,
    );
    expect(
      accountDeletionOutcomeMessage(
        const AccountDeletionResult.pending(
          serverState: 'requested',
          statusTrackingAvailable: false,
        ),
        isSpanish: true,
      ),
      allOf(contains('sigue en curso'), contains('no se pudo guardar')),
    );
  });

  test('last backup line is truthful in every backup state', () {
    const CloudBackupStatusCopy en = CloudBackupStatusCopy(isSpanish: false);
    const CloudBackupStatusCopy es = CloudBackupStatusCopy(isSpanish: true);

    expect(en.lastBackupTitle, 'Last backup');
    expect(es.lastBackupTitle, 'Última copia de seguridad');
    // Automatic backups are partial only until a full backup exists.
    expect(
      en.recoveryCoverage,
      allOf(
        contains(
          'automatic backups made before your first full backup, include only tasks, profile and settings',
        ),
        contains(
          'After a full backup, automatic backups keep all of it up to date',
        ),
      ),
    );
    expect(
      es.recoveryCoverage,
      allOf(
        contains(
          'las automáticas hechas antes de tu primera copia completa, incluyen solo tareas, perfil y ajustes',
        ),
        contains('las copias automáticas lo mantienen todo al día'),
      ),
    );
    expect(en.recoveryCoverage, isNot(contains('may only include')));
    expect(
      en.storageScopeOn,
      'Encrypted backups go to your account: tasks, profile and settings until you make a full backup, then all planning data.',
    );
    expect(
      es.storageScopeOn,
      'Las copias cifradas se guardan en tu cuenta: tareas, perfil y ajustes hasta que hagas una copia completa, y después todos los datos de planificación.',
    );
    expect(
      en.lastBackupValue('Nov 20, 2026 · 9:30 AM'),
      'Nov 20, 2026 · 9:30 AM.',
    );
    expect(es.lastBackupValue('20 nov 2026 · 9:30'), '20 nov 2026 · 9:30.');
    // No record here does not claim that nothing is in the cloud.
    expect(
      en.lastBackupValue(null),
      'This device has not made or restored a cloud backup yet.',
    );
    expect(
      es.lastBackupValue(null),
      'Este dispositivo todavía no ha hecho ni restaurado una copia en la nube.',
    );

    const unlinked = CloudBackupAttention.fullBackupNotLinked;
    expect(
      en.lastBackupValue(null, attention: unlinked),
      "A full backup is in the cloud, but this device did not make it. Press Back up all planning data once to keep it up to date automatically. If you use several devices, restore first: that button replaces the cloud copy with this device's data.",
    );
    expect(
      es.lastBackupValue(null, attention: unlinked),
      'Hay una copia completa en la nube, pero no la hizo este dispositivo. Pulsa Guardar todos los datos una vez para mantenerla al día automáticamente. Si usas varios dispositivos, restaura primero: ese botón reemplaza la copia en la nube con los datos de este dispositivo.',
    );

    const changed = CloudBackupAttention.changedOnAnotherDevice;
    final String enChanged = en.lastBackupValue(
      'Nov 20, 2026 · 9:30 AM',
      attention: changed,
    );
    expect(enChanged, startsWith('Nov 20, 2026 · 9:30 AM. '));
    expect(enChanged, contains('changed on another device'));
    expect(enChanged, contains('Restore cloud backup'));
    expect(
      enChanged,
      contains(
        "Back up all planning data would replace the other device's newer copy",
      ),
    );
    final String esChanged = es.lastBackupValue(
      '20 nov 2026 · 9:30',
      attention: changed,
    );
    expect(esChanged, startsWith('20 nov 2026 · 9:30. '));
    expect(esChanged, contains('cambió en otro dispositivo'));
    expect(esChanged, contains('Restaurar copia en la nube'));
    expect(
      esChanged,
      contains(
        'Guardar todos los datos reemplazaría la copia más reciente del otro dispositivo',
      ),
    );
  });

  test('backup recovery key copy never claims a key that does not exist', () {
    const BackupRecoveryKeyCopy en = BackupRecoveryKeyCopy(isSpanish: false);
    const BackupRecoveryKeyCopy es = BackupRecoveryKeyCopy(isSpanish: true);

    expect(en.noKeyTitle, 'No backup key on this device yet');
    expect(
      es.noKeyTitle,
      'Todavía no hay una clave de respaldo en este dispositivo',
    );
    expect(en.noKeyBody, contains('Restore key'));
    expect(es.noKeyBody, contains('Restaurar clave'));

    expect(
      en.importOutcome(RecoveryKeyImportOutcome.doesNotMatch),
      'This key does not match your cloud backup. Your current key was not changed.',
    );
    expect(
      es.importOutcome(RecoveryKeyImportOutcome.doesNotMatch),
      'Esta clave no coincide con tu copia en la nube. Tu clave actual no se cambió.',
    );
    for (final RecoveryKeyImportOutcome refused in const [
      RecoveryKeyImportOutcome.doesNotMatch,
      RecoveryKeyImportOutcome.backupUnreadable,
      RecoveryKeyImportOutcome.cloudUnavailable,
      RecoveryKeyImportOutcome.cloudBackupOff,
      RecoveryKeyImportOutcome.ownerMismatch,
      RecoveryKeyImportOutcome.accountChanged,
    ]) {
      expect(en.importOutcome(refused), contains('not changed'));
      expect(es.importOutcome(refused), contains('no se cambió'));
    }
    // A right key on a damaged backup is not called a wrong key.
    expect(
      en.importOutcome(RecoveryKeyImportOutcome.backupUnreadable),
      allOf(contains('damaged'), isNot(contains('does not match'))),
    );
    expect(
      es.importOutcome(RecoveryKeyImportOutcome.backupUnreadable),
      allOf(contains('dañada'), isNot(contains('no coincide'))),
    );
    // An owner mismatch is not described as an account change.
    expect(
      en.importOutcome(RecoveryKeyImportOutcome.ownerMismatch),
      allOf(
        contains('signed in to the cloud'),
        isNot(contains('changed before')),
      ),
    );
    expect(
      es.importOutcome(RecoveryKeyImportOutcome.ownerMismatch),
      contains('conectada a la nube'),
    );
    // Off or offline: the user is told plainly what to do first.
    expect(
      en.importOutcome(RecoveryKeyImportOutcome.cloudBackupOff),
      startsWith('Turn on Cloud Backup first'),
    );
    expect(
      es.importOutcome(RecoveryKeyImportOutcome.cloudBackupOff),
      startsWith('Primero activa la copia en la nube'),
    );
    expect(
      en.importOutcome(RecoveryKeyImportOutcome.cloudUnavailable),
      contains('Get online'),
    );
    expect(
      es.importOutcome(RecoveryKeyImportOutcome.cloudUnavailable),
      contains('Conéctate a internet'),
    );
    // The confirmation before an import no longer promises a replacement.
    for (final BackupRecoveryKeyCopy copy in const [en, es]) {
      expect(copy.checkKeyTitle, isNot(contains('Replace')));
      expect(copy.checkKeyAction, isNot(contains('Reemplazar')));
    }
    expect(en.checkKeyBody, contains('only if it opens the backup'));
    expect(es.checkKeyBody, contains('solo si abre la copia'));
    expect(en.checkKeyAction, 'Check and use key');
    expect(es.checkKeyAction, 'Comprobar y usar clave');
    expect(
      en.importOutcome(RecoveryKeyImportOutcome.installedUnverified),
      contains('previous key is kept'),
    );
    expect(
      es.importOutcome(RecoveryKeyImportOutcome.installedUnverified),
      contains('clave anterior se conserva'),
    );
    expect(
      en.importOutcome(RecoveryKeyImportOutcome.invalidFormat),
      'That recovery key is not valid.',
    );
    expect(
      es.importOutcome(RecoveryKeyImportOutcome.invalidFormat),
      'Esa clave de recuperación no es válida.',
    );
    for (final RecoveryKeyImportOutcome outcome
        in RecoveryKeyImportOutcome.values) {
      expect(en.importOutcome(outcome), isNot(es.importOutcome(outcome)));
    }
  });

  ProviderContainer createContainer({
    MockAuthService? authService,
    PersonContextSpine? personContext,
    AccountStorageScope? accountScope,
    Object? personContextError,
    PersonContextRepository? personContextRepository,
    List<DecisionOutcomeEntity>? decisionOutcomes,
    bool? learningPaused,
    DateTime? learningNow,
    bool billingAccess = false,
    bool billingCreditAccess = false,
    bool guideReady = false,
    AiCreditWallet? wallet,
    bool? notificationPermission = true,
    bool noTasks = false,
  }) {
    final AccountStorageScope resolvedScope =
        accountScope ??
        AccountStorageScope.authenticated('settings-test-account');
    final ValueNotifier<bool?> permissionListenable = ValueNotifier<bool?>(
      notificationPermission,
    );
    addTearDown(permissionListenable.dispose);

    final ProviderContainer container = ProviderContainer(
      retry: (int retryCount, Object error) => null,
      overrides: [
        if (billingAccess)
          appAccessProvider.overrideWithValue(
            AppAccessState(
              hasPremiumAccess: true,
              hasTesterFullAccess: false,
              paywallDisabled: false,
              internalBillingTest: true,
              internalCreditTest: billingCreditAccess,
            ),
          ),
        if (guideReady)
          adaptiveGuidanceProvider.overrideWith(_CopyGuidance.new),
        if (authService != null)
          authServiceProvider.overrideWithValue(authService),
        accountStorageScopeProvider.overrideWithValue(resolvedScope),
        // The guide reads saved tasks when it loads; there are none here.
        if (noTasks) domainTaskRepositoryProvider.overrideWithValue(_NoTasks()),
        accountLegacyOwnershipProvider.overrideWithValue(
          LegacyScopeOwnership.provenNotOwned,
        ),
        aiCreditWalletProvider.overrideWith(
          (Ref ref) async =>
              wallet ??
              AiCreditWallet(
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
        if (learningNow != null)
          learningLedgerClockProvider.overrideWithValue(() => learningNow),
        if (learningPaused != null)
          learningPausedProvider.overrideWith(
            (Ref ref) async => learningPaused,
          ),
        if (personContextRepository != null)
          personContextRepositoryProvider.overrideWithValue(
            personContextRepository,
          ),
        if (personContext != null)
          personContextClockProvider.overrideWithValue(
            () => personContext.updatedAt,
          ),
        personContextSpineProvider.overrideWith((Ref ref) {
          if (personContextError case final Exception error) {
            throw error;
          }
          if (personContextError case final Error error) {
            throw error;
          }
          if (personContextError != null) {
            throw StateError(
              'Unsupported test failure type: ${personContextError.runtimeType}',
            );
          }
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

  for (final es in [false, true]) {
    testWidgets(
      '${es ? 'Spanish' : 'English'} Settings use current Chat and plain guide descriptions',
      (tester) async {
        useTallSurface(tester);
        final container = createContainer(
          billingAccess: true,
          billingCreditAccess: true,
          guideReady: true,
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              locale: Locale(es ? 'es' : 'en'),
              supportedLocales: ChronoSparkLocalizations.supportedLocales,
              localizationsDelegates: const [
                ChronoSparkLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: const SettingsScreen(),
            ),
          ),
        );
        addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          find.textContaining(
            es
                ? 'Elegir un paso y Chat pueden usar IA externa'
                : 'Choose a step and Chat can use external AI',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining('Choose a step and SI Chat can use external AI'),
          findsNothing,
        );
        await invokeNavTile(
          tester,
          es ? 'Planificación y orientación' : 'Planning & guidance',
        );
        final guide = es
            ? 'Vuelve a mostrar la guía sin cambiar tu trabajo ni tu actividad guardados.'
            : 'Shows the guide again without changing your saved work or activity.';
        final setup = es
            ? 'Vuelve a abrir la bienvenida y la configuración de la cuenta. Conserva tu trabajo guardado y el progreso de la guía.'
            : 'Reopens welcome and account setup. Keeps your saved work and guide progress.';
        await tester.scrollUntilVisible(
          find.text(guide),
          400,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(guide).hitTestable(), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text(setup),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(setup).hitTestable(), findsOneWidget);
        expect(find.textContaining('contextual intervention'), findsNothing);
        expect(find.textContaining('intervención contextual'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final theme in [appTheme, appLightTheme]) {
    testWidgets(
      '${theme.brightness.name} planning preference fields and menus remain readable',
      (tester) async {
        final previousFatal = WidgetController.hitTestWarningShouldBeFatal;
        WidgetController.hitTestWarningShouldBeFatal = true;
        addTearDown(
          () => WidgetController.hitTestWarningShouldBeFatal = previousFatal,
        );
        useTallSurface(tester);
        final container = createContainer();
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(theme: theme, home: const SettingsScreen()),
          ),
        );
        addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.scrollUntilVisible(
          find.text('Planning & guidance'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await invokeNavTile(tester, 'Planning & guidance');
        final before = container.read(personalizationProfileProvider);
        double contrast(Color foreground, Color background) {
          final first = Color.alphaBlend(
            foreground,
            background,
          ).computeLuminance();
          final second = background.computeLuminance();
          return first > second
              ? (first + .05) / (second + .05)
              : (second + .05) / (first + .05);
        }

        for (final label in [
          'Planning style',
          'Priority strategy',
          'Missed-task recovery',
        ]) {
          await tester.scrollUntilVisible(
            find.text(label),
            250,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pump(const Duration(milliseconds: 350));
          final field = find
              .ancestor(
                of: find.text(label),
                matching: find.byType(DropdownButtonFormField<String>),
              )
              .first;
          final decorator = tester.widget<InputDecorator>(
            find.descendant(of: field, matching: find.byType(InputDecorator)),
          );
          final fill = Color.alphaBlend(
            decorator.decoration.fillColor!,
            const Color(0xFF050D1A),
          );
          var paintedLabels = 0;
          for (final element
              in find
                  .descendant(of: field, matching: find.byType(RichText))
                  .evaluate()) {
            final paragraph = element.renderObject! as RenderParagraph;
            if (paragraph.text.toPlainText().trim().isEmpty) continue;
            paintedLabels++;
            expect(
              contrast(paragraph.text.style!.color!, fill),
              greaterThanOrEqualTo(4.5),
              reason: label,
            );
          }
          expect(paintedLabels, greaterThanOrEqualTo(2), reason: label);
        }
        final field = find
            .ancestor(
              of: find.text('Planning style'),
              matching: find.byType(DropdownButtonFormField<String>),
            )
            .first;
        final button = find.descendant(
          of: field,
          matching: find.byType(DropdownButton<String>),
        );
        await tester.ensureVisible(button);
        await tester.pump(const Duration(milliseconds: 350));
        expect(button.hitTestable(), findsOneWidget);
        final dropdown = tester.widget<DropdownButton<String>>(button);
        final alternate = dropdown.items!.firstWhere(
          (item) => item.value != dropdown.value,
        );
        final alternateLabel = (alternate.child as Text).data!;
        await tester.tap(button.hitTestable());
        await tester.pump(const Duration(milliseconds: 350));
        final menuText = find.text(alternateLabel).last;
        expect(menuText.hitTestable(), findsOneWidget);
        // Flutter 3.44 paints the menu behind a transparent Material. Inspect
        // that painter's actual color rather than the transparent wrapper.
        final paintedMenu = find.ancestor(
          of: menuText,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is CustomPaint &&
                widget.painter?.runtimeType.toString() ==
                    '_DropdownMenuPainter',
          ),
        );
        expect(paintedMenu, findsOneWidget);
        final painter = tester.widget<CustomPaint>(paintedMenu).painter!;
        // The pinned Flutter painter type is private; its public color getter
        // is the actual BoxDecoration fill. Fail if that API or type changes.
        // ignore: avoid_dynamic_calls
        final menuColor = (painter as dynamic).color as Color;
        final paragraph = tester.renderObject<RenderParagraph>(menuText);
        expect(menuColor, theme.colorScheme.surface);
        expect(
          contrast(paragraph.text.style!.color!, menuColor),
          greaterThanOrEqualTo(4.5),
        );
        expect(Theme.of(tester.element(menuText)).brightness, theme.brightness);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump(const Duration(milliseconds: 350));
        final after = container.read(personalizationProfileProvider);
        expect(after.planningStyle, before.planningStyle);
        expect(after.priorityStrategy, before.priorityStrategy);
        expect(after.recoveryPolicy, before.recoveryPolicy);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('mounted reminder controls reload restored settings', (
    tester,
  ) async {
    final container = createContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.scrollUntilVisible(
      find.text('Notifications'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await invokeNavTile(tester, 'Notifications');
    final actions =
        container.read(settingsUiActionsProvider) as _FakeSettingsUiActions;
    final before = actions.advancedLoads;
    expect(before, greaterThan(0));
    expect(find.text('Reminder Time'), findsNothing);
    actions.reflectionPrefs = const ReflectionReminderPrefs(
      enabled: true,
      time: TimeOfDay(hour: 9, minute: 30),
    );
    container.read(restoredSettingsRevisionProvider.notifier).bump();
    await tester.pump();
    expect(find.text('Reminder Time'), findsOneWidget);
    // The main switch, the reminder rules and quiet hours each reload.
    expect(actions.advancedLoads, before + 3);
    expect(tester.takeException(), isNull);
  });

  for (final es in [false, true]) {
    testWidgets('the task reminder switch saves the choice (es=$es)', (
      tester,
    ) async {
      useTallSurface(tester);
      final container = createContainer();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: Locale(es ? 'es' : 'en'),
            supportedLocales: ChronoSparkLocalizations.supportedLocales,
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              ChronoSparkLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const SettingsScreen(),
          ),
        ),
      );
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
      await tester.pump(const Duration(milliseconds: 200));
      await invokeNavTile(tester, es ? 'Notificaciones' : 'Notifications');
      final title = find.text(
        es ? 'Recordatorios de tareas' : 'Task Reminders',
      );
      await tester.scrollUntilVisible(
        title,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.textContaining(
          es
              ? 'Solo se programan las 20 siguientes a la vez.'
              : 'Only the next 20 are set at once.',
        ),
        findsOneWidget,
      );
      final Finder toggle = find.descendant(
        of: find.byKey(const Key('task-reminders-toggle')),
        matching: find.byType(Switch),
      );
      expect(tester.widget<Switch>(toggle).value, isTrue);
      await tester.tap(toggle);
      await tester.pump(const Duration(milliseconds: 200));

      final actions =
          container.read(settingsUiActionsProvider) as _FakeSettingsUiActions;
      expect(actions.taskReminderWrites, [false]);
      expect(tester.widget<Switch>(toggle).value, isFalse);
    });
  }

  Future<ProviderContainer> openNotifications(
    WidgetTester tester, {
    bool es = false,
    bool? permission = true,
    void Function(_FakeSettingsUiActions actions)? arrange,
    bool noTasks = false,
  }) async {
    useTallSurface(tester);
    final container = createContainer(
      notificationPermission: permission,
      noTasks: noTasks,
    );
    arrange?.call(
      container.read(settingsUiActionsProvider) as _FakeSettingsUiActions,
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: Locale(es ? 'es' : 'en'),
          supportedLocales: ChronoSparkLocalizations.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            ChronoSparkLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const SettingsScreen(),
        ),
      ),
    );
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await tester.pump(const Duration(milliseconds: 200));
    await invokeNavTile(tester, es ? 'Notificaciones' : 'Notifications');
    return container;
  }

  Switch switchIn(WidgetTester tester, String key) => tester.widget<Switch>(
    find.descendant(of: find.byKey(Key(key)), matching: find.byType(Switch)),
  );

  Finder healthText(String text) => find.descendant(
    of: find.byKey(const Key('reminder-health-row')),
    matching: find.text(text),
  );

  for (final es in [false, true]) {
    testWidgets('the main reminder switch turns reminders off, says so at '
        'the top and holds the other controls (es=$es)', (tester) async {
      final container = await openNotifications(tester, es: es);
      expect(
        healthText(
          es
              ? 'Los recordatorios pueden llegar a este dispositivo.'
              : 'Reminders can arrive on this device.',
        ),
        findsOneWidget,
      );
      expect(switchIn(tester, 'reminders-main-toggle').value, isTrue);
      expect(switchIn(tester, 'task-reminders-toggle').onChanged, isNotNull);

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('reminders-main-toggle')),
          matching: find.byType(Switch),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      final actions =
          container.read(settingsUiActionsProvider) as _FakeSettingsUiActions;
      expect(actions.mainSwitchWrites, [false]);
      expect(switchIn(tester, 'reminders-main-toggle').value, isFalse);
      expect(
        healthText(
          es
              ? 'Los recordatorios están desactivados. Activa Recordatorios abajo para volver a recibirlos.'
              : 'Reminders are off. Turn on Reminders below to get them again.',
        ),
        findsOneWidget,
      );
      // Each feature keeps its choice but cannot change while all are off.
      expect(switchIn(tester, 'task-reminders-toggle').value, isTrue);
      expect(switchIn(tester, 'task-reminders-toggle').onChanged, isNull);
      expect(switchIn(tester, 'overdue-nudges-toggle').onChanged, isNull);
      expect(switchIn(tester, 'quiet-hours-toggle').onChanged, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the habit and goal rules describe chosen days and the '
        'evening reminder (es=$es)', (tester) async {
      await openNotifications(tester, es: es);
      final Finder habitRule = find.textContaining(
        es
            ? 'los días de la semana que elijas (el lunes si no eliges ninguno)'
            : 'on the days of the week you chose (Monday if none)',
      );
      await tester.scrollUntilVisible(
        habitRule,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(habitRule, findsOneWidget);
      expect(
        find.textContaining(
          es
              ? 'el día del mes que elijas (el día 1 si no eliges ninguno)'
              : 'on the day of the month you chose (the 1st if none)',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(es ? 'al crearlo' : 'when you create it'),
        findsOneWidget,
      );
      expect(
        find.textContaining(es ? 'los lunes o el primer' : 'Mondays, or the'),
        findsNothing,
      );
      expect(
        find.textContaining(
          es
              ? 'recibes un aviso a las 18:00'
              : 'gets one reminder at 6 PM instead',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          es
              ? 'Con Avisos de vencidos activado, otro a las 9:00'
              : 'With Overdue nudges on, one more at 9 AM',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('lead time, overdue nudges and quiet hours save the choice '
        '(es=$es)', (tester) async {
      final container = await openNotifications(tester, es: es);
      final actions =
          container.read(settingsUiActionsProvider) as _FakeSettingsUiActions;

      final Finder lead = find.text(es ? 'A la hora' : 'At the time');
      await tester.ensureVisible(lead);
      await tester.tap(lead);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(
        find.text(es ? '15 minutos antes' : '15 minutes before'),
      );
      await tester.pump(const Duration(milliseconds: 350));
      expect(actions.leadWrites, [15]);

      final Finder overdue = find.descendant(
        of: find.byKey(const Key('overdue-nudges-toggle')),
        matching: find.byType(Switch),
      );
      expect(tester.widget<Switch>(overdue).value, isFalse);
      await tester.ensureVisible(overdue);
      await tester.tap(overdue);
      await tester.pump(const Duration(milliseconds: 200));
      expect(actions.overdueWrites, [true]);

      final Finder quiet = find.descendant(
        of: find.byKey(const Key('quiet-hours-toggle')),
        matching: find.byType(Switch),
      );
      expect(tester.widget<Switch>(quiet).value, isFalse);
      await tester.ensureVisible(quiet);
      await tester.tap(quiet);
      await tester.pump(const Duration(milliseconds: 200));
      expect(actions.quietWrites, hasLength(1));
      expect(actions.quietWrites.single.enabled, isTrue);
      expect(actions.quietWrites.single.startMinutes, 22 * 60);
      expect(actions.quietWrites.single.endMinutes, 7 * 60);
      expect(find.text(es ? 'Empieza' : 'Starts'), findsOneWidget);
      expect(find.text(es ? 'Termina' : 'Ends'), findsOneWidget);
      expect(
        find.textContaining(
          es
              ? 'Las horas que elegiste tú (hábitos, planificación diaria, reflexión) no se mueven.'
              : 'Times you chose yourself (habits, daily planning, reflection) are not moved.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('with notifications off the top row says why and offers the '
        'same step as the notice (es=$es)', (tester) async {
      await openNotifications(tester, es: es, permission: false);
      expect(
        healthText(
          es
              ? 'Las notificaciones de Axiomara están desactivadas, así que los recordatorios no pueden llegar.'
              : 'Notifications are off for Axiomara, so reminders cannot arrive.',
        ),
        findsOneWidget,
      );
      expect(
        healthText(es ? 'Activar notificaciones' : 'Turn on notifications'),
        findsOneWidget,
      );
    });
  }

  for (final es in [false, true]) {
    testWidgets('when the device reminders cannot be updated the main switch '
        'says so and offers to try again (es=$es)', (tester) async {
      final container = await openNotifications(
        tester,
        es: es,
        arrange: (actions) => actions.mainSwitchApplies = false,
      );
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('reminders-main-toggle')),
          matching: find.byType(Switch),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        find.text(
          es
              ? 'Los recordatorios están desactivados, pero algunos aún no se pudieron detener.'
              : 'Reminders are off, but some could not be stopped yet.',
        ),
        findsOneWidget,
      );
      final actions =
          container.read(settingsUiActionsProvider) as _FakeSettingsUiActions;
      actions.mainSwitchApplies = true;
      // Let the message finish sliding in.
      await tester.pump(const Duration(milliseconds: 750));
      await tester.tap(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text(es ? 'Intentar de nuevo' : 'Try again'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(actions.mainSwitchWrites, [false, false]);
    });
  }

  testWidgets('try again still applies the switch after leaving Settings', (
    tester,
  ) async {
    final container = await openNotifications(
      tester,
      arrange: (actions) => actions.mainSwitchApplies = false,
    );
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('reminders-main-toggle')),
        matching: find.byType(Switch),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    final actions =
        container.read(settingsUiActionsProvider) as _FakeSettingsUiActions;
    actions.mainSwitchApplies = true;
    // Leave Settings while the message is still showing: the same app keeps
    // its messenger, so the message moves to the new screen.
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('en'),
          supportedLocales: ChronoSparkLocalizations.supportedLocales,
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            ChronoSparkLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(body: SizedBox.shrink()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 750));
    expect(find.byType(SettingsScreen), findsNothing);
    await tester.tap(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.text('Try again'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(actions.mainSwitchWrites, [false, false]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the open Notifications area is the notification settings '
      'hint place; changing lead time finishes that hint', (tester) async {
    final container = await openNotifications(tester, noTasks: true);
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is GuideHintPlace &&
            widget.place == GuidancePlaces.notificationSettings,
      ),
      findsOneWidget,
    );
    final Finder lead = find.text('At the time');
    await tester.ensureVisible(lead);
    await tester.tap(lead);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('15 minutes before'));
    await tester.pump(const Duration(milliseconds: 350));
    final AdaptiveGuidanceState guidance = await container.read(
      adaptiveGuidanceProvider.future,
    );
    expect(
      guidance.lessonFinishedByAction(GuidanceLessonId.notificationSettings),
      isTrue,
    );
  });

  testWidgets('quiet hours with the same start and end show as off', (
    tester,
  ) async {
    await openNotifications(
      tester,
      arrange: (actions) => actions.storedQuietHours = const QuietHours(
        enabled: true,
        startMinutes: 22 * 60,
        endMinutes: 22 * 60,
      ),
    );
    expect(switchIn(tester, 'quiet-hours-toggle').value, isFalse);
    expect(find.text('Starts'), findsNothing);
  });
  for (final dark in [true, false]) {
    testWidgets(
      'Reflection picker follows dark forms=$dark and Cancel preserves time',
      (tester) async {
        useTallSurface(tester);
        final container = createContainer();
        final actions =
            container.read(settingsUiActionsProvider) as _FakeSettingsUiActions;
        actions.reflectionPrefs = const ReflectionReminderPrefs(
          enabled: true,
          time: TimeOfDay(hour: 20, minute: 0),
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: dark ? appTheme : appLightTheme,
              home: const SettingsScreen(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));
        await tester.scrollUntilVisible(
          find.text('Notifications'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await invokeNavTile(tester, 'Notifications');
        await tester.scrollUntilVisible(
          find.text('Reminder Time'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('8:00 PM'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        final dialog = find.byType(TimePickerDialog);
        expect(dialog, findsOneWidget);
        final pickerTheme = Theme.of(tester.element(dialog));
        expect(
          pickerTheme.brightness,
          dark ? Brightness.dark : Brightness.light,
        );
        final primary = pickerTheme.colorScheme.primary.computeLuminance();
        final onPrimary = pickerTheme.colorScheme.onPrimary.computeLuminance();
        final contrast = primary > onPrimary
            ? (primary + .05) / (onPrimary + .05)
            : (onPrimary + .05) / (primary + .05);
        expect(contrast, greaterThanOrEqualTo(4.5));
        await tester.tap(find.text('Cancel'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(actions.reflectionTimeWrites, 0);
        expect(
          actions.reflectionPrefs.time,
          const TimeOfDay(hour: 20, minute: 0),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final locale in const [Locale('en'), Locale('es')]) {
    testWidgets('cloud recovery scope is readable in ${locale.languageCode}', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = createContainer();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: locale,
            supportedLocales: ChronoSparkLocalizations.supportedLocales,
            localizationsDelegates: const [
              ChronoSparkLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(1.5)),
              child: SettingsScreen(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final section = find.text(
        locale.languageCode == 'es' ? 'Datos y cuenta' : 'Data & account',
      );
      await tester.scrollUntilVisible(
        section,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.tap(section.hitTestable());
      await tester.pump(const Duration(milliseconds: 300));
      final warning = find.textContaining(
        locale.languageCode == 'es'
            ? 'Otros datos de planificación'
            : 'Other planning data',
      );
      if (Env.enableCloudSync) {
        expect(warning, findsOneWidget);
        await tester.scrollUntilVisible(
          warning,
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
        final text = tester.widget<Text>(warning);
        expect(text.maxLines, isNull);
        final paragraph = tester.renderObject<RenderParagraph>(warning);
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(
          text.data,
          contains(
            locale.languageCode == 'es'
                ? 'Podrías perderlos'
                : 'You may lose it',
          ),
        );
      } else {
        expect(warning, findsNothing);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final locale in const [Locale('en'), Locale('es')]) {
    testWidgets('Settings opens localized licenses in ${locale.languageCode}', (
      tester,
    ) async {
      useTallSurface(tester);
      final container = createContainer();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: locale,
            supportedLocales: ChronoSparkLocalizations.supportedLocales,
            localizationsDelegates: const [
              ChronoSparkLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final String helpLabel = locale.languageCode == 'es'
          ? 'Ayuda y aspectos legales'
          : 'Help & legal';
      await tester.ensureVisible(find.text(helpLabel));
      await tester.pump();
      await tester.tap(find.text(helpLabel).hitTestable());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final context = tester.element(find.byType(SettingsScreen));
      final label = MaterialLocalizations.of(context).licensesPageTitle;
      expect(label, locale.languageCode == 'es' ? 'Licencias' : 'Licenses');
      await Scrollable.ensureVisible(
        tester.element(find.text(label)),
        alignment: 0.5,
      );
      await tester.pump();
      await tester.tap(find.text(label).hitTestable());
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 5),
      );

      expect(find.byType(LicensePage), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(LicensePage),
          matching: find.text(label),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(LicensePage),
          matching: find.text('Axiomara'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.descendant(
          of: find.byType(LicensePage),
          matching: find.byType(BackButton),
        ),
      );
      for (
        int frame = 0;
        frame < 10 && find.byType(LicensePage).evaluate().isNotEmpty;
        frame++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.byType(LicensePage), findsNothing);
    });
  }

  testWidgets(
    'sign-out cleanup StateError shows retry and preserves the signed-in account',
    (tester) async {
      useTallSurface(tester);
      int attempts = 0;
      final auth = MockAuthService(
        onBeforeSignedOut: (_) async {
          attempts++;
          throw StateError('Reminder cancellation failed');
        },
      );
      await auth.signInWithGoogle();
      final accountId = auth.currentUser!.id;
      final container = createContainer(authService: auth);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('Data & account'));
      await tester.pump(const Duration(milliseconds: 300));
      final label = find.text('Close Profile').evaluate().isNotEmpty
          ? 'Close Profile'
          : 'Log Out';
      await invokeNavTile(tester, label);
      expect(tester.takeException(), isNull);
      expect(find.text('Could not log out. Please try again.'), findsOneWidget);
      expect(auth.currentUser?.id, accountId);
      expect(attempts, 1);
      await invokeNavTile(tester, label);
      expect(tester.takeException(), isNull);
      expect(auth.currentUser?.id, accountId);
      expect(attempts, 2);
    },
  );

  testWidgets('paid wallet distinguishes included and purchased credits', (
    tester,
  ) async {
    useTallSurface(tester);
    final container = createContainer(
      billingAccess: true,
      wallet: serverAiCreditWallet({
        'tier': 'premium_monthly',
        'balance': 399,
        'purchased_credits': 100,
        'period_credits': 300,
        'period_ends_at': '2026-09-08T04:39:00Z',
      }),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('399 credits available'), findsOneWidget);
    expect(
      find.textContaining('299 included · 100 purchased (do not expire)'),
      findsOneWidget,
    );
    expect(find.textContaining('Free allowance'), findsNothing);
    expect(find.textContaining('Monthly allowance: 300'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Spanish settings localize wallet and account descriptions', (
    tester,
  ) async {
    useTallSurface(tester);
    final container = createContainer(
      billingAccess: true,
      wallet: serverAiCreditWallet({
        'tier': 'premium_monthly',
        'balance': 399,
        'purchased_credits': 100,
        'period_credits': 300,
        'period_ends_at': '2026-09-08T04:39:00Z',
      }),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('es'),
          supportedLocales: ChronoSparkLocalizations.supportedLocales,
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            ChronoSparkLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: SettingsScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('399 créditos disponibles'), findsOneWidget);
    expect(
      find.textContaining('299 incluidos · 100 comprados (no caducan)'),
      findsOneWidget,
    );
    expect(find.textContaining('Asignación mensual: 300'), findsOneWidget);
    expect(find.text('Suscripción de prueba activa'), findsOneWidget);
    expect(
      find.textContaining('Pruebas de licencia de Google Play'),
      findsOneWidget,
    );
    expect(find.textContaining('Test subscription active'), findsNothing);
    expect(
      find.text(
        'Copia en la nube, cierre de sesión, datos locales y controles de la cuenta',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('credits available'), findsNothing);
    expect(find.textContaining('Cloud backup'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final entry in ['Manage plan', 'View credits']) {
    testWidgets('$entry preserves Settings for Android Back', (tester) async {
      useTallSurface(tester);
      final container = createContainer(billingAccess: true);
      final router = GoRouter(
        initialLocation: '/settings',
        routes: [
          GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
          GoRoute(
            path: '/paywall',
            builder: (_, _) =>
                const Scaffold(body: Text('Subscription destination')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text(entry));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Subscription destination'), findsOneWidget);
      expect(router.canPop(), isTrue);
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Test subscription active'), findsOneWidget);
      expect(tester.takeException(), isNull);
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

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Make the app work for you'), findsOneWidget);
    expect(find.text('PLAN & CREDITS'), findsNothing);
    expect(find.text('SUBSCRIPTION'), findsNothing);
    expect(find.text('20 credits available'), findsNothing);
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

  testWidgets('toggle labels name the control and toggle it exactly once', (
    tester,
  ) async {
    useTallSurface(tester);
    final container = createContainer();
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('Appearance & permissions'));
      await tester.pump(const Duration(milliseconds: 300));
      final tile = find.ancestor(
        of: find.text('Sound effects'),
        matching: find.byType(MergeSemantics),
      );
      expect(tile, findsOneWidget);
      final control = find.descendant(of: tile, matching: find.byType(Switch));
      await Scrollable.ensureVisible(tester.element(control), alignment: 0.5);
      await tester.pump(const Duration(milliseconds: 300));
      final before = tester.widget<Switch>(control).value;
      expect(find.bySemanticsLabel('Sound effects'), findsOneWidget);
      await tester.tap(find.text('Sound effects'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.widget<Switch>(control).value, !before);
      await tester.tap(control);
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.widget<Switch>(control).value, before);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
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
        'External AI assistance is not enabled for this account. Your saved planning work remains available.',
      ),
      findsOneWidget,
    );
    expect(find.text('Allow external AI assistance'), findsNothing);
    expect(find.text('PERSONAL INFORMATION'), findsOneWidget);
    expect(find.text('Personal information unavailable'), findsOneWidget);
    expect(
      find.text(
        'A verified signed-in account is required. No personal information will be invented.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Spanish external-AI disclosure matches the account gate', (
    WidgetTester tester,
  ) async {
    useTallSurface(tester);
    final ProviderContainer container = createContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('es'),
          supportedLocales: ChronoSparkLocalizations.supportedLocales,
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            ChronoSparkLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: SettingsScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Planificación y orientación'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.scrollUntilVisible(
      find.text('Asistencia de IA externa'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(
      find.text(
        'La asistencia de IA externa no está habilitada para esta cuenta. Tu trabajo de planificación guardado permanece disponible.',
      ),
      findsOneWidget,
    );
    expect(find.text('Allow external AI assistance'), findsNothing);
  });

  testWidgets('Spanish expanded settings keep release controls localized', (
    WidgetTester tester,
  ) async {
    useTallSurface(tester);
    final ProviderContainer container = createContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('es'),
          supportedLocales: ChronoSparkLocalizations.supportedLocales,
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            ChronoSparkLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: SettingsScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('Apariencia y permisos'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('APARIENCIA Y PERMISOS'), findsOneWidget);
    expect(find.text('Formularios y diálogos oscuros'), findsOneWidget);
    expect(
      find.text(
        'El fondo sigue oscuro. Este ajuste cambia los formularios y diálogos.',
      ),
      findsOneWidget,
    );
    expect(find.text('Efectos de sonido'), findsOneWidget);
    expect(find.text('APPEARANCE & PERMISSIONS'), findsNothing);
    expect(find.text('Dark Mode'), findsNothing);

    await tester.tap(find.text('Apariencia y permisos'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Notificaciones'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.scrollUntilVisible(
      find.text('REFLEXIÓN DIARIA'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Recordatorio de reflexión'), findsOneWidget);
    expect(find.text('DAILY REFLECTION'), findsNothing);
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

    expect(find.text('PERSONAL INFORMATION'), findsOneWidget);
    expect(find.text('Add personal information'), findsOneWidget);
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
        'Information you save here for guidance stays only on this device. It is excluded from backup and sync, and will not be restored after reinstalling Axiomara or changing devices.',
      ),
      findsOneWidget,
    );

    await invokeNavTile(tester, 'Add personal information');

    expect(find.text('Add personal information'), findsNWidgets(2));
    expect(
      find.text(
        'Before you opt in: Information you save here for guidance is stored only on this device, excluded from backup and sync, and will not be restored after reinstalling Axiomara or changing devices.',
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

  testWidgets('Spanish Person Context consent and device scope are localized', (
    WidgetTester tester,
  ) async {
    useTallSurface(tester);
    final AccountStorageScope scope = AccountStorageScope.authenticated(
      'spanish-context-settings-account',
    );
    final ProviderContainer container = createContainer(
      accountScope: scope,
      personContext: PersonContextSpine(
        accountScopeId: scope.v2Namespace!,
        updatedAt: DateTime.utc(2026, 9, 4),
        signals: const <PersonContextSignal>[],
      ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('es'),
          supportedLocales: ChronoSparkLocalizations.supportedLocales,
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            ChronoSparkLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: SettingsScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.scrollUntilVisible(
      find.text('Planificación y orientación'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await invokeNavTile(tester, 'Planificación y orientación');

    expect(find.text('INFORMACIÓN PERSONAL'), findsOneWidget);
    expect(find.text('Añadir información personal'), findsOneWidget);
    expect(
      find.textContaining(
        'La información que guardas aquí para recibir orientación permanece solo en este dispositivo',
      ),
      findsOneWidget,
    );

    await invokeNavTile(tester, 'Añadir información personal');

    expect(find.textContaining('No se infiere nada'), findsOneWidget);
    expect(find.textContaining('Antes de aceptar'), findsOneWidget);
    expect(find.text('Guardar con consentimiento'), findsOneWidget);
    expect(find.text('Add personal information'), findsNothing);
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

      expect(find.text('Personal information unavailable'), findsOneWidget);
      expect(
        find.text('Clear corrupt personal information data'),
        findsOneWidget,
      );

      await invokeNavTile(tester, 'Clear corrupt personal information data');

      expect(
        find.text('Permanently clear corrupt personal information?'),
        findsOneWidget,
      );
      expect(
        find.text(
          'This permanently clears only recoverable or corrupt personal information payloads stored on this device. Tasks, goals, and Schedule items are unaffected. This cannot be undone.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(store.values[repository.storageKey!], '{corrupt-active');
      expect(store.values[repository.corruptionKey!], '{recoverable-copy');

      await invokeNavTile(tester, 'Clear corrupt personal information data');
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
      expect(
        find.text('Corrupt personal information data cleared.'),
        findsOneWidget,
      );

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

    expect(
      find.text('Personal information temporarily unavailable'),
      findsOneWidget,
    );
    expect(find.text('Retry personal information'), findsOneWidget);
    expect(find.text('Clear corrupt personal information data'), findsNothing);
    expect(find.textContaining('Permanently clear'), findsNothing);
  });

  for (final scenario in const [
    (
      name: 'one outcome',
      count: 1,
      ageDays: 0,
      helpfulCount: 1,
      option: null,
      english:
          'low confidence · Still learning: 1 reviewable outcome. No preference is applied yet.',
      spanish:
          'confianza baja · Aún está aprendiendo: 1 resultado revisable. Todavía no se aplica ninguna preferencia.',
    ),
    (
      name: 'two outcomes',
      count: 2,
      ageDays: 0,
      helpfulCount: 2,
      option: null,
      english:
          'low confidence · Still learning: 2 reviewable outcomes. No preference is applied yet.',
      spanish:
          'confianza baja · Aún está aprendiendo: 2 resultados revisables. Todavía no se aplica ninguna preferencia.',
    ),
    (
      name: 'aged outcomes below the evidence threshold',
      count: 3,
      ageDays: 60,
      helpfulCount: 3,
      option: 'minimum',
      english:
          'low confidence · Still learning: 3 reviewable outcomes. No preference is applied yet.',
      spanish:
          'confianza baja · Aún está aprendiendo: 3 resultados revisables. Todavía no se aplica ninguna preferencia.',
    ),
    (
      name: 'eligible outcomes without an option',
      count: 3,
      ageDays: 0,
      helpfulCount: 2,
      option: null,
      english:
          'developing confidence · 67% of recent weighted outcomes helped.',
      spanish:
          'confianza en desarrollo · 67% de los resultados recientes ponderados ayudaron.',
    ),
    (
      name: 'minimum option',
      count: 3,
      ageDays: 0,
      helpfulCount: 2,
      option: 'minimum',
      english:
          'developing confidence · 67% of recent weighted outcomes helped. The strongest repeated option is minimum.',
      spanish:
          'confianza en desarrollo · 67% de los resultados recientes ponderados ayudaron. La opción repetida con mayor respaldo es «mínima».',
    ),
    (
      name: 'best-fit option',
      count: 3,
      ageDays: 0,
      helpfulCount: 2,
      option: 'bestFit',
      english:
          'developing confidence · 67% of recent weighted outcomes helped. The strongest repeated option is bestFit.',
      spanish:
          'confianza en desarrollo · 67% de los resultados recientes ponderados ayudaron. La opción repetida con mayor respaldo es «más adecuada».',
    ),
    (
      name: 'established stretch option',
      count: 6,
      ageDays: 0,
      helpfulCount: 5,
      option: 'stretch',
      english:
          'established confidence · 83% of recent weighted outcomes helped. The strongest repeated option is stretch.',
      spanish:
          'confianza consolidada · 83% de los resultados recientes ponderados ayudaron. La opción repetida con mayor respaldo es «de mayor esfuerzo».',
    ),
    (
      name: 'unknown option preserved verbatim',
      count: 3,
      ageDays: 0,
      helpfulCount: 2,
      option: 'task execution',
      english:
          'developing confidence · 67% of recent weighted outcomes helped. The strongest repeated option is task execution.',
      spanish:
          'confianza en desarrollo · 67% de los resultados recientes ponderados ayudaron. La opción repetida con mayor respaldo es «task execution».',
    ),
  ]) {
    for (final locale in const [Locale('en'), Locale('es', 'US')]) {
      testWidgets(
        'learning pattern copy in ${locale.toLanguageTag()}: ${scenario.name}',
        (WidgetTester tester) async {
          useTallSurface(tester);
          final DateTime now = DateTime.utc(2026, 10, 3, 12);
          final outcomes = <DecisionOutcomeEntity>[
            for (int index = 0; index < scenario.count; index += 1)
              DecisionOutcomeEntity(
                decisionId: 'localized-decision-$index',
                kind: index < scenario.helpfulCount
                    ? DecisionOutcomeKind.accepted
                    : DecisionOutcomeKind.rejected,
                surface: 'smart_planner',
                situation: 'bounded planning choice',
                recordedAt: now.subtract(Duration(days: scenario.ageDays)),
                modelVersion: 'predictive-planning-v2',
                recommendationConfidence: .64,
                optionChosen: scenario.option,
                recommendationHelped: index < scenario.helpfulCount,
              ),
          ];
          final savedOutcomes = outcomes
              .map((outcome) => outcome.toJson())
              .toList();
          final ProviderContainer container = createContainer(
            decisionOutcomes: outcomes,
            learningPaused: false,
            learningNow: now,
          );
          final bool isSpanish = locale.languageCode == 'es';

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                locale: locale,
                supportedLocales: ChronoSparkLocalizations.supportedLocales,
                localizationsDelegates: const [
                  ChronoSparkLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                home: const SettingsScreen(),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 200));
          await invokeNavTile(
            tester,
            isSpanish ? 'Planificación y orientación' : 'Planning & guidance',
          );
          final String expected = isSpanish
              ? scenario.spanish
              : scenario.english;
          await tester.scrollUntilVisible(
            find.text(
              isSpanish
                  ? 'QUÉ CAMBIÓ CON TUS COMENTARIOS'
                  : 'WHAT CHANGED FROM YOUR FEEDBACK',
            ),
            500,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pump();

          expect(find.text(expected), findsOneWidget);
          if (isSpanish) {
            expect(find.textContaining('Still learning:'), findsNothing);
            expect(
              find.textContaining('weighted outcomes helped.'),
              findsNothing,
            );
            expect(
              find.textContaining('The strongest repeated option'),
              findsNothing,
            );
          }
          if (scenario.option == 'task execution') {
            expect(
              find.textContaining(
                isSpanish ? 'opción task execution' : 'option task execution',
              ),
              findsNWidgets(scenario.count),
            );
          }
          expect(
            container
                .read(decisionOutcomesProvider)
                .requireValue
                .map((outcome) => outcome.toJson())
                .toList(),
            savedOutcomes,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  for (final language in ['en', 'es']) {
    testWidgets(
      '$language stored habit observations display current labels without rewriting user text',
      (tester) async {
        useTallSurface(tester);
        final now = DateTime.utc(2026, 9, 2, 12);
        final outcomes = [
          DecisionOutcomeEntity(
            decisionId: 'legacy-habit-label',
            kind: DecisionOutcomeKind.completed,
            surface: 'daily_rhythm',
            situation: 'daily rhythm occurrence',
            recordedAt: now,
            modelVersion: 'habit-outcome-v1',
            recommendationConfidence: .64,
            completionResult:
                'My Daily Rhythm notes stay exactly as I wrote them.',
          ),
          DecisionOutcomeEntity(
            decisionId: 'legacy-habit-occurrence-label',
            kind: DecisionOutcomeKind.completed,
            surface: 'daily_rhythm_occurrence',
            situation: 'Daily Rhythm helped my routine',
            recordedAt: now.subtract(const Duration(minutes: 1)),
            modelVersion: 'habit-outcome-v1',
            recommendationConfidence: .64,
          ),
        ];
        final saved = outcomes.map((outcome) => outcome.toJson()).toList();
        final container = createContainer(
          decisionOutcomes: outcomes,
          learningPaused: false,
          learningNow: now,
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: appTheme,
              locale: Locale(language),
              supportedLocales: ChronoSparkLocalizations.supportedLocales,
              localizationsDelegates: const [
                ChronoSparkLocalizations.delegate,
                ...GlobalMaterialLocalizations.delegates,
              ],
              home: const SettingsScreen(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));
        await invokeNavTile(
          tester,
          language == 'es'
              ? 'Planificación y orientación'
              : 'Planning & guidance',
        );
        final first = find.byKey(
          ValueKey<String>('learning-ledger-${outcomes.first.id}'),
        );
        await tester.scrollUntilVisible(
          first,
          400,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          find.descendant(
            of: first,
            matching: find.textContaining(
              language == 'es' ? 'Hábito ·' : 'Habit ·',
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: first,
            matching: find.textContaining(
              language == 'es' ? 'registro de hábito' : 'habit occurrence',
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: first,
            matching: find.textContaining(
              'My Daily Rhythm notes stay exactly as I wrote them.',
            ),
          ),
          findsOneWidget,
        );
        final second = find.byKey(
          ValueKey<String>('learning-ledger-${outcomes.last.id}'),
        );
        await tester.scrollUntilVisible(
          second,
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          find.descendant(
            of: second,
            matching: find.textContaining(
              language == 'es' ? 'registro de hábito ·' : 'Habit occurrence ·',
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: second,
            matching: find.textContaining('Daily Rhythm helped my routine'),
          ),
          findsOneWidget,
        );
        expect(
          container
              .read(decisionOutcomesProvider)
              .requireValue
              .map((outcome) => outcome.toJson())
              .toList(),
          saved,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

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
      learningNow: now,
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
      matchesGoldenFile(platformGoldenFile('settings_learning_ledger.png')),
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
  ReflectionReminderPrefs reflectionPrefs = const ReflectionReminderPrefs(
    enabled: false,
    time: TimeOfDay(hour: 20, minute: 0),
  );
  int advancedLoads = 0;
  int reflectionTimeWrites = 0;
  final List<bool> taskReminderWrites = <bool>[];
  final List<bool> mainSwitchWrites = <bool>[];
  final List<bool> overdueWrites = <bool>[];
  final List<int> leadWrites = <int>[];
  final List<QuietHours> quietWrites = <QuietHours>[];

  /// What the main switch reports back: false when the device's reminders
  /// could not all be updated.
  bool mainSwitchApplies = true;

  /// Replaces the stored quiet hours when set.
  QuietHours? storedQuietHours;

  @override
  Future<void> setTaskRemindersEnabled(bool enabled) async {
    taskReminderWrites.add(enabled);
  }

  @override
  Future<bool> setRemindersEnabled(bool enabled) async {
    mainSwitchWrites.add(enabled);
    return mainSwitchApplies;
  }

  @override
  Future<void> setTaskOverdueNudgesEnabled(bool enabled) async {
    overdueWrites.add(enabled);
  }

  @override
  Future<void> setTaskReminderLeadMinutes(int minutes) async {
    leadWrites.add(minutes);
  }

  @override
  Future<void> setQuietHours(QuietHours quietHours) async {
    quietWrites.add(quietHours);
  }

  @override
  ReminderOrchestratorPrefs loadAdvancedReminderPrefs() {
    advancedLoads++;
    final ReminderOrchestratorPrefs stored = super.loadAdvancedReminderPrefs();
    final QuietHours? quiet = storedQuietHours;
    if (quiet == null) return stored;
    return ReminderOrchestratorPrefs(
      goalRemindersEnabled: stored.goalRemindersEnabled,
      habitRemindersEnabled: stored.habitRemindersEnabled,
      dailyPlanningEnabled: stored.dailyPlanningEnabled,
      dailyPlanningHour: stored.dailyPlanningHour,
      dailyPlanningMinute: stored.dailyPlanningMinute,
      taskRemindersEnabled: stored.taskRemindersEnabled,
      taskOverdueNudgesEnabled: stored.taskOverdueNudgesEnabled,
      taskReminderLeadMinutes: stored.taskReminderLeadMinutes,
      remindersEnabled: stored.remindersEnabled,
      quietHours: quiet,
    );
  }

  @override
  ReflectionReminderPrefs loadReflectionReminderPrefs() {
    return reflectionPrefs;
  }

  @override
  Future<bool> setReflectionReminderEnabled({
    required bool enabled,
    required TimeOfDay time,
  }) async {
    return enabled;
  }

  @override
  Future<bool> setReflectionReminderTime({required TimeOfDay time}) async {
    reflectionTimeWrites++;
    return true;
  }

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

class _CopyGuidance extends AdaptiveGuidanceNotifier {
  @override
  Future<AdaptiveGuidanceState> build() async => const AdaptiveGuidanceState(
    milestones: {},
    counts: {},
    skippedLessons: {},
    completedLessons: {},
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
