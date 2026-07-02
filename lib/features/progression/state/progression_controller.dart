import 'package:fantastic_guacamole/features/progression/state/progression_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProgressionController extends Notifier<ProgressionState> {
  @override
  ProgressionState build() => ProgressionState.initial();
}
