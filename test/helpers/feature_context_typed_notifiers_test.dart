import 'package:fantastic_guacamole/data/repositories/habit_repository.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/controllers/si_state_controller.dart';
import 'package:fantastic_guacamole/state/providers/habits_provider.dart';
import 'package:fantastic_guacamole/state/providers/execution_signals_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_provider.dart';
import 'package:fantastic_guacamole/state/providers/momentum_engine_provider.dart';
import 'package:fantastic_guacamole/state/models/trajectory_summary_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _account = NotifierProvider<_Account, String?>(_Account.new);

void main() {
  test('typed feature notifiers project A, signed-out, and B', () async {
    final container = ProviderContainer(overrides: [
      habitsProvider.overrideWith(_FixtureHabitsNotifier.new),
      profileProvider.overrideWith(_FixtureProfileController.new),
      siStateProvider.overrideWith(_FixtureSiStateController.new),
      executionSignalsProvider.overrideWith((ref) => _execution(ref.watch(_account))),
      trajectorySummaryProvider.overrideWith((ref) => _trajectory(ref.watch(_account))),
    ]);
    addTearDown(container.dispose);
    container.read(_account.notifier).set('A');
    expect((await container.read(habitsProvider.future)).single.title, 'A_HABIT');
    expect(container.read(profileProvider).name, 'A_PROFILE');
    final aMomentum = container.read(momentumEngineProvider);
    expect(aMomentum.score, 100);
    expect(aMomentum.energyPercent, 70);
    expect(aMomentum.trend, 'Rising');
    container.read(_account.notifier).set(null);
    expect(await container.read(habitsProvider.future), isEmpty);
    expect(container.read(profileProvider).name, 'signed_out');
    final signedOutMomentum = container.read(momentumEngineProvider);
    expect(signedOutMomentum.score, 0);
    expect(signedOutMomentum.energyPercent, 0);
    expect(signedOutMomentum.trend, 'Declining');
    container.read(_account.notifier).set('B');
    expect((await container.read(habitsProvider.future)).single.title, 'B_HABIT');
    expect(container.read(profileProvider).name, 'B_PROFILE');
    final bMomentum = container.read(momentumEngineProvider);
    expect(bMomentum.score, 0);
    expect(bMomentum.energyPercent, 30);
    expect(bMomentum.trend, 'Declining');
    expect(bMomentum.score, isNot(aMomentum.score));
  });
}
class _Account extends Notifier<String?> { @override String? build() => null; void set(String? value) => state = value; }
class _FixtureHabitsNotifier extends HabitsNotifier { @override Future<List<HabitRecord>> build() async { final a=ref.watch(_account); return a==null?const []:[HabitRecord(id:'shared-habit', title:'${a}_HABIT')]; } }
class _FixtureProfileController extends ProfileController { @override ProfileState build() { final a=ref.watch(_account); return ProfileState(name:a==null?'signed_out':'${a}_PROFILE', profileReady:a!=null); } }
class _FixtureSiStateController extends SIStateController { @override SIState build() { final a=ref.watch(_account); return SIState(energy:a == 'A' ? .7 : a == 'B' ? .3 : 0, fatigue:0, completedToday:0); } }
ExecutionSignals _execution(String? a) => ExecutionSignals(createdToday:0, completedToday:a == 'A' ? 4 : a == 'B' ? 0 : 0, skippedToday:a == 'B' ? 3 : 0, delayedToday:0, created7d:0, completed7d:a == 'A' ? 4 : 0, skipped7d:a == 'B' ? 3 : 0, delayed7d:0);
TrajectorySummaryView _trajectory(String? a) => TrajectorySummaryView(pendingTasks:0, completedTasks:0, completedToday:0, level:a == 'A' ? 5 : 1, streak:0, energy:a == 'A' ? .7 : .3, momentum:a == 'A' ? .9 : 0, adaptability:0, lastSessionXp:0, lastSessionQuality:0, pressureIndex:a == 'B' ? 80 : 0, behaviorDivergence:0, alert:'${a ?? 'signed_out'}_TRAJECTORY', predictionTitle:null, predictionOutcome:null, predictionProbability:null, predictionExplanation:null);
