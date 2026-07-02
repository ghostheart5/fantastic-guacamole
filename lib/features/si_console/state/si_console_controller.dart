import 'package:fantastic_guacamole/features/si_console/state/si_console_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SiConsoleController extends Notifier<SiConsoleState> {
  @override
  SiConsoleState build() => SiConsoleState.initial();
}
