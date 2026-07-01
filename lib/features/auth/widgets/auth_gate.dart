import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../ui/layout/holo_background.dart';
import '../../../features/system_shell/main_shell.dart';
import '../auth_session_controller.dart';
import '../screens/login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthSessionController>(
      builder: (BuildContext context, AuthSessionController auth, Widget? child) {
        if (auth.isLoading) {
          return const Scaffold(
            body: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: HoloBackground(
                    backgroundAsset: 'assets/backgrounds/login_bg.png',
                    child: SizedBox.shrink(),
                  ),
                ),
                Center(child: CircularProgressIndicator()),
              ],
            ),
          );
        }

        if (!auth.isSignedIn) {
          return const LoginScreen();
        }

        return const MainShell();
      },
    );
  }
}
