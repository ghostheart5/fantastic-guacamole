import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/core/constants/app_colors.dart';
import 'package:fantastic_guacamole/core/constants/app_urls.dart';
import 'package:fantastic_guacamole/features/notifications/notification_scheduler.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final soundEnabled = ref.watch(soundEnabledProvider);
    final access = ref.watch(appAccessProvider);
    final hasMockSession = ref.watch(mockAuthSessionProvider);
    final intelligence = ref.watch(intelligenceStateProvider);

    return AnimatedSystemBackground(
      backgroundAssetPath: 'assets/backgrounds/settings_bg.png',
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Header row with back button
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (Navigator.canPop(context)) {
                        context.pop();
                        return;
                      }
                      ref.read(appFlowProvider.notifier).toCoach();
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.neonCyan.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        color: AppColors.neonCyan,
                        size: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [AppColors.neonCyan, AppColors.neonViolet],
                          ).createShader(bounds),
                          child: const Text(
                            'SETTINGS',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 3,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const Text(
                          'SYSTEM CONFIG',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10, letterSpacing: 2, color: Colors.white38),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              _Section(
                label: 'PREFERENCES',
                accentColor: AppColors.neonCyan,
                child: Column(
                  children: [
                    _NeonToggleTile(
                      title: 'Sound Effects',
                      value: soundEnabled,
                      onChanged: (v) => ref.read(soundEnabledProvider.notifier).set(v),
                    ),
                    ValueListenableBuilder<bool?>(
                      valueListenable: NotificationScheduler.permissionGrantedListenable,
                      builder: (context, granted, _) {
                        final String subtitle = switch (granted) {
                          true => 'Granted',
                          false => 'Denied (scheduling disabled)',
                          null => 'Unknown until app initializes notifications',
                        };
                        return _NeonStatusTile(
                          title: 'Notification Permission',
                          subtitle: subtitle,
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              _Section(
                label: 'ACCOUNT',
                accentColor: AppColors.neonViolet,
                child: Column(
                  children: [
                    _NeonNavTile(
                      title: access.hasTesterFullAccess ? 'Tester Access' : 'Subscription',
                      subtitle: access.subscriptionStatusDetail,
                      onTap: () => context.go(RoutePaths.paywall),
                    ),
                    if (hasMockSession)
                      _NeonNavTile(
                        title: 'Sign out Mock Session',
                        subtitle:
                            'Return to login and disable the current tester mock auth session.',
                        onTap: () {
                          ref.read(mockAuthSessionProvider.notifier).set(false);
                          context.go(RoutePaths.login);
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              _Section(
                label: 'RUNTIME MODE',
                accentColor: AppColors.neonCyan,
                child: Column(
                  children: [
                    _NeonStatusTile(title: 'Flavor', subtitle: intelligence.environment.appFlavor),
                    _NeonStatusTile(
                      title: 'Mock Mode',
                      subtitle: intelligence.flags.mockMode
                          ? 'Enabled (offline local mode)'
                          : 'Disabled',
                    ),
                    _NeonStatusTile(
                      title: 'Paywall Disabled',
                      subtitle: intelligence.flags.paywallDisabled
                          ? 'Enabled (dev-only bypass)'
                          : 'Disabled',
                    ),
                    _NeonStatusTile(
                      title: 'Mock Login',
                      subtitle: intelligence.flags.mockLoginEnabled ? 'Enabled' : 'Disabled',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              _Section(
                label: 'LEGAL',
                accentColor: AppColors.memoryAmber,
                child: Column(
                  children: [
                    _NeonNavTile(
                      title: 'Privacy Policy',
                      subtitle: AppUrls.privacy,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              const _InfoScreen(title: 'Privacy Policy', body: _kPrivacyPolicy),
                        ),
                      ),
                    ),
                    _NeonNavTile(
                      title: 'Terms of Service',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              const _InfoScreen(title: 'Terms of Service', body: _kTermsOfService),
                        ),
                      ),
                    ),
                    _NeonNavTile(
                      title: 'Support',
                      subtitle: AppUrls.support,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const _InfoScreen(title: 'Support', body: _kSupportInfo),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.child, required this.accentColor});
  final String label;
  final Widget child;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF050D1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(color: accentColor.withValues(alpha: 0.06), blurRadius: 16, spreadRadius: -2),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 2,
                  height: 12,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 2.5,
                    color: accentColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          child,
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _NeonToggleTile extends StatelessWidget {
  const _NeonToggleTile({required this.title, required this.value, required this.onChanged});
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.neonCyan,
            activeTrackColor: AppColors.neonCyan.withValues(alpha: 0.3),
            inactiveTrackColor: Colors.white12,
            inactiveThumbColor: Colors.white38,
          ),
        ],
      ),
    );
  }
}

class _NeonNavTile extends StatelessWidget {
  const _NeonNavTile({required this.title, required this.onTap, this.subtitle});
  final String title;
  final VoidCallback onTap;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  if (subtitle != null)
                    Text(
                      subtitle ?? '',
                      maxLines: 3,
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white38, fontSize: 11, height: 1.35),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white38, size: 18),
          ],
        ),
      ),
    );
  }
}

class _NeonStatusTile extends StatelessWidget {
  const _NeonStatusTile({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                Text(
                  subtitle,
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white38, fontSize: 11, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Generic info screen (Privacy Policy / Terms of Service)
// ---------------------------------------------------------------------------

class _InfoScreen extends StatelessWidget {
  const _InfoScreen({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return AnimatedSystemBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.neonCyan.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new,
                          color: AppColors.neonCyan,
                          size: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [AppColors.neonCyan, AppColors.neonViolet],
                      ).createShader(bounds),
                      child: Text(
                        title.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  child: Text(
                    body,
                    style: const TextStyle(fontSize: 13, color: Colors.white60, height: 1.75),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Legal text
// ---------------------------------------------------------------------------

const _kPrivacyPolicy = '''
ChronoSpark collects and processes task data, energy metrics, and session history solely to provide its productivity features. All data is stored locally on your device unless you opt in to cloud sync.

We do not sell, share, or transmit your personal data to third parties. Analytics, if enabled, are aggregated and anonymised.

You may delete your local data at any time by uninstalling the app. For questions, contact support through the app store listing.

Last updated: 2025.
''';

const _kTermsOfService = '''
By using ChronoSpark, you agree to use the app for personal productivity purposes only.

The app is provided "as-is" without warranty of any kind. Task recommendations are generated algorithmically and are not a substitute for professional advice.

Subscription features, where available, are subject to the pricing and terms displayed at point of purchase. Refunds are handled according to the platform's (Apple App Store / Google Play) refund policy.

We reserve the right to modify these terms at any time. Continued use of the app constitutes acceptance of any revised terms.

Last updated: 2025.
''';

const _kSupportInfo = '''
ChronoSpark support:

Website: https://chronospark.app/support

Closed testing notes:
- Tester builds may include bypassed authentication and premium access.
- Live billing is not enabled in QA builds.
- If you encounter an issue, include device model, OS version, and the screen where the issue occurred.

For account or privacy questions, use the support channel listed on the store listing.
''';
