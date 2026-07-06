import 'package:fantastic_guacamole/state/state/momentum_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MomentumController extends Notifier<MomentumState> {
  @override
  MomentumState build() => const MomentumState();

  void onSessionCompleted() {
    state = state.copyWith(active: true, chainCount: state.chainCount + 1);
  }

  void reset() {
    state = const MomentumState();
  }
}

final momentumProvider = NotifierProvider<MomentumController, MomentumState>(
  MomentumController.new,
);
