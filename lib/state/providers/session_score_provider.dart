import 'package:fantastic_guacamole/state/models/session_score_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final sessionScoreProvider = NotifierProvider<SessionScoreNotifier, SessionScoreView?>(
  SessionScoreNotifier.new,
);

class SessionScoreNotifier extends Notifier<SessionScoreView?> {
  @override
  SessionScoreView? build() => null;

  void set(SessionScoreView? value) => state = value;
}
