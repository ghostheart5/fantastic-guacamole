import 'dart:async';

import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/core/debug/diagnostics_context_service.dart';
import 'package:fantastic_guacamole/dev/test_data_generator.dart';
import 'package:fantastic_guacamole/domain/entities/app_theme_entity.dart';
import 'package:fantastic_guacamole/features/permissions/notification_permission_prompt.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/providers/auth_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart'
    as extended_domain;
import 'package:fantastic_guacamole/state/providers/optimization_provider.dart';
import 'package:fantastic_guacamole/state/providers/route_paths_provider.dart';
import 'package:fantastic_guacamole/state/providers/settings_ui_provider.dart';
import 'package:fantastic_guacamole/state/services/auth_gateway_support.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_content.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_provider.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_reset_service.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_target_registry.dart';
import 'package:fantastic_guacamole/tutorial/widgets/micro_tutorial_card.dart';
import 'package:fantastic_guacamole/tutorial/widgets/show_me_again_button.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/constants/app_urls.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

part 'settings_screen.sections.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(extended_domain.extendedDomainBootstrapProvider);
    final int extendedSettingsCount = ref.watch(extended_domain.appSettingsProvider).length;
    final int legalPoliciesCount = ref.watch(extended_domain.privacyPoliciesProvider).length;
    final routes = ref.watch(routeSurfaceProvider);
    final soundEnabled = ref.watch(soundEnabledProvider);
    final themeAsync = ref.watch(currentThemeProvider);
    final bool isDarkMode = themeAsync.asData?.value.isDark ?? true;
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
                      title: 'Dark Mode',
                      value: isDarkMode,
                      onChanged: (bool enabled) {
                        final AppThemeEntity next = enabled
                            ? AppThemeEntity.dark()
                            : AppThemeEntity.light();
                        unawaited(ref.read(themeActionsProvider).save(next));
                      },
                    ),
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
              const SizedBox(height: 16),
              const _ReminderAutomationSection(),
              if (reflectionTutorialEnabled) ...[
                const SizedBox(height: 12),
                const _DailyReflectionTutorialPanel(),
              ],
              const SizedBox(height: 16),
              const _ChronoSparkAcademySection(),
              const SizedBox(height: 16),

              _Section(
                label: 'IDENTITY & ACCESS',
                accentColor: AppColors.neonViolet,
                child: Column(
                  children: [
                    _NeonNavTile(
                      title: 'Subscription & Paywall',
                      subtitle: access.subscriptionStatusDetail,
                      onTap: () => context.go(routes.paywall),
                    ),
                    _NeonNavTile(
                      title: hasMockSession ? 'Sign out Mock Session' : 'Log Out',
                      subtitle: hasMockSession
                          ? 'Return to login and disable the current tester mock auth session.'
                          : 'End the current session and return to login.',
                      onTap: () =>
                          unawaited(_signOut(context, ref, hasMockSession: hasMockSession)),
                    ),
                    if (access.hasTesterFullAccess)
                      _NeonNavTile(
                        title: 'Reset Tester Data',
                        subtitle: 'Erase local test content and restart onboarding.',
                        onTap: () => unawaited(_confirmTesterReset(context, ref)),
                      ),
                    if (!hasMockSession)
                      _NeonNavTile(
                        title: 'Delete Account',
                        subtitle: accountDeletionConfigured
                            ? 'Permanent deletion of account and synced data.'
                            : 'Deletion endpoint unavailable in this build; request deletion via support.',
                        onTap: () => unawaited(
                          accountDeletionConfigured
                              ? _confirmDeleteAccount(context, ref)
                              : _requestAccountDeletionSupport(context, ref),
                        ),
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
                    _NeonStatusTile(
                      title: 'Extended Settings',
                      subtitle: '$extendedSettingsCount loaded',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const _SupabaseBackendHealthSection(),
              const SizedBox(height: 16),

              _Section(
                label: 'LEGAL PROTOCOLS',
                accentColor: AppColors.memoryAmber,
                child: Column(
                  children: [
                    _NeonNavTile(
                      title: 'Privacy Policy',
                      subtitle: legalPoliciesCount > 0
                          ? 'Live: ${AppUrls.privacy} · local cache:$legalPoliciesCount'
                          : AppUrls.privacy,
                      onTap: () => unawaited(
                        _openExternalWithFallback(
                          context: context,
                          ref: ref,
                          url: AppUrls.privacy,
                          fallbackRoute: routes.privacy,
                          failureLabel: 'Privacy policy link unavailable.',
                        ),
                      ),
                    ),
                    _NeonNavTile(
                      title: 'Terms of Service',
                      onTap: () => unawaited(
                        _openExternalWithFallback(
                          context: context,
                          ref: ref,
                          url: AppUrls.terms,
                          fallbackRoute: routes.terms,
                          failureLabel: 'Terms link unavailable.',
                        ),
                      ),
                    ),
                    _NeonNavTile(
                      title: 'Support',
                      subtitle: 'Help center: ${AppUrls.support}',
                      onTap: () => unawaited(
                        _openExternalWithFallback(
                          context: context,
                          ref: ref,
                          url: AppUrls.support,
                          fallbackRoute: routes.support,
                          failureLabel: 'Support link unavailable.',
                        ),
                      ),
                    ),
                    _NeonNavTile(
                      title: 'Contact Support',
                      subtitle: 'Send email with diagnostics context prefilled',
                      onTap: () => unawaited(_contactSupportWithDiagnostics(context, ref)),
                    ),
                    _NeonNavTile(
                      title: 'Copy Support Email',
                      subtitle: 'Copy prefilled support email template to clipboard',
                      onTap: () => unawaited(_copySupportEmailTemplate(context)),
                    ),
                    _NeonNavTile(
                      title: 'Copy Diagnostics',
                      subtitle: 'Copy app and device context for support forms',
                      onTap: () => unawaited(_copyDiagnosticsToClipboard(context)),
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
                    onTap: () => context.push(routes.advisor),
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

  Future<void> _signOut(BuildContext context, WidgetRef ref, {required bool hasMockSession}) async {
    final routes = ref.read(routeSurfaceProvider);
    try {
      if (hasMockSession) {
        ref.read(mockAuthSessionProvider.notifier).set(false);
      } else {
        await ref.read(authServiceProvider).signOut();
      }
      if (!context.mounted) {
        return;
      }
      context.go(routes.login);
    } on Exception {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not log out. Please try again.')));
    }
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

  Future<void> _openExternalWithFallback({
    required BuildContext context,
    required WidgetRef ref,
    required String url,
    required String fallbackRoute,
    required String failureLabel,
  }) async {
    final bool opened = await ref.read(externalUrlServiceProvider).open(Uri.parse(url));
    if (opened || !context.mounted) {
      return;
    }
    context.push(fallbackRoute);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failureLabel)));
  }

  Future<void> _requestAccountDeletionSupport(BuildContext context, WidgetRef ref) async {
    final Uri mail = Uri(
      scheme: 'mailto',
      path: Env.supportEmail,
      queryParameters: <String, String>{
        'subject': 'Account deletion request',
        'body': 'Please delete my ChronoSpark account associated with this email.',
      },
    );
    final bool opened = await ref.read(externalUrlServiceProvider).open(mail);
    if (opened || !context.mounted) {
      return;
    }
    await Clipboard.setData(
      const ClipboardData(
        text:
            'To: support@chronospark.app\nSubject: Account deletion request\n\nPlease delete my ChronoSpark account associated with this email.',
      ),
    );
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No email app found. Account deletion email template copied to clipboard.'),
      ),
    );
  }

  Future<void> _contactSupportWithDiagnostics(BuildContext context, WidgetRef ref) async {
    try {
      final DiagnosticsContext diagnostics = await DiagnosticsContextService.collect();
      final String body = _buildSupportEmailBody(diagnostics);

      final Uri mail = Uri(
        scheme: 'mailto',
        path: Env.supportEmail,
        queryParameters: <String, String>{'subject': 'ChronoSpark support request', 'body': body},
      );

      final bool opened = await ref.read(externalUrlServiceProvider).open(mail);
      if (opened || !context.mounted) {
        return;
      }
      await Clipboard.setData(
        ClipboardData(
          text: 'To: ${Env.supportEmail}\nSubject: ChronoSpark support request\n\n$body',
        ),
      );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No email app found. Support email template copied to clipboard.'),
        ),
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to gather diagnostics for support.')));
    }
  }

  Future<void> _copyDiagnosticsToClipboard(BuildContext context) async {
    try {
      final DiagnosticsContext diagnostics = await DiagnosticsContextService.collect();
      final String payload = _buildDiagnosticsPayload(diagnostics);
      await Clipboard.setData(ClipboardData(text: payload));
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Diagnostics copied to clipboard.')));
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not copy diagnostics. Try Contact Support instead.')),
      );
    }
  }

  Future<void> _copySupportEmailTemplate(BuildContext context) async {
    try {
      final DiagnosticsContext diagnostics = await DiagnosticsContextService.collect();
      final String body = _buildSupportEmailBody(diagnostics);
      final String payload =
          'To: ${Env.supportEmail}\nSubject: ChronoSpark support request\n\n$body';
      await Clipboard.setData(ClipboardData(text: payload));
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Support email template copied to clipboard.')));
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not copy support email template.')));
    }
  }

  String _buildSupportEmailBody(DiagnosticsContext diagnostics) {
    return 'Issue summary:\n'
        '- What happened:\n'
        '- What I expected:\n'
        '- Steps to reproduce:\n\n'
        '${_buildDiagnosticsPayload(diagnostics)}';
  }

  String _buildDiagnosticsPayload(DiagnosticsContext diagnostics) {
    return 'ChronoSpark diagnostics\n'
        'App: ${diagnostics.appName}\n'
        'Version: ${diagnostics.appVersionLabel}\n'
        'Package: ${diagnostics.packageName}\n'
        'Platform: ${diagnostics.platform}\n'
        'OS: ${diagnostics.osVersion}\n'
        'Device: ${diagnostics.model}\n'
        'Physical device: ${diagnostics.isPhysicalDevice}\n'
        'Device ID: ${diagnostics.deviceId}\n';
  }
}

bool _hasSecureHttpsEndpoint(String value) {
  final Uri? uri = Uri.tryParse(value.trim());
  return uri != null && uri.hasAuthority && uri.scheme == 'https';
}
