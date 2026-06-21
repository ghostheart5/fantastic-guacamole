import 'package:flutter/material.dart';
import 'routes.dart';
import '../theme/app_theme.dart';

class ChronoSparkApp extends StatelessWidget {
  const ChronoSparkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChronoSpark Futuristic Planner',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      initialRoute: '/',
      onGenerateRoute: AppRoutes.generate,
    );
  }
}
