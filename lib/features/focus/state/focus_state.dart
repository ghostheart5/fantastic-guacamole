import 'package:fantastic_guacamole/features/focus/models/focus_session.dart';

class FocusViewState {
  const FocusViewState({
    required this.session,
    required this.remainingSeconds,
    required this.isRunning,
    required this.isCompleted,
  });

  final FocusSession? session;
  final int remainingSeconds;
  final bool isRunning;
  final bool isCompleted;

  factory FocusViewState.initial() {
    return const FocusViewState(
      session: null,
      remainingSeconds: 0,
      isRunning: false,
      isCompleted: false,
    );
  }

  FocusViewState copyWith({
    FocusSession? session,
    int? remainingSeconds,
    bool? isRunning,
    bool? isCompleted,
  }) {
    return FocusViewState(
      session: session ?? this.session,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isRunning: isRunning ?? this.isRunning,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
