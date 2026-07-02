import 'package:fantastic_guacamole/app/app_root.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:fantastic_guacamole/app/app_root.dart';
export 'package:fantastic_guacamole/app/navigation_shell.dart';
export 'package:fantastic_guacamole/core/constants/constants.dart';
export 'package:fantastic_guacamole/core/errors/errors.dart';
export 'package:fantastic_guacamole/core/extensions/extensions.dart';
export 'package:fantastic_guacamole/state/app_state.dart';
export 'package:fantastic_guacamole/state/core/app_providers.dart';

// Layer flow:
// UI (features) -> Riverpod (state/controllers) -> Usecases (domain)
// -> Engine (AI / scoring) -> Repository (data) -> Models

class ChronosparkApp extends StatelessWidget {
  const ChronosparkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(child: AppRoot());
  }
}
