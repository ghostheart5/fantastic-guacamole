import 'package:flutter/material.dart';

import 'package:fantastic_guacamole/core/constants/app_assets.dart';
import 'package:fantastic_guacamole/ui/widgets/app_background.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0F172A),
      body: AppBackground(image: AppAssets.bgHome, child: Center()),
    );
  }
}
