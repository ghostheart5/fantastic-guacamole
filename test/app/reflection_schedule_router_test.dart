import 'package:fantastic_guacamole/state/providers/settings_ui_provider.dart';
import 'dart:async';
import 'dart:convert';

import 'package:fantastic_guacamole/app/navigation_shell.dart';
import 'package:fantastic_guacamole/app/router/app_router.dart';
import 'package:fantastic_guacamole/app/router/route_guards.dart' as guards;
import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/core/data/account_data_registry.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/services/contracts/password_recovery_auth.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/features/timeline/ui/timeline_screen.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/providers/account_onboarding_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_provider.dart'
    show passwordRecoveryStateProvider;
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _account = 'reflection-router-account';
final _authenticated = NotifierProvider<_Flag, bool>(_Flag.new);
final _welcome = NotifierProvider<_Flag, bool>(_Flag.new);

class _Flag extends Notifier<bool> {
  @override
  bool build() => true;
  void deny() => state = false;
}

class _Onboarding extends AccountOnboardingCompleteNotifier {
  @override
  bool build() => true;
  void deny() => state = const AsyncData(false);
  void loading() => state = const AsyncLoading();
}

class _Recovery extends Notifier<AsyncValue<PasswordRecoveryState>> {
  @override
  AsyncValue<PasswordRecoveryState> build() =>
      const AsyncData(PasswordRecoveryState.inactive());
  void pending() =>
      state = const AsyncData(PasswordRecoveryState.pending(_account, 1));
}

final _recovery =
    NotifierProvider<_Recovery, AsyncValue<PasswordRecoveryState>>(
      _Recovery.new,
    );

class _Goals extends GoalsNotifier {
  @override
  List<GoalEntity> build() => const [];
}

class _Events extends TimelineNotifier {
  @override
  List<TimelineEventEntity> build() => const [];
}

Future<void> _frames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AndroidFlutterLocalNotificationsPlugin.registerWith();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  Completer<String?>? coldResponse;
  int launchQueries = 0;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    NotificationScheduler.tappedPayloadListenable.value = null;
    coldResponse = null;
    launchQueries = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'initialize' ||
              call.method == 'areNotificationsEnabled') {
            return true;
          }
          if (call.method == 'pendingNotificationRequests') return <Object>[];
          if (call.method == 'getNotificationAppLaunchDetails') {
            launchQueries++;
            final response = coldResponse;
            final payload = await response?.future;
            return <String, Object?>{
              'notificationLaunchedApp': payload != null,
              if (payload != null)
                'notificationResponse': <String, Object?>{
                  'notificationResponseType': 0,
                  'payload': payload,
                },
            };
          }
          return null;
        });
    NotificationScheduler().resetLaunchConsumptionForTesting();
    await NotificationScheduler().init(requestPermissions: false);
  });
  tearDown(() {
    NotificationScheduler.tappedPayloadListenable.value = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  for (final cold in [false, true]) {
    for (final condition in [
      'allowed',
      'setup',
      'setup loading',
      'welcome',
      'signed out',
      'recovery',
      'boundary loading',
      'blocked boundary',
    ]) {
      testWidgets(
        '${cold ? 'cold' : 'foreground'} reflection with $condition uses real router admission',
        (tester) async {
          tester.view.physicalSize = const Size(1200, 2400);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final container = ProviderContainer(
            overrides: [
              accountStorageScopeProvider.overrideWithValue(
                AccountStorageScope.authenticated(_account),
              ),
              accountLegacyOwnershipProvider.overrideWithValue(
                LegacyScopeOwnership.provenNotOwned,
              ),
              guards.authenticatedGuardProvider.overrideWith(
                (ref) => ref.watch(_authenticated),
              ),
              guards.onboardingWelcomeCompleteGuardProvider.overrideWith(
                (ref) => ref.watch(_welcome),
              ),
              guards.onboardingCompleteGuardProvider.overrideWith(
                (ref) =>
                    ref
                        .watch(accountOnboardingCompleteProvider)
                        .asData
                        ?.value ??
                    false,
              ),
              accountOnboardingCompleteProvider.overrideWith(_Onboarding.new),
              passwordRecoveryStateProvider.overrideWith(
                (ref) => ref
                    .watch(_recovery)
                    .when(
                      data: Stream.value,
                      error: (e, s) => Stream.error(e, s),
                      loading: () => const Stream.empty(),
                    ),
              ),
              settingsUiActionsProvider.overrideWith(
                _RoutingSettingsActions.new,
              ),
              goalsProvider.overrideWith(_Goals.new),
              timelineProvider.overrideWith(_Events.new),
              timelinePersistenceCorruptedProvider.overrideWithValue(false),
              allTasksProvider.overrideWith((ref) async => const <Task>[]),
              unreadNotificationsProvider.overrideWithValue(0),
            ],
          );
          addTearDown(container.dispose);
          final boundary = container.read(authSessionBoundaryProvider.notifier);
          final generation = boundary.begin(
            userId: _account,
            isTransitioning: true,
          );
          boundary.complete(generation);
          final router = container.read(appRouterProvider)
            ..go(RoutePaths.nexus);
          final response = Completer<String?>();
          if (cold) coldResponse = response;
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: Consumer(
                builder: (context, ref, _) => MaterialApp.router(
                  routerConfig: ref.watch(appRouterProvider),
                ),
              ),
            ),
          );
          await _frames(tester);
          expect(find.byType(NavigationShell), findsOneWidget);
          expect(
            router.routeInformationProvider.value.uri.path,
            RoutePaths.nexus,
          );
          final payload = jsonEncode({
            'v': 1,
            'accountScope': AccountDataRegistry.accountDigest(_account),
            'notificationId': 'reflection_reminder',
          });
          switch (condition) {
            case 'setup':
              (container.read(accountOnboardingCompleteProvider.notifier)
                      as _Onboarding)
                  .deny();
            case 'setup loading':
              (container.read(accountOnboardingCompleteProvider.notifier)
                      as _Onboarding)
                  .loading();
            case 'welcome':
              container.read(_welcome.notifier).deny();
            case 'signed out':
              container.read(_authenticated.notifier).deny();
            case 'recovery':
              container.read(_recovery.notifier).pending();
              // Deliver the provider event while the real router still owns the shell.
              await tester.pump();
            case 'boundary loading':
              boundary.begin(userId: _account, isTransitioning: true);
            case 'blocked boundary':
              boundary.block(generation, issue: 'Test storage block');
          }
          if (condition == 'allowed') {
            expect(container.read(guards.authenticatedGuardProvider), isTrue);
            expect(
              container.read(guards.onboardingWelcomeCompleteGuardProvider),
              isTrue,
            );
            expect(
              container.read(guards.onboardingCompleteGuardProvider),
              isTrue,
            );
            expect(
              container
                  .read(passwordRecoveryStateProvider)
                  .asData
                  ?.value
                  .isPending,
              isFalse,
            );
            expect(
              container.read(authSessionBoundaryProvider).isStorageReady,
              isTrue,
            );
          }
          if (condition == 'recovery') {
            expect(
              container
                  .read(passwordRecoveryStateProvider)
                  .asData
                  ?.value
                  .isPending,
              isTrue,
            );
          }
          if (cold) {
            response.complete(payload);
          } else {
            NotificationScheduler.tappedPayloadListenable.value = payload;
          }
          await _frames(tester);
          if (condition == 'allowed') {
            expect(find.byType(TimelineScreen), findsOneWidget);
            expect(find.text('Schedule'), findsOneWidget);
            final route = ModalRoute.of(
              tester.element(find.byType(TimelineScreen)),
            )!;
            expect(route.animation!.status, AnimationStatus.completed);
            bool popped = false;
            bool transitionCompleted = false;
            unawaited(
              route.popped.then((_) {
                popped = true;
              }),
            );
            unawaited(
              route.completed.then((_) {
                transitionCompleted = true;
              }),
            );
            await tester.tap(find.byTooltip('Back').hitTestable());
            await _frames(tester);
            expect(popped, isTrue);
            expect(transitionCompleted, isTrue);
            expect(find.byType(TimelineScreen), findsNothing);
            expect(
              router.routeInformationProvider.value.uri.path,
              RoutePaths.nexus,
            );
            if (cold) {
              expect(launchQueries, 1);
              // Recreate the shell without changing Android's retained launch
              // intent or the process singleton. No cold response is cleared.
              await tester.pumpWidget(const SizedBox.shrink());
              await _frames(tester);
              await tester.pumpWidget(
                UncontrolledProviderScope(
                  container: container,
                  child: Consumer(
                    builder: (context, ref, _) => MaterialApp.router(
                      routerConfig: ref.watch(appRouterProvider),
                    ),
                  ),
                ),
              );
              await _frames(tester);
              expect(find.byType(NavigationShell), findsOneWidget);
              expect(
                find.byType(TimelineScreen, skipOffstage: false),
                findsNothing,
              );
              expect(
                router.routeInformationProvider.value.uri.path,
                RoutePaths.nexus,
              );
              expect(launchQueries, 1);
              // Use the real plugin callback for a genuine foreground tap with
              // the same daily payload; cold-claim state must not suppress it.
              await _deliverForeground(channel, payload);
              await _frames(tester);
              expect(find.byType(TimelineScreen), findsOneWidget);
              expect(find.text('Schedule'), findsOneWidget);
              expect(launchQueries, 1);
              await tester.tap(find.byTooltip('Back').hitTestable());
              await _frames(tester);
              expect(find.byType(TimelineScreen), findsNothing);
            }
          } else {
            expect(
              find.byType(TimelineScreen, skipOffstage: false),
              findsNothing,
            );
            final expectedPath = switch (condition) {
              'setup' || 'setup loading' || 'welcome' => RoutePaths.onboarding,
              'signed out' || 'recovery' => RoutePaths.login,
              _ => RoutePaths.nexus,
            };
            expect(
              router.routeInformationProvider.value.uri.path,
              expectedPath,
            );
            if (condition == 'setup loading') {
              expect(
                container.read(accountOnboardingCompleteProvider).isLoading,
                isTrue,
              );
            }
          }
          expect(NotificationScheduler.tappedPayloadListenable.value, isNull);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}

// Reminder recovery has its own integration suite. Navigation retains the real
// shell dispatch while isolating unrelated reminder repositories/platform I/O.
class _RoutingSettingsActions extends SettingsUiActions {
  _RoutingSettingsActions(super.ref);
  @override
  Future<void> refreshNotificationPermissionAndReminders() async {}
}

Future<void> _deliverForeground(MethodChannel channel, String payload) async {
  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  await messenger.handlePlatformMessage(
    channel.name,
    const StandardMethodCodec().encodeMethodCall(
      MethodCall('didReceiveNotificationResponse', <String, Object>{
        'notificationResponseType': 0,
        'payload': payload,
      }),
    ),
    null,
  );
}
