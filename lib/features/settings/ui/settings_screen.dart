import 'dart:async';

import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/dev/test_data_generator.dart';
import 'package:fantastic_guacamole/features/admin/ui/product_advisor_screen.dart';
import 'package:fantastic_guacamole/features/permissions/notification_permission_prompt.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/providers/auth_provider.dart';
import 'package:fantastic_guacamole/state/providers/optimization_provider.dart';
import 'package:fantastic_guacamole/state/providers/route_paths_provider.dart';
import 'package:fantastic_guacamole/state/providers/settings_ui_provider.dart';
import 'package:fantastic_guacamole/state/services/auth_gateway_support.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_content.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_provider.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_reset_service.dart';
import 'package:fantastic_guacamole/tutorial/widgets/micro_tutorial_card.dart';
import 'package:fantastic_guacamole/tutorial/widgets/show_me_again_button.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/constants/app_urls.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routes = ref.watch(routeSurfaceProvider);
    final soundEnabled = ref.watch(soundEnabledProvider);
    final access = ref.watch(appAccessProvider);
    final hasMockSession = ref.watch(mockAuthSessionProvider);
    final intelligence = ref.watch(intelligenceStateProvider);
    final bool accountDeletionConfigured = _hasSecureHttpsEndpoint(Env.accountDeleteEndpoint);
    final bool reflectionTutorialEnabled = ref.watch(
      featureFlagEnabledProvider('daily_reflection_tutorial_enabled'),
    );

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
                          'COMMAND MATRIX',
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
                label: 'SYSTEM TUNING',
                accentColor: AppColors.neonCyan,
                child: Column(
                  children: [
                    _NeonToggleTile(
                      title: 'Audio FX',
                      value: soundEnabled,
                      onChanged: (v) => ref.read(soundEnabledProvider.notifier).set(v),
                    ),
                    ValueListenableBuilder<bool?>(
                      valueListenable: ref.watch(notificationPermissionListenableProvider),
                      builder: (context, granted, _) {
                        final String subtitle = switch (granted) {
                          true => 'Granted',
                          false => 'Denied (scheduling disabled)',
                          null => 'Unknown until app initializes notifications',
                        };
                        return _NeonStatusTile(title: 'Alert Permission', subtitle: subtitle);
                      },
                    ),
                    const SizedBox(height: 8),
                    ValueListenableBuilder<bool?>(
                      valueListenable: ref.watch(notificationPermissionListenableProvider),
                      builder: (context, granted, _) {
                        return NotificationPermissionPrompt(
                          permissionGranted: granted,
                          onRequestPermission: () async {
                            final bool granted = await ref
                                .read(settingsUiActionsProvider)
                                .requestNotificationPermission();
                            return granted;
                          },
                          onOpenSystemSettings: () async {
                            final bool opened = await ref
                                .read(settingsUiActionsProvider)
                                .openSystemAppSettings();
                            if (!context.mounted || opened) {
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Open your device app settings and enable notifications for ChronoSpark.',
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              const _ReflectionReminderSection(),
              if (reflectionTutorialEnabled) ...[
                const SizedBox(height: 12),
                const _DailyReflectionTutorialPanel(),
              ],
              const SizedBox(height: 16),

              _Section(
                label: 'IDENTITY & ACCESS',
                accentColor: AppColors.neonViolet,
                child: Column(
                  children: [
                    _NeonNavTile(
                      title: access.hasTesterFullAccess ? 'Tester Access' : 'Subscription',
                      subtitle: access.subscriptionStatusDetail,
                      onTap: () => context.go(routes.paywall),
                    ),
                    if (hasMockSession)
                      _NeonNavTile(
                        title: 'Sign out Mock Session',
                        subtitle:
                            'Return to login and disable the current tester mock auth session.',
                        onTap: () {
                          ref.read(mockAuthSessionProvider.notifier).set(false);
                          context.go(routes.login);
                        },
                      ),
                    if (access.hasTesterFullAccess)
                      _NeonNavTile(
                        title: 'Reset Tester Data',
                        subtitle: 'Erase local test content and restart onboarding.',
                        onTap: () => unawaited(_confirmTesterReset(context, ref)),
                      ),
                    if (!hasMockSession)
                      accountDeletionConfigured
                          ? _NeonNavTile(
                              title: 'Delete Account',
                              subtitle: 'Permanently delete your account and all synced data.',
                              onTap: () => unawaited(_confirmDeleteAccount(context, ref)),
                            )
                          : _NeonNavTile(
                              title: 'Delete Account',
                              subtitle:
                                  'Temporarily unavailable in this build while account deletion is being finalized.',
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Account deletion is not configured for this build yet.',
                                    ),
                                  ),
                                );
                              },
                            ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              _Section(
                label: 'RUNTIME FLAGS',
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
                label: 'LEGAL PROTOCOLS',
                accentColor: AppColors.memoryAmber,
                child: Column(
                  children: [
                    _NeonNavTile(
                      title: 'Privacy Policy',
                      subtitle: AppUrls.privacy,
                      onTap: () => context.push(routes.privacy),
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
              if (kDebugMode) ...[
                const SizedBox(height: 16),
                _Section(
                  label: 'DEV TOOLS',
                  accentColor: AppColors.neonViolet,
                  child: _NeonNavTile(
                    title: 'Generate Test Data',
                    subtitle: '20 tasks · XP 2400 · streak 14 · energy 75%',
                    onTap: () => unawaited(TestDataGenerator.generate(ref, context)),
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
                      MaterialPageRoute<void>(builder: (_) => const ProductAdvisorScreen()),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const _GlobalMetricsDebugSection(),
                const SizedBox(height: 16),
                const _TutorialLifecycleDebugSection(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmTesterReset(BuildContext context, WidgetRef ref) async {
    final routes = ref.read(routeSurfaceProvider);
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text('Purge tester runtime data?'),
              content: const Text(
                'This permanently removes local tasks, goals, memories, '
                'timeline history, profile progress, focus recovery, logs, '
                'SI state, and tester settings on this device.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Abort'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Purge Data'),
                ),
              ],
            );
          },
        ) ??
        false;
    if (!confirmed || !context.mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Purging local tester runtime data...')));

    try {
      await ref.read(testerDataResetControllerProvider).reset();
      if (context.mounted) {
        context.go(routes.onboarding);
      }
    } on Exception {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tester data purge did not complete. Restart and retry.')),
        );
      }
    }
  }

  Future<void> _confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
    final routes = ref.read(routeSurfaceProvider);
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text('Initiate permanent account purge?'),
              content: const Text(
                'This action cannot be undone. Your account and synced data will be permanently removed.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Abort'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed || !context.mounted) {
      return;
    }

    final TextEditingController passwordController = TextEditingController();
    bool obscurePassword = true;
    final String? password = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext _, StateSetter setState) {
            return AlertDialog(
              title: const Text('Authorize account purge'),
              content: TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Account password',
                  suffixIcon: IconButton(
                    tooltip: obscurePassword ? 'Show password' : 'Hide password',
                    onPressed: () => setState(() {
                      obscurePassword = !obscurePassword;
                    }),
                    icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility),
                  ),
                ),
                onSubmitted: (String value) {
                  Navigator.of(dialogContext).pop(value.trim());
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Abort'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(passwordController.text.trim()),
                  child: const Text('Purge Account'),
                ),
              ],
            );
          },
        );
      },
    );
    passwordController.dispose();

    final String secret = password?.trim() ?? '';
    if (secret.isEmpty || !context.mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Executing account purge...')));

    try {
      await ref.read(authServiceProvider).deleteCurrentAccount(password: secret);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Account purge complete.')));
      context.go(routes.login);
    } on FirebaseAuthException catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyDeleteError(error))));
    } on Exception {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Account purge failed. Retry.')));
    }
  }

  String _friendlyDeleteError(FirebaseAuthException error) {
    final String message = error.message?.trim() ?? '';
    switch (error.code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Password is incorrect.';
      case 'missing-password':
      case 'missing-email':
      case 'operation-not-supported':
      case 'operation-failed':
      case 'network-request-failed':
        return message.isNotEmpty ? message : 'Account purge failed.';
      case 'no-current-user':
        return 'Session expired. Sign in again.';
      default:
        if (message.isNotEmpty) {
          return message;
        }
        return 'Account purge failed. Retry.';
    }
  }
}

bool _hasSecureHttpsEndpoint(String value) {
  final Uri? uri = Uri.tryParse(value.trim());
  return uri != null && uri.hasAuthority && uri.scheme == 'https';
}

class _ReflectionReminderSection extends ConsumerStatefulWidget {
  const _ReflectionReminderSection();

  @override
  ConsumerState<_ReflectionReminderSection> createState() => _ReflectionReminderSectionState();
}

class _DailyReflectionTutorialPanel extends ConsumerWidget {
  const _DailyReflectionTutorialPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(tutorialProgressProvider);
    final TutorialStepContent step = TutorialContent.steps.firstWhere(
      (TutorialStepContent content) => content.id == 'daily_reflection',
      orElse: () => TutorialContent.steps.first,
    );

    return progressAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (progress) {
        if (progress.isStepCompleted(step.id)) {
          return const SizedBox.shrink();
        }

        if (progress.isStepDismissed(step.id)) {
          return Align(
            alignment: Alignment.centerLeft,
            child: ShowMeAgainButton(stepId: step.id, label: 'Show Reflection Tutorial Again'),
          );
        }

        return MicroTutorialCard(
          step: step,
          onComplete: () {
            ref.read(tutorialProgressProvider.notifier).markIntroSeen();
          },
          onDismiss: () {
            ref.read(tutorialProgressProvider.notifier).markIntroSeen();
          },
        );
      },
    );
  }
}

class _ReflectionReminderSectionState extends ConsumerState<_ReflectionReminderSection> {
  bool _enabled = false;
  TimeOfDay _time = const TimeOfDay(hour: 20, minute: 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final ReflectionReminderPrefs prefs = ref
        .read(settingsUiActionsProvider)
        .loadReflectionReminderPrefs();
    setState(() {
      _enabled = prefs.enabled;
      _time = prefs.time;
    });
  }

  Future<void> _toggle(bool value) async {
    final bool enabled = await ref
        .read(settingsUiActionsProvider)
        .setReflectionReminderEnabled(enabled: value, time: _time);
    if (!mounted) {
      return;
    }
    setState(() => _enabled = enabled);
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
    await ref.read(settingsUiActionsProvider).setReflectionReminderTime(time: picked);
    if (_enabled) {
      await ref
          .read(settingsUiActionsProvider)
          .setReflectionReminderEnabled(enabled: true, time: picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Section(
      label: 'DAILY REFLECTION',
      accentColor: AppColors.neonViolet,
      child: Column(
        children: [
          _NeonToggleTile(title: 'Reflection Reminder', value: _enabled, onChanged: _toggle),
          if (_enabled)
            GestureDetector(
              onTap: _pickTime,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Reminder Time',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.neonViolet.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.neonViolet.withValues(alpha: 0.4)),
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
            error: (e, _) => _NeonStatusTile(title: 'Optimizer Error', subtitle: e.toString()),
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

class _TutorialLifecycleDebugSection extends ConsumerWidget {
  const _TutorialLifecycleDebugSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(tutorialProgressProvider);

    return _Section(
      label: 'TUTORIAL LIFECYCLE',
      accentColor: AppColors.neonViolet,
      child: Column(
        children: [
          progressAsync.when(
            data: (progress) => _NeonStatusTile(
              title: 'Status',
              subtitle:
                  'started=${progress.started} · introSeen=${progress.hasSeenIntro} · '
                  'version=${progress.contentVersion} · completed=${progress.completedStepIds.length} · '
                  'skipped=${progress.dismissedStepIds.length} · forever=${progress.skippedForeverStepIds.length}',
            ),
            loading: () =>
                const _NeonStatusTile(title: 'Status', subtitle: 'Loading tutorial state...'),
            error: (e, _) => _NeonStatusTile(title: 'Status Error', subtitle: e.toString()),
          ),
          _NeonNavTile(
            title: 'Start Tutorial',
            subtitle: 'Marks tutorial started for current content version',
            onTap: () => unawaited(ref.read(tutorialProgressProvider.notifier).startTutorial()),
          ),
          _NeonNavTile(
            title: 'Update Content Version',
            subtitle: 'Applies version migration/reset semantics for tutorial state',
            onTap: () => unawaited(
              ref.read(tutorialProgressProvider.notifier).updateTutorialContentVersion(),
            ),
          ),
          _NeonNavTile(
            title: 'Show First Step Again',
            subtitle: 'Reveals ${TutorialContent.steps.first.id} if hidden or skipped forever',
            onTap: () => unawaited(
              ref.read(tutorialResetServiceProvider).showAgain(TutorialContent.steps.first.id),
            ),
          ),
          _NeonNavTile(
            title: 'Reset Tutorial Progress',
            subtitle: 'Clears completion, skip, and start state for tutorial lifecycle',
            onTap: () => unawaited(ref.read(tutorialResetServiceProvider).resetAll()),
          ),
          _NeonNavTile(
            title: 'Replay Onboarding',
            subtitle: 'Marks onboarding incomplete so onboarding flow can be replayed',
            onTap: () => unawaited(ref.read(tutorialResetServiceProvider).replayOnboarding()),
          ),
        ],
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
