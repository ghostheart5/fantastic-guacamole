import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/ui/widgets/widgets.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScreen(
      child: Center(
        child: AppColumn(
          gap: 3,
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AppText(
              'Welcome to ChronoSpark',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const AppText(
              'Your AI-powered focus system.',
              textAlign: TextAlign.center,
            ),
            AppButton(
              label: 'Get Started',
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool(onboardingCompleteStorageKey, true);
                ref.read(onboardingCompleteProvider.notifier).set(true);
              },
            ),
          ],
        ),
      ),
    );
  }
}
