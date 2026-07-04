import 'dart:async';

import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/core/constants/app_colors.dart';
import 'package:fantastic_guacamole/core/constants/app_urls.dart';
import 'package:fantastic_guacamole/core/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/data/di/services_providers.dart';
import 'package:fantastic_guacamole/dev/test_data_generator.dart';
import 'package:fantastic_guacamole/features/admin/ui/product_advisor_screen.dart';
import 'package:fantastic_guacamole/features/notifications/notification_scheduler.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/providers/optimization_provider.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:flutter/foundation.dart';
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
      backgroundAssetPath: 'assets/backgrounds/settings_bg.jpg',
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
                        border: Border.all(
                          color: AppColors.neonCyan.withValues(alpha: 0.3),
                        ),
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
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 2,
                            color: Colors.white38,
                          ),
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
                      onChanged: (v) =>
                          ref.read(soundEnabledProvider.notifier).set(v),
                    ),
                    ValueListenableBuilder<bool?>(
                      valueListenable:
                          NotificationScheduler.permissionGrantedListenable,
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

              const _ReflectionReminderSection(),
              const SizedBox(height: 16),

              _Section(
                label: 'ACCOUNT',
                accentColor: AppColors.neonViolet,
                child: Column(
                  children: [
                    _NeonNavTile(
                      title: access.hasTesterFullAccess
                          ? 'Tester Access'
                          : 'Subscription',
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
                    _NeonStatusTile(
                      title: 'Flavor',
                      subtitle: intelligence.environment.appFlavor,
                    ),
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
                      subtitle: intelligence.flags.mockLoginEnabled
                          ? 'Enabled'
                          : 'Disabled',
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
                          builder: (_) => const _InfoScreen(
                            title: 'Privacy Policy',
                            body: _kPrivacyPolicy,
                          ),
                        ),
                      ),
                    ),
                    _NeonNavTile(
                      title: 'Terms of Service',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const _InfoScreen(
                            title: 'Terms of Service',
                            body: _kTermsOfService,
                          ),
                        ),
                      ),
                    ),
                    _NeonNavTile(
                      title: 'Support',
                      subtitle: AppUrls.support,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const _InfoScreen(
                            title: 'Support',
                            body: _kSupportInfo,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 16),
                _Section(
                  label: 'DEV TOOLS',
                  accentColor: AppColors.neonViolet,
                  child: _NeonNavTile(
                    title: 'Generate Test Data',
                    subtitle: '20 tasks · XP 2400 · streak 14 · energy 75%',
                    onTap: () =>
                        unawaited(TestDataGenerator.generate(ref, context)),
                  ),
                ),
                const SizedBox(height: 8),
                _Section(
                  label: 'PRODUCT ADVISOR',
                  accentColor: AppColors.memoryAmber,
                  child: _NeonNavTile(
                    title: 'Open Advisor',
                    subtitle: 'Insights, recommendations, and optimizer state',
                    onTap: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const ProductAdvisorScreen(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const _GlobalMetricsDebugSection(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ReflectionReminderSection extends ConsumerStatefulWidget {
  const _ReflectionReminderSection();

  @override
  ConsumerState<_ReflectionReminderSection> createState() =>
      _ReflectionReminderSectionState();
}

class _ReflectionReminderSectionState
    extends ConsumerState<_ReflectionReminderSection> {
  static const _enabledKey = 'reflection_reminder_enabled';
  static const _timeKey = 'reflection_reminder_time';
  static const _notifId = 'reflection_reminder';

  bool _enabled = false;
  TimeOfDay _time = const TimeOfDay(hour: 20, minute: 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final enabledStr = SharedPrefsService.load(_enabledKey);
    final timeStr = SharedPrefsService.load(_timeKey);
    setState(() {
      _enabled = enabledStr == 'true';
      if (timeStr != null) {
        final parts = timeStr.split(':');
        if (parts.length == 2) {
          _time = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 20,
            minute: int.tryParse(parts[1]) ?? 0,
          );
        }
      }
    });
  }

  Future<void> _toggle(bool value) async {
    setState(() => _enabled = value);
    await SharedPrefsService.save(_enabledKey, value.toString());
    final scheduler = ref.read(notificationSchedulerProvider);
    if (value) {
      await scheduler.scheduleDailyAt(
        id: _notifId,
        title: 'Time to reflect',
        body: 'Capture your thoughts and energy for today.',
        hour: _time.hour,
        minute: _time.minute,
      );
    } else {
      await scheduler.cancel(_notifId);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.neonViolet,
            onPrimary: Colors.white,
            surface: Color(0xFF0B111C),
            onSurface: Colors.white70,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _time = picked);
    await SharedPrefsService.save(_timeKey, '${picked.hour}:${picked.minute}');
    if (_enabled) {
      final scheduler = ref.read(notificationSchedulerProvider);
      await scheduler.cancel(_notifId);
      await scheduler.scheduleDailyAt(
        id: _notifId,
        title: 'Time to reflect',
        body: 'Capture your thoughts and energy for today.',
        hour: picked.hour,
        minute: picked.minute,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Section(
      label: 'DAILY REFLECTION',
      accentColor: AppColors.neonViolet,
      child: Column(
        children: [
          _NeonToggleTile(
            title: 'Reflection Reminder',
            value: _enabled,
            onChanged: _toggle,
          ),
          if (_enabled)
            GestureDetector(
              onTap: _pickTime,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Reminder Time',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.neonViolet.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.neonViolet.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        _time.format(context),
                        style: const TextStyle(
                          color: AppColors.neonViolet,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GlobalMetricsDebugSection extends ConsumerWidget {
  const _GlobalMetricsDebugSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(optimizationConfigProvider);
    return _Section(
      label: 'GLOBAL OPTIMIZER',
      accentColor: AppColors.neonCyan,
      child: Column(
        children: [
          configAsync.when(
            data: (config) => Column(
              children: [
                _NeonStatusTile(
                  title: 'Focus Duration Multiplier',
                  subtitle: config.focusDurationMultiplier.toStringAsFixed(2),
                ),
                _NeonStatusTile(
                  title: 'Task Difficulty Scale',
                  subtitle: config.taskDifficultyScale.toStringAsFixed(2),
                ),
              ],
            ),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (e, _) => _NeonStatusTile(
              title: 'Optimizer Error',
              subtitle: e.toString(),
            ),
          ),
          _NeonNavTile(
            title: 'Refresh Global Metrics',
            subtitle: 'Fetches latest aggregate data from Supabase',
            onTap: () {
              ref.invalidate(optimizationConfigProvider);
            },
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.label,
    required this.child,
    required this.accentColor,
  });
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
          BoxShadow(
            color: accentColor.withValues(alpha: 0.06),
            blurRadius: 16,
            spreadRadius: -2,
          ),
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
  const _NeonToggleTile({
    required this.title,
    required this.value,
    required this.onChanged,
  });
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
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
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
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle ?? '',
                      maxLines: 3,
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        height: 1.35,
                      ),
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
                Text(
                  title,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                Text(
                  subtitle,
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    height: 1.35,
                  ),
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
                          border: Border.all(
                            color: AppColors.neonCyan.withValues(alpha: 0.3),
                          ),
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
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white60,
                      height: 1.75,
                    ),
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
