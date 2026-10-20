import 'dart:async';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/features/settings/ui/cloud_backup_actions.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/sync_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final spanish in [false, true]) {
    testWidgets(
      'restore exposes cleanup and reminder warnings ${spanish ? 'es' : 'en'}',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            accountStorageScopeProvider.overrideWithValue(
              AccountStorageScope.authenticated('warning-owner'),
            ),
            restoreFromCloudProvider.overrideWith((ref) async {
              await Future<void>.value();
              ref.read(cloudRestoreWarningsProvider.notifier)
                ..add(CloudRestoreWarning.legacyCleanupPending)
                ..add(CloudRestoreWarning.remindersPending);
              return true;
            }),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              locale: Locale(spanish ? 'es' : 'en'),
              supportedLocales: ChronoSparkLocalizations.supportedLocales,
              localizationsDelegates: const [
                ChronoSparkLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: const Scaffold(body: CloudBackupActions(enabled: true)),
            ),
          ),
        );
        await tester.tap(
          find.text(
            spanish ? 'Restaurar copia en la nube' : 'Restore cloud backup',
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(spanish ? 'Restaurar copia' : 'Restore backup'),
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining(spanish ? 'limpieza segura' : 'secure cleanup'),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            spanish ? 'permiso de notificaciones' : 'notification permission',
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            spanish ? 'Copia en la nube restaurada.' : 'Cloud backup restored.',
          ),
          findsNothing,
        );
      },
    );
  }
  for (final spanish in [false, true]) {
    testWidgets(
      'cloud controls require opt-in, confirmation and completion ${spanish ? 'es' : 'en'}',
      (tester) async {
        var uploads = 0;
        var restores = 0;
        final upload = Completer<bool>();
        final container = ProviderContainer(
          overrides: [
            accountStorageScopeProvider.overrideWithValue(
              AccountStorageScope.authenticated('cloud-action-owner'),
            ),
            syncToCloudProvider.overrideWith((ref) async {
              uploads++;
              return upload.future;
            }),
            restoreFromCloudProvider.overrideWith((ref) async {
              restores++;
              return true;
            }),
          ],
        );
        addTearDown(container.dispose);
        await tester.binding.setSurfaceSize(const Size(360, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        Future<void> mount(bool enabled) async {
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                locale: Locale(spanish ? 'es' : 'en'),
                supportedLocales: ChronoSparkLocalizations.supportedLocales,
                localizationsDelegates: const [
                  ChronoSparkLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                home: Scaffold(
                  body: MediaQuery(
                    data: const MediaQueryData(
                      textScaler: TextScaler.linear(1.5),
                    ),
                    child: CloudBackupActions(enabled: enabled),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
        }

        final backup = find.text(
          spanish ? 'Guardar copia ahora' : 'Back up now',
        );
        final restore = find.text(
          spanish ? 'Restaurar copia en la nube' : 'Restore cloud backup',
        );
        await mount(false);
        await tester.tap(backup);
        await tester.tap(restore);
        expect(uploads, 0);
        expect(restores, 0);
        await mount(true);
        await tester.tap(backup);
        await tester.pump();
        expect(uploads, 1);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        await tester.tap(backup);
        expect(uploads, 1);
        upload.complete(true);
        await tester.pumpAndSettle();
        expect(
          find.text(
            spanish
                ? 'Copia cifrada guardada en la nube.'
                : 'Encrypted cloud backup saved.',
          ),
          findsOneWidget,
        );
        await tester.tap(restore);
        await tester.pumpAndSettle();
        expect(restores, 0);
        expect(
          find.textContaining(
            spanish ? 'reemplaza las tareas' : 'replaces tasks',
          ),
          findsOneWidget,
        );
        await tester.tap(find.text(spanish ? 'Cancelar' : 'Cancel'));
        await tester.pumpAndSettle();
        expect(restores, 0);
        await tester.tap(restore);
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(spanish ? 'Restaurar copia' : 'Restore backup'),
        );
        await tester.pumpAndSettle();
        expect(restores, 1);
        expect(
          find.text(
            spanish ? 'Copia en la nube restaurada.' : 'Cloud backup restored.',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('account switch cancels a pending restore confirmation', (
    tester,
  ) async {
    var scope = AccountStorageScope.authenticated('owner-a');
    var restores = 0;
    final container = ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWith((ref) => scope),
        restoreFromCloudProvider.overrideWith((ref) async {
          restores++;
          return true;
        }),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: CloudBackupActions(enabled: true)),
        ),
      ),
    );
    await tester.tap(find.text('Restore cloud backup'));
    await tester.pumpAndSettle();
    scope = AccountStorageScope.authenticated('owner-b');
    container.invalidate(accountStorageScopeProvider);
    await tester.tap(find.text('Restore backup'));
    await tester.pumpAndSettle();
    expect(restores, 0);
    expect(find.text('Cloud backup restored.'), findsNothing);
  });
}
