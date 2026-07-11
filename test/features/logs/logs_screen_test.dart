import 'package:fantastic_guacamole/domain/entities/log_entry_entity.dart';
import 'package:fantastic_guacamole/features/logs/ui/logs_screen.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/providers/logs_provider.dart';
import 'package:fantastic_guacamole/state/state/logs_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('handles empty logs with helpful empty-state copy', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        profileProvider.overrideWith(_StaticProfileController.new),
        logsProvider.overrideWith(_EmptyLogsController.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: LogsScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('ACTIVITY LEDGER'), findsOneWidget);
    expect(
      find.text('Your completed actions and mission events will appear here.'),
      findsOneWidget,
    );
  });
}

class _StaticProfileController extends ProfileController {
  @override
  ProfileState build() => ProfileState(xp: 120, streak: 3, longestStreak: 7);
}

class _EmptyLogsController extends LogsController {
  @override
  LogsState build() =>
      const LogsState(entries: <LogEntryEntity>[], isLoading: false);
}
