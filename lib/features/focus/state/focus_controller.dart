import 'package:flutter_riverpod/flutter_riverpod.dart';

class FocusState {
  final bool active;
  final int seconds;
  final bool completed;

  FocusState({this.active = false, this.seconds = 0, this.completed = false});

  FocusState copyWith({bool? active, int? seconds, bool? completed}) {
    return FocusState(
      active: active ?? this.active,
      seconds: seconds ?? this.seconds,
      completed: completed ?? this.completed,
    );
  }
}

final focusControllerProvider = NotifierProvider<FocusController, FocusState>(
  FocusController.new,
);

final focusProvider = Provider<bool>(
  (ref) => ref.watch(focusControllerProvider).active,
);

class FocusController extends Notifier<FocusState> {
  @override
  FocusState build() => FocusState();

  int _sessionToken = 0;

  void start() {
    _sessionToken++;
    state = FocusState(active: true, seconds: 0);
    _runTimer(_sessionToken);
  }

  Future<void> _runTimer(int token) async {
    while (true) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!ref.mounted || token != _sessionToken) {
        return;
      }
      final FocusState current = state;
      if (!current.active) {
        return;
      }
      state = current.copyWith(seconds: current.seconds + 1);
    }
  }

  void complete() {
    _sessionToken++;
    state = state.copyWith(active: false, completed: true);
  }

  void reset() {
    _sessionToken++;
    state = FocusState();
  }
}
