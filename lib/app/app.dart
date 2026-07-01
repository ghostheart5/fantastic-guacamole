import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/di/app_locator.dart';
import '../core/state/app_state.dart';
import '../features/auth/auth_session_controller.dart';
import '../features/settings/controllers/settings_controller.dart';
import '../features/auth/widgets/auth_gate.dart';
import '../theme/app_theme.dart';
import 'routes.dart';

class ChronoSparkApp extends StatelessWidget {
  const ChronoSparkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: <ChangeNotifierProvider>[
        ChangeNotifierProvider<AppState>(create: (_) => AppState()),
        ChangeNotifierProvider<AuthSessionController>(
          create: (_) => AuthSessionController()..bootstrap(),
        ),
        ChangeNotifierProvider<SettingsController>(
          create: (_) => AppLocator.instance.settingsController(),
        ),
      ],
      child: Consumer<SettingsController>(
        builder: (BuildContext context, SettingsController settingsController, Widget? child) {
          final SettingsState settings = settingsController.read();
          return MaterialApp(
            title: 'ChronoSpark Futuristic Planner',
            debugShowCheckedModeBanner: false,
            theme: settings.neonRecall ? AppTheme.neonRecall() : AppTheme.dark(),
            builder: (BuildContext context, Widget? appChild) {
              final MediaQueryData mediaQuery = MediaQuery.of(context);
              return MediaQuery(
                data: mediaQuery.copyWith(
                  textScaler: TextScaler.linear(settings.textScale),
                ),
                child: appChild ?? const SizedBox.shrink(),
              );
            },
            home: const AuthGate(),
            onGenerateRoute: AppRoutes.generate,
          );
        },
      ),
    );
  }
}
