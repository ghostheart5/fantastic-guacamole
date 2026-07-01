import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/state/app_state.dart';
import 'features/system_shell/main_shell.dart';
import 'theme/dark_theme.dart';

class ChronoSparkSystemApp extends StatelessWidget {
  const ChronoSparkSystemApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppState>(
      create: (_) => AppState(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'ChronoSpark',
        theme: buildDarkTheme(),
        home: const MainShell(),
      ),
    );
  }
}
