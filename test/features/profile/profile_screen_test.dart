import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/features/profile/ui/profile_screen.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
        // Profile reaches goals through coreValuesAlignmentProvider, and
        // GoalsNotifier.build schedules a timer that outlives the test frame.
        goalsProvider.overrideWith(_StaticGoals.new),
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
}

class _StaticProfile extends ProfileController {
  _StaticProfile(this._state);

  final ProfileState _state;

  @override
  ProfileState build() => _state;
}

class _StaticGoals extends GoalsNotifier {
  @override
  List<GoalEntity> build() => const <GoalEntity>[];
}
