import 'package:flutter/material.dart';

import '../../system_shell/pages/settings_page.dart';

class SettingsHome extends StatelessWidget {
  const SettingsHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: const SettingsPage(),
    );
  }
}
