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

part 'settings_screen.sections.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routes = ref.watch(routeSurfaceProvider);
    final soundEnabled = ref.watch(soundEnabledProvider);
    final access = ref.watch(appAccessProvider);
    final hasMockSession = ref.watch(mockAuthSessionProvider);
    final intelligence = ref.watch(intelligenceStateProvider);
    final bool accountDeletionConfigured = _hasSecureHttpsEndpoint(
      Env.accountDeleteEndpoint,
    );
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
                          'COMMAND MATRIX',
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
                label: 'SYSTEM TUNING',
                accentColor: AppColors.neonCyan,
                child: Column(
                  children: [
                    _NeonToggleTile(
                      title: 'Audio FX',
                      value: soundEnabled,
                      onChanged: (v) =>
                          ref.read(soundEnabledProvider.notifier).set(v),
                    ),
                    ValueListenableBuilder<bool?>(
                      valueListenable: ref.watch(
                        notificationPermissionListenableProvider,
                      ),
                      builder: (context, granted, _) {
                        final String subtitle = switch (granted) {
                          true => 'Granted',
                          false => 'Denied (scheduling disabled)',
                          null => 'Unknown until app initializes notifications',
                        };
                        return _NeonStatusTile(
                          title: 'Alert Permission',
                          subtitle: subtitle,
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    ValueListenableBuilder<bool?>(
                      valueListenable: ref.watch(
                        notificationPermissionListenableProvider,
                      ),
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
                      title: access.hasTesterFullAccess
                          ? 'Tester Access'
                          : 'Subscription',
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
                        subtitle:
                            'Erase local test content and restart onboarding.',
                        onTap: () =>
                            unawaited(_confirmTesterReset(context, ref)),
                      ),
                    if (!hasMockSession)
                      accountDeletionConfigured
                          ? _NeonNavTile(
                              title: 'Delete Account',
                              subtitle:
                                  'Permanently delete your account and all synced data.',
                              onTap: () => unawaited(
                                _confirmDeleteAccount(context, ref),
                              ),
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
                      title: 'Delete Account',
                      subtitle: AppUrls.deleteAccount,
                      onTap: () => context.push(routes.deleteAccount),
                    ),
                    _NeonNavTile(
                      title: 'Terms of Service',
                      subtitle: AppUrls.terms,
                      onTap: () => context.push(routes.terms),
                    ),
                    _NeonNavTile(
                      title: 'Support',
                      subtitle: AppUrls.support,
                      onTap: () => context.push(routes.support),
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

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Purging local tester runtime data...')),
    );

    try {
      await ref.read(testerDataResetControllerProvider).reset();
      if (context.mounted) {
        context.go(routes.onboarding);
      }
    } on Exception {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tester data purge did not complete. Restart and retry.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    WidgetRef ref,
  ) async {
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
                    tooltip: obscurePassword
                        ? 'Show password'
                        : 'Hide password',
                    onPressed: () => setState(() {
                      obscurePassword = !obscurePassword;
                    }),
                    icon: Icon(
                      obscurePassword ? Icons.visibility_off : Icons.visibility,
                    ),
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
                  onPressed: () => Navigator.of(
                    dialogContext,
                  ).pop(passwordController.text.trim()),
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
      await ref
          .read(authServiceProvider)
          .deleteCurrentAccount(password: secret);
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account purge failed. Retry.')),
      );
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
