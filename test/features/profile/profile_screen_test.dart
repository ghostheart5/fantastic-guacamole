import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/features/profile/ui/profile_screen.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Profile is a 600+ line screen that had no widget coverage. It derives its
/// whole view state from ProfileController, so these smoke tests pin that the
/// derivation renders for both a fresh account and an established one.
void main() {
  Future<ProviderContainer> pumpProfile(
    WidgetTester tester,
    ProfileState state,
  ) async {
    tester.platformDispatcher.views.first
      ..physicalSize = const Size(1200, 4000)
      ..devicePixelRatio = 1.0;
    addTearDown(() {
      tester.platformDispatcher.views.first
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });

    final ProviderContainer container = ProviderContainer(
      overrides: [
        profileProvider.overrideWith(() => _StaticProfile(state)),
        // GoalsNotifier.build schedules a timer that outlives the test frame.
        goalsProvider.overrideWith(_StaticGoals.new),
        // ProfileController.updateName() persists via the real SecureStore by
        // default, which under an unmocked flutter_secure_storage platform
        // channel hangs forever rather than throwing (same landmine as
        // unmocked share_plus/Clipboard channels).
        secureStoreProvider.overrideWithValue(
          SecureStore(backend: InMemorySecureStoreBackend()),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pump();
    return container;
  }

  testWidgets('renders for a brand-new account', (WidgetTester tester) async {
    await pumpProfile(tester, ProfileState());

    expect(tester.takeException(), isNull);
    expect(find.byType(ProfileScreen), findsOneWidget);
  });

  testWidgets('renders for an established account', (
    WidgetTester tester,
  ) async {
    await pumpProfile(
      tester,
      ProfileState(
        xp: 640,
        level: 8,
        streak: 15,
        longestStreak: 22,
        name: 'Keegan',
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(ProfileScreen), findsOneWidget);
  });

  testWidgets('renders when the account has no display name set', (
    WidgetTester tester,
  ) async {
    // Onboarding lets the user skip the name field, so an empty name reaches
    // this screen in normal use.
    await pumpProfile(tester, ProfileState(xp: 30, level: 1, name: ''));

    expect(tester.takeException(), isNull);
    expect(find.byType(ProfileScreen), findsOneWidget);
  });

  group('_NameEditor save flow', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    testWidgets('an empty/whitespace-only name is not saved', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await pumpProfile(
        tester,
        ProfileState(name: 'Keegan'),
      );

      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.text('Update Identity'));
      await tester.pump();

      expect(container.read(profileProvider).name, 'Keegan');
    });

    testWidgets('a trimmed non-empty name is saved', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await pumpProfile(
        tester,
        ProfileState(name: 'Keegan'),
      );

      await tester.enterText(find.byType(TextField), '  Nova  ');
      await tester.tap(find.text('Update Identity'));
      await tester.pump();
      await tester.pump();

      expect(container.read(profileProvider).name, 'Nova');
    });
  });

  testWidgets(
    'INVITE FRIENDS falls back to clipboard + SnackBar when the share sheet is unavailable',
    (WidgetTester tester) async {
      // Same landmine as Progression's share button: an unmocked share_plus
      // or clipboard platform channel hangs forever rather than throwing, so
      // both must be mocked explicitly to exercise the real fallback path.
      String? clipboardText;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (
            MethodCall call,
          ) async {
            switch (call.method) {
              case 'Clipboard.setData':
                clipboardText =
                    (call.arguments as Map<dynamic, dynamic>)['text']
                        as String?;
                return null;
              case 'Clipboard.getData':
                return <String, dynamic>{'text': clipboardText};
              default:
                return null;
            }
          });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/share'),
            (MethodCall call) async {
              throw PlatformException(
                code: 'unavailable',
                message: 'no share implementation in tests',
              );
            },
          );
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('dev.fluttercommunity.plus/share'),
              null,
            );
      });

      await pumpProfile(tester, ProfileState(streak: 5, level: 3));

      await tester.tap(find.text('INVITE FRIENDS'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('Share sheet unavailable. Invite copied to clipboard.'),
        findsOneWidget,
      );
      expect(clipboardText, contains('ChronoSpark'));
    },
  );
}

class _StaticProfile extends ProfileController {
  _StaticProfile(this._state);

  final ProfileState _state;

  @override
  ProfileState build() => _state;

  @override
  Future<void> updateName(String name) async {
    final String trimmed = name.trim();
    if (trimmed.isNotEmpty) {
      state = state.copyWith(name: trimmed);
    }
  }
}

class _StaticGoals extends GoalsNotifier {
  @override
  List<GoalEntity> build() => const <GoalEntity>[];
}
