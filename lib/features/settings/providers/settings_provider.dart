import 'package:fantastic_guacamole/features/settings/actions/settings_actions.dart';
import 'package:fantastic_guacamole/features/settings/controllers/settings_controller.dart';
import 'package:fantastic_guacamole/features/settings/models/settings_model.dart';
import 'package:fantastic_guacamole/state/auth/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final settingsProvider = NotifierProvider<SettingsController, SettingsModel>(
  SettingsController.new,
);

final settingsActionsProvider = Provider<SettingsActions>(
  (ref) => SettingsActions(ref.read(authServiceProvider)),
);
