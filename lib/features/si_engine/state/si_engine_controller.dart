import 'package:fantastic_guacamole/features/si_engine/state/si_engine_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SiEngineController extends Notifier<SiEngineState> {
  @override
  SiEngineState build() => SiEngineState.initial();
}
