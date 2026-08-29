import 'dart:async';
import 'dart:convert';

import 'package:fantastic_guacamole/ui/navigation/app_view_navigation.dart';
import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/core/debug/diagnostics_context_service.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/services/backup_cipher.dart';
import 'package:fantastic_guacamole/dev/test_data_generator.dart';
import 'package:fantastic_guacamole/domain/entities/app_theme_entity.dart';
import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/domain/release/assistant_release_control.dart';
import 'package:fantastic_guacamole/features/permissions/notification_permission_prompt.dart';
import 'package:fantastic_guacamole/features/permissions/voice_permission_prompt.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/ui/constants/app_assets.dart';
import 'package:fantastic_guacamole/state/providers/auth_provider.dart';
import 'package:fantastic_guacamole/state/providers/assistant_release_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart'
    as extended_domain;
import 'package:fantastic_guacamole/state/providers/optimization_provider.dart';
import 'package:fantastic_guacamole/state/providers/memories_provider.dart';
import 'package:fantastic_guacamole/state/providers/route_paths_provider.dart';
import 'package:fantastic_guacamole/state/providers/settings_ui_provider.dart';
import 'package:fantastic_guacamole/state/models/personalization_models.dart';
import 'package:fantastic_guacamole/state/services/auth_gateway_support.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/constants/app_urls.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:fantastic_guacamole/ui/system/temporal_glass.dart';
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
    final int extendedSettingsCount = ref
        .watch(extended_domain.appSettingsProvider)
        .length;
    final routes = ref.watch(routeSurfaceProvider);
    final soundEnabled = ref.watch(soundEnabledProvider);
    final themeAsync = ref.watch(currentThemeProvider);
    final bool isDarkMode = themeAsync.asData?.value.isDark ?? true;
    final access = ref.watch(appAccessProvider);
    final walletAsync = ref.watch(aiCreditWalletProvider);
    final bool usesAiCredits = Env.isAiProxyConfigured;
    final String creditLabel = usesAiCredits ? 'AI credits' : 'Smart credits';
    final String creditValue = walletAsync.when(
      data: (wallet) => '${wallet.balance} of ${wallet.allowance} available',
      loading: () => 'Loading balance',
      error: (_, _) => 'Balance unavailable',
    );
    final String creditDetail = walletAsync.when(
      data: (wallet) =>
          '${wallet.tier == 'premium' ? 'Premium' : 'Free'} allowance · resets ${MaterialLocalizations.of(context).formatMediumDate(wallet.resetAt)}',
      loading: () => 'Reading this account’s credit wallet.',
      error: (_, _) => 'Open credits to retry and review usage.',
    );
    final bool hasInternalAdvisorAccess = ref.watch(
      internalAdvisorAccessProvider,
    );
    final hasMockSignIn = ref.watch(mockSignInProvider);
    final intelligence = ref.watch(intelligenceStateProvider);
    final bool accountDeletionConfigured = _hasSecureHttpsEndpoint(
      Env.accountDeleteEndpoint,
    );
    final bool? voicePermissionGranted = ref.watch(
      voicePermissionStatusProvider,
    );
    return AnimatedSystemBackground(
      backgroundAssetPath: AppAssets.bgSettingsControlPlane,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TemporalScreenHeader(
                title: 'SETTINGS',
                subtitle: 'Preferences, guidance, and account control.',
                eyebrow: 'PREFERENCES & ACCOUNT',
                onBack: () {
                  if (Navigator.canPop(context)) {
                    context.pop();
                    return;
                  }
                  goToAppView(context, ref, AppView.nexus);
                },
              ),
              const SizedBox(height: 20),

              _PlanAndCreditsCard(
                planStatus: access.subscriptionStatusLabel,
                planDetail: access.subscriptionStatusDetail,
                creditLabel: creditLabel,
                creditValue: creditValue,
                creditDetail: creditDetail,
                onOpenPlan: () => context.go(routes.paywall),
                onOpenCredits: () => context.go(routes.paywall),
              ),
              const SizedBox(height: 14),

              _SettingsCategory(
                title: 'Appearance & permissions',
                subtitle: 'Theme, sound, alerts, and microphone access',
                icon: Icons.tune_rounded,
                accent: AppColors.neonCyan,
                child: _Section(
                  label: 'APPEARANCE & PERMISSIONS',
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
                            null =>
                              'Unknown until app initializes notifications',
                          };
                          return _NeonStatusTile(
                            title: 'Alert Permission',
                            subtitle:
                                '$subtitle · reminder text may appear in device previews',
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
                                  .requestNotificationPermissionAndRegisterPush();
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
                      const SizedBox(height: 8),
                      VoicePermissionPrompt(
                        permissionGranted: voicePermissionGranted,
                        onRequestPermission: () async {
                          final bool granted = await ref
                              .read(settingsUiActionsProvider)
                              .requestVoicePermission();
                          ref
                              .read(voicePermissionStatusProvider.notifier)
                              .set(granted);
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
                                'Open your device app settings and enable microphone access for ChronoSpark.',
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              const _SettingsCategory(
                title: 'Planning & guidance',
                subtitle:
                    'Reminders, planning preferences, memory, and tutorials',
                icon: Icons.auto_awesome_rounded,
                accent: AppColors.neonViolet,
                child: Column(
                  children: <Widget>[
                    _ReflectionReminderSection(),
                    SizedBox(height: 10),
                    _ReminderAutomationSection(),
                    SizedBox(height: 10),
                    _PersonalizationSection(),
                    SizedBox(height: 10),
                    _MemoryGovernanceSection(),
                    SizedBox(height: 10),
                    _AssistantReleaseSection(),
                    SizedBox(height: 10),
                    _AdaptiveGuidanceSection(),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              _SettingsCategory(
                title: 'Data & account',
                subtitle:
                    'Cloud backup, sign out, local data, and account controls',
                icon: Icons.shield_outlined,
                accent: AppColors.neonCyan,
                child: Column(
                  children: <Widget>[
                    const _CloudDataControlSection(),
                    const SizedBox(height: 10),
                    _Section(
                      label: 'ACCOUNT & DEVICE',
                      accentColor: AppColors.neonViolet,
                      child: Column(
                        children: <Widget>[
                          _NeonNavTile(
                            title: hasMockSignIn
                                ? 'Exit Tester Mode'
                                : 'Log Out',
                            subtitle: hasMockSignIn
                                ? 'Return to login and disable the current tester sign-in state.'
                                : 'Sign out and return to login.',
                            onTap: () => unawaited(
                              _signOut(
                                context,
                                ref,
                                hasMockSignIn: hasMockSignIn,
                              ),
                            ),
                          ),
                          _NeonNavTile(
                            title: 'Clear Local Data',
                            subtitle:
                                'Remove saved planning data, offline actions, notifications, and local intelligence from this device.',
                            onTap: () =>
                                unawaited(_confirmClearLocalData(context, ref)),
                          ),
                          if (access.hasTesterFullAccess)
                            _NeonNavTile(
                              title: 'Reset Tester Data',
                              subtitle:
                                  'Erase local test content and restart onboarding.',
                              onTap: () =>
                                  unawaited(_confirmTesterReset(context, ref)),
                            ),
                          if (!hasMockSignIn)
                            _NeonNavTile(
                              title: 'Delete Account',
                              subtitle: accountDeletionConfigured
                                  ? 'Permanent deletion of account and synced data.'
                                  : 'Deletion endpoint unavailable in this build; request deletion via support.',
                              onTap: () => unawaited(
                                accountDeletionConfigured
                                    ? _confirmDeleteAccount(context, ref)
                                    : _requestAccountDeletionSupport(
                                        context,
                                        ref,
                                      ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              _SettingsCategory(
                title: 'Help & legal',
                subtitle: 'Support, privacy, terms, and account assistance',
                icon: Icons.help_outline_rounded,
                accent: AppColors.memoryAmber,
                child: _Section(
                  label: 'HELP & LEGAL',
                  accentColor: AppColors.memoryAmber,
                  child: Column(
                    children: [
                      _NeonNavTile(
                        title: 'Privacy Policy',
                        subtitle: AppUrls.privacy,
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
                        subtitle:
                            'Review app/device context before sending; no stable device ID is included.',
                        onTap: () => unawaited(
                          _contactSupportWithDiagnostics(context, ref),
                        ),
                      ),
                      _NeonNavTile(
                        title: 'Copy Support Email',
                        subtitle:
                            'Copy prefilled support email template to clipboard',
                        onTap: () =>
                            unawaited(_copySupportEmailTemplate(context)),
                      ),
                      _NeonNavTile(
                        title: 'Copy Diagnostics',
                        subtitle:
                            'Copy a reviewable, identifier-free support summary',
                        onTap: () =>
                            unawaited(_copyDiagnosticsToClipboard(context)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (kDebugMode) ...[
                _SettingsCategory(
                  title: 'Developer & diagnostics',
                  subtitle:
                      'Internal build details, backend health, and test tools',
                  icon: Icons.developer_mode_rounded,
                  accent: AppColors.neonViolet,
                  child: Column(
                    children: <Widget>[
                      _Section(
                        label: 'RUNTIME FLAGS',
                        accentColor: AppColors.neonCyan,
                        child: Column(
                          children: <Widget>[
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
                            _NeonStatusTile(
                              title: 'Extended Settings',
                              subtitle: '$extendedSettingsCount loaded',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      const _SupabaseBackendHealthSection(),
                      const SizedBox(height: 10),
                      _Section(
                        label: 'DEV TOOLS',
                        accentColor: AppColors.neonViolet,
                        child: _NeonNavTile(
                          title: 'Generate Test Data',
                          subtitle:
                              '20 tasks · XP 2400 · streak 14 · energy 75%',
                          onTap: () => unawaited(
                            TestDataGenerator.generate(ref, context),
                          ),
                        ),
                      ),
                      if (hasInternalAdvisorAccess) ...[
                        const SizedBox(height: 8),
                        _Section(
                          label: 'INTERNAL DIAGNOSTICS',
                          accentColor: AppColors.memoryAmber,
                          child: _NeonNavTile(
                            title: 'Advisor Diagnostics',
                            subtitle:
                                'Admin-only product health and optimizer state',
                            onTap: () => context.push(routes.advisor),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      const _GlobalMetricsDebugSection(),
                      const SizedBox(height: 10),
                      const _AdaptiveGuidanceDebugSection(),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _signOut(
    BuildContext context,
    WidgetRef ref, {
    required bool hasMockSignIn,
  }) async {
    final routes = ref.read(routeSurfaceProvider);
    try {
      if (hasMockSignIn) {
        ref.read(mockSignInProvider.notifier).set(false);
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not log out. Please try again.')),
      );
    }
  }

  Future<void> _confirmTesterReset(BuildContext context, WidgetRef ref) async {
    final routes = ref.read(routeSurfaceProvider);
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text('Clear tester data?'),
              content: const Text(
                'This permanently removes local tasks, goals, memories, '
                'timeline history, profile progress, recovery data, logs, '
                'SI state, and tester settings on this device.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Clear Data'),
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
              'Tester data could not be cleared. Restart and retry.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _confirmClearLocalData(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            icon: const Icon(
              Icons.phonelink_erase_rounded,
              color: AppColors.memoryAmber,
            ),
            title: const Text('Clear data from this device?'),
            content: const SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Your ChronoSpark cloud account and Google Play subscription remain active.',
                    style: TextStyle(
                      color: AppColors.neonCyan,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 16),
                  TemporalStatusRow(
                    icon: Icons.history_rounded,
                    text:
                        'Planning records and Timeline history are removed from this device.',
                    color: AppColors.memoryAmber,
                  ),
                  SizedBox(height: 10),
                  TemporalStatusRow(
                    icon: Icons.notifications_off_outlined,
                    text:
                        'Offline actions and scheduled reminders are removed.',
                    color: AppColors.memoryAmber,
                  ),
                  SizedBox(height: 10),
                  TemporalStatusRow(
                    icon: Icons.psychology_outlined,
                    text:
                        'Profile progress and local intelligence are removed.',
                    color: AppColors.memoryAmber,
                  ),
                  SizedBox(height: 14),
                  Text(
                    'Local removal cannot be undone. This is not account deletion.',
                    style: TextStyle(color: Colors.white70, height: 1.4),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              FilledButton.icon(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                icon: const Icon(Icons.shield_outlined),
                label: const Text('Keep local data'),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.memoryAmber,
                ),
                icon: const Icon(Icons.phonelink_erase_rounded),
                label: const Text('Clear this device'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) return;
    try {
      await ref
          .read(localUserDataCleanupServiceProvider)
          .clearForAccountSwitch();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Local data cleared from this device.')),
      );
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Local data could not be cleared. Retry.'),
        ),
      );
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
              icon: const Icon(
                Icons.person_remove_outlined,
                color: AppColors.recallRed,
              ),
              title: const Text('Delete account permanently?'),
              content: const SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Your ChronoSpark account and synced planning data will be permanently removed.',
                      style: TextStyle(color: Colors.white, height: 1.4),
                    ),
                    SizedBox(height: 14),
                    TemporalStatusRow(
                      icon: Icons.cloud_off_outlined,
                      text: 'Deleted cloud data cannot be restored.',
                      color: AppColors.recallRed,
                    ),
                    SizedBox(height: 10),
                    TemporalStatusRow(
                      icon: Icons.play_arrow_rounded,
                      text:
                          'An active Google Play subscription is not canceled automatically. Manage it separately in Google Play.',
                      color: AppColors.memoryAmber,
                    ),
                    SizedBox(height: 14),
                    Text(
                      'Nothing has been deleted yet.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                FilledButton.icon(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  icon: const Icon(Icons.shield_outlined),
                  label: const Text('Keep my account'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.recallRed,
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Continue'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed || !context.mounted) {
      return;
    }

    final String provider =
        ref
            .read(authServiceProvider)
            .currentUser
            ?.appMetadata['provider']
            ?.toString()
            .trim()
            .toLowerCase() ??
        'email';
    if (provider == 'google' || provider == 'github') {
      final String providerLabel = provider == 'google' ? 'Google' : 'GitHub';
      final bool continueToHostedPath =
          await showDialog<bool>(
            context: context,
            builder: (BuildContext dialogContext) => AlertDialog(
              icon: const Icon(Icons.verified_user_outlined),
              title: Text('Verify with $providerLabel'),
              content: Text(
                'This account uses $providerLabel, so it does not have a ChronoSpark password to enter here. Continue to the secure account-deletion page and follow its identity-verification instructions.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Continue securely'),
                ),
              ],
            ),
          ) ??
          false;
      if (!continueToHostedPath || !context.mounted) {
        return;
      }
      await _openExternalWithFallback(
        context: context,
        ref: ref,
        url: AppUrls.deleteAccount,
        fallbackRoute: routes.deleteAccount,
        failureLabel: 'Unable to open the hosted account-deletion page.',
      );
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
              title: const Text('Confirm account deletion'),
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
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(
                    dialogContext,
                  ).pop(passwordController.text.trim()),
                  child: const Text('Delete Account'),
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
    ).showSnackBar(const SnackBar(content: Text('Deleting account...')));

    try {
      await ref
          .read(authServiceProvider)
          .deleteCurrentAccount(password: secret);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Account deleted.')));
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
        const SnackBar(content: Text('Account deletion failed. Retry.')),
      );
    }
  }

  String _friendlyDeleteError(FirebaseAuthException error) {
    switch (error.code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Password is incorrect.';
      case 'missing-password':
      case 'missing-email':
      case 'operation-not-supported':
      case 'operation-failed':
      case 'network-request-failed':
        return 'Account deletion could not be completed. Retry or use the support request path.';
      case 'no-current-user':
        return 'Sign-in expired. Sign in again before deleting the account.';
      default:
        return 'Account deletion failed. Retry.';
    }
  }

  Future<void> _openExternalWithFallback({
    required BuildContext context,
    required WidgetRef ref,
    required String url,
    required String fallbackRoute,
    required String failureLabel,
  }) async {
    final bool opened = await ref
        .read(externalUrlServiceProvider)
        .open(Uri.parse(url));
    if (opened || !context.mounted) {
      return;
    }
    context.push(fallbackRoute);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(failureLabel)));
  }

  Future<void> _requestAccountDeletionSupport(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final Uri mail = Uri(
      scheme: 'mailto',
      path: Env.supportEmail,
      queryParameters: <String, String>{
        'subject': 'Account deletion request',
        'body':
            'Please delete my ChronoSpark account associated with this email.',
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
        content: Text(
          'No email app found. Account deletion email template copied to clipboard.',
        ),
      ),
    );
  }

  Future<void> _contactSupportWithDiagnostics(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      final DiagnosticsContext diagnostics =
          await DiagnosticsContextService.collect();
      final String body = _buildSupportEmailBody(diagnostics);

      final Uri mail = Uri(
        scheme: 'mailto',
        path: Env.supportEmail,
        queryParameters: <String, String>{
          'subject': 'ChronoSpark support request',
          'body': body,
        },
      );

      final bool opened = await ref.read(externalUrlServiceProvider).open(mail);
      if (opened || !context.mounted) {
        return;
      }
      await Clipboard.setData(
        ClipboardData(
          text:
              'To: ${Env.supportEmail}\nSubject: ChronoSpark support request\n\n$body',
        ),
      );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No email app found. Support email template copied to clipboard.',
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to gather diagnostics for support.'),
        ),
      );
    }
  }

  Future<void> _copyDiagnosticsToClipboard(BuildContext context) async {
    try {
      final DiagnosticsContext diagnostics =
          await DiagnosticsContextService.collect();
      final String payload = _buildDiagnosticsPayload(diagnostics);
      await Clipboard.setData(ClipboardData(text: payload));
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Diagnostics copied to clipboard.')),
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not copy diagnostics. Try Contact Support instead.',
          ),
        ),
      );
    }
  }

  Future<void> _copySupportEmailTemplate(BuildContext context) async {
    try {
      final DiagnosticsContext diagnostics =
          await DiagnosticsContextService.collect();
      final String body = _buildSupportEmailBody(diagnostics);
      final String payload =
          'To: ${Env.supportEmail}\nSubject: ChronoSpark support request\n\n$body';
      await Clipboard.setData(ClipboardData(text: payload));
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Support email template copied to clipboard.'),
        ),
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not copy support email template.')),
      );
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
        'Stable device identifier: omitted by default\n';
  }
}

bool _hasSecureHttpsEndpoint(String value) {
  final Uri? uri = Uri.tryParse(value.trim());
  return uri != null && uri.hasAuthority && uri.scheme == 'https';
}
