import 'package:fantastic_guacamole/features/settings/state/settings_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsController extends Notifier<SettingsState> {
  @override
  SettingsState build() => SettingsState.initial();
}
