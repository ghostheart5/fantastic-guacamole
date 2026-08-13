import 'dart:async';

import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/domain/entities/app_theme_entity.dart';
import 'package:fantastic_guacamole/features/auth/application/auth_providers.dart';
import 'package:fantastic_guacamole/features/permissions/notification_permission_prompt.dart';
import 'package:fantastic_guacamole/features/permissions/voice_permission_prompt.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/providers/auth_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart'
    as extended_domain;
import 'package:fantastic_guacamole/state/providers/route_paths_provider.dart';
import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/state/providers/settings_ui_provider.dart';
import 'package:fantastic_guacamole/state/providers/settings_preference_provider.dart';
import 'package:fantastic_guacamole/state/services/auth_gateway_support.dart';
import 'package:fantastic_guacamole/system/audio/audio_service.dart';
import 'package:fantastic_guacamole/ui/constants/app_assets.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/constants/app_urls.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

part 'settings_screen.sections.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _syncAudioSettings();
    });
  }

  void _syncAudioSettings() {
    AudioService.setSoundEffectsEnabled(ref.read(soundEnabledProvider));
    AudioService.setAdvancedProfileEnabled(
      ref.read(advancedAudioProfileEnabledProvider),
    );
    AudioService.setHapticsEnabled(ref.read(hapticFeedbackEnabledProvider));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(
      soundEnabledProvider,
      (_, next) => AudioService.setSoundEffectsEnabled(next),
    );
    ref.listen<bool>(
      advancedAudioProfileEnabledProvider,
      (_, next) => AudioService.setAdvancedProfileEnabled(next),
    );
    ref.listen<bool>(
      hapticFeedbackEnabledProvider,
      (_, next) => AudioService.setHapticsEnabled(next),
    );

    ref.watch(extended_domain.extendedDomainBootstrapProvider);
    final int legalPoliciesCount = ref
        .watch(extended_domain.privacyPoliciesProvider)
        .length;
    final routes = ref.watch(routeSurfaceProvider);
    final soundEnabled = ref.watch(soundEnabledProvider);
    ref.watch(settingsPreferencesProvider);
    final advancedAudioEnabled = ref.watch(advancedAudioProfileEnabledProvider);
    final hapticFeedbackEnabled = ref.watch(hapticFeedbackEnabledProvider);
    final motionProfile = ref.watch(motionProfileProvider);
    final bool systemReducedMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final themeAsync = ref.watch(currentThemeProvider);
    final bool isDarkMode = themeAsync.asData?.value.isDark ?? true;
    final access = ref.watch(appAccessProvider);
    final hasMockSession = ref.watch(mockAuthSessionProvider);
    final notificationPermission = ref.watch(notificationPermissionProvider);
    final voicePermissionStatus = ref.watch(voicePermissionStatusProvider);
    final bool accountDeletionConfigured = _hasSecureHttpsEndpoint(
      Env.accountDeleteEndpoint,
    );
    final bool allowDeletionSupportFallback = !kReleaseMode;

    return Semantics(
      identifier: 'screen-settings',
      container: true,
      child: AnimatedSystemBackground(
        backgroundAssetPath: AppAssets.bgSettings,
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
                        ref.read(appFlowProvider.notifier).toNexus();
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
                              colors: [
                                AppColors.neonCyan,
                                AppColors.neonViolet,
                              ],
                            ).createShader(bounds),
                            child: const Text(
                              'Settings',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const Text(
                            'Preferences, account, and support',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 0.8,
                              color: Colors.white38,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xEE07111F),
                        AppColors.neonCyan.withValues(alpha: 0.10),
                        AppColors.neonViolet.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.neonCyan.withValues(alpha: 0.25),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.neonCyan.withValues(alpha: 0.08),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Workspace status',
                        style: TextStyle(
                          color: AppColors.neonCyan,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Settings are ready',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Manage app controls, account access, and support links here.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                _Section(
                  label: 'APP PREFERENCES',
                  accentColor: AppColors.neonCyan,
                  child: Column(
                    children: [
                      _NeonToggleTile(
                        title: 'Dark mode',
                        switchKey: const Key('settings_dark_mode_toggle'),
                        value: isDarkMode,
                        onChanged: (bool enabled) {
                          final AppThemeEntity next = enabled
                              ? AppThemeEntity.dark()
                              : AppThemeEntity.light();
                          unawaited(ref.read(themeActionsProvider).save(next));
                        },
                      ),
                      _NeonToggleTile(
                        title: 'Audio effects',
                        value: soundEnabled,
                        onChanged: (bool enabled) {
                          unawaited(
                            ref
                                .read(settingsPreferencesProvider.notifier)
                                .setSoundEnabled(enabled),
                          );
                          AudioService.setSoundEffectsEnabled(enabled);
                        },
                      ),
                      _NeonToggleTile(
                        title: 'Advanced audio profile (optional)',
                        value: advancedAudioEnabled,
                        onChanged: (bool enabled) {
                          ref
                              .read(
                                advancedAudioProfileEnabledProvider.notifier,
                              )
                              .set(enabled);
                          AudioService.setAdvancedProfileEnabled(enabled);
                        },
                      ),
                      _NeonToggleTile(
                        title: 'Haptic feedback',
                        value: hapticFeedbackEnabled,
                        onChanged: (bool enabled) {
                          ref
                              .read(hapticFeedbackEnabledProvider.notifier)
                              .set(enabled);
                          AudioService.setHapticsEnabled(enabled);
                        },
                      ),
                      _MotionProfileTile(
                        value: motionProfile,
                        onChanged: (MotionProfile value) {
                          ref.read(motionProfileProvider.notifier).set(value);
                        },
                      ),
                      if (!kReleaseMode)
                        _NeonStatusTile(
                          title: 'Motion Debug',
                          subtitle:
                              'Profile: ${motionProfile.name.toUpperCase()} | System reduced motion: ${systemReducedMotion ? 'ON' : 'OFF'}',
                        ),
                      _NeonStatusTile(
                        title: 'Notifications',
                        subtitle: switch (notificationPermission.granted) {
                          true => 'Granted',
                          false => 'Denied (reminders are off)',
                          null => 'Checking notification access',
                        },
                      ),
                      const SizedBox(height: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          NotificationPermissionPrompt(
                            permissionGranted: notificationPermission.granted,
                            permissionState:
                                notificationPermission.permissionState,
                            onRequestPermission: () async {
                              final NotificationPermissionSnapshot state =
                                  await ref
                                      .read(
                                        notificationPermissionProvider.notifier,
                                      )
                                      .requestPermission();
                              return state.isGranted;
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
                          ),
                          if (notificationPermission.granted == false)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  context.push(
                                    RoutePaths.notificationPermissionRecovery,
                                  );
                                },
                                icon: const Icon(Icons.build_circle_outlined),
                                label: const Text('Fix notification access'),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      VoicePermissionPrompt(
                        permissionGranted: voicePermissionStatus,
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
                      const SizedBox(height: 12),
                      const _ReflectionReminderSection(),
                      const SizedBox(height: 12),
                      const _ReminderAutomationSection(),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                _Section(
                  label: 'ACCOUNT',
                  accentColor: AppColors.neonViolet,
                  child: Column(
                    children: [
                      _NeonNavTile(
                        title: 'Profile & Identity',
                        subtitle: 'Name, progress, and identity settings.',
                        onTap: () => context.push(RoutePaths.profile),
                      ),
                      _NeonNavTile(
                        title: 'Billing Center',
                        subtitle: 'Manage your plan and renewal status.',
                        onTap: () =>
                            context.push(RoutePaths.subscriptionManagement),
                      ),
                      _NeonNavTile(
                        title: 'Credit History',
                        subtitle: 'Review credit purchases and usage records.',
                        onTap: () => context.push(RoutePaths.creditHistory),
                      ),
                      _NeonNavTile(
                        title: 'Explore Plans',
                        subtitle:
                            '${access.subscriptionStatusDetail} · compare plan tiers.',
                        onTap: () => context.push(routes.paywall),
                      ),
                      _NeonNavTile(
                        title: 'Log Out',
                        subtitle: 'End the current session.',
                        onTap: () => unawaited(
                          _signOut(
                            context,
                            ref,
                            hasMockSession: hasMockSession,
                          ),
                        ),
                      ),
                      if (!hasMockSession)
                        _NeonNavTile(
                          title: 'Delete Account',
                          subtitle: accountDeletionConfigured
                              ? 'Permanent deletion of account and synced data.'
                              : (allowDeletionSupportFallback
                                    ? 'Deletion endpoint unavailable in this build; open the deletion instructions.'
                                    : 'Deletion endpoint unavailable; open the verified deletion instructions.'),
                          onTap: () => unawaited(
                            accountDeletionConfigured
                                ? _confirmDeleteAccount(context, ref)
                                : (allowDeletionSupportFallback
                                      ? _requestAccountDeletionSupport(
                                          context,
                                          ref,
                                        )
                                      : _showAccountDeletionUnavailable(
                                          context,
                                          ref,
                                        )),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                _Section(
                  label: 'SUPPORT & LEGAL',
                  accentColor: AppColors.memoryAmber,
                  child: Column(
                    children: [
                      _NeonNavTile(
                        title: 'Privacy Policy',
                        subtitle: legalPoliciesCount > 0
                            ? 'Live: ${AppUrls.privacy} | cache: $legalPoliciesCount'
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
                        title: 'About ChronoSpark',
                        subtitle:
                            'App information, privacy, and support details.',
                        onTap: () => context.push(RoutePaths.about),
                      ),
                    ],
                  ),
                ),
                if (!kReleaseMode) ...[
                  const SizedBox(height: 16),
                  _Section(
                    label: 'DEVELOPER',
                    accentColor: AppColors.neonCyan,
                    child: Column(
                      children: [
                        _NeonNavTile(
                          title: 'Completion Events Inspector',
                          subtitle:
                              'Review and clear local completion_events_v1 records.',
                          onTap: () =>
                              context.push(RoutePaths.completionEvents),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signOut(
    BuildContext context,
    WidgetRef ref, {
    required bool hasMockSession,
  }) async {
    final routes = ref.read(routeSurfaceProvider);
    try {
      if (hasMockSession) {
        ref.read(mockAuthSessionProvider.notifier).set(false);
      } else {
        await ref.read(authControllerProvider.notifier).signOut();
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
                'This action cannot be undone. Your account and synced data will be permanently removed.\n\n'
                'Deleting ChronoSpark does not cancel an active Google Play subscription. First open Google Play, then go to Payments & subscriptions > Subscriptions and cancel ChronoSpark.',
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

    final authService = ref.read(authServiceProvider);
    final AccountDeletionReauthenticationMethod reauthenticationMethod =
        authService.currentUser?.accountDeletionReauthenticationMethod ??
        AccountDeletionReauthenticationMethod.unsupported;
    String secret = '';
    if (reauthenticationMethod ==
        AccountDeletionReauthenticationMethod.password) {
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
                        obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
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
      secret = password?.trim() ?? '';
      if (secret.isEmpty) {
        return;
      }
    } else if (reauthenticationMethod ==
            AccountDeletionReauthenticationMethod.recentGoogleSignIn ||
        reauthenticationMethod ==
            AccountDeletionReauthenticationMethod.recentPhoneSignIn) {
      final String provider =
          reauthenticationMethod ==
              AccountDeletionReauthenticationMethod.recentGoogleSignIn
          ? 'Google'
          : 'phone';
      final bool useRecentSignIn =
          await showDialog<bool>(
            context: context,
            builder: (BuildContext dialogContext) => AlertDialog(
              title: Text('Verify recent $provider sign-in'),
              content: Text(
                'ChronoSpark can delete this account only within '
                '${defaultAccountDeletionRecentSignInWindow.inMinutes} minutes of a $provider sign-in. '
                'If that window has passed, abort, sign out, sign back in with $provider, and retry. The server will reject a stale session.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Abort'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Verify and Purge'),
                ),
              ],
            ),
          ) ??
          false;
      if (!useRecentSignIn) {
        return;
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This account provider cannot be reauthenticated safely. Account deletion was stopped.',
          ),
        ),
      );
      return;
    }

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Executing account purge...')));

    try {
      await authService.deleteCurrentAccount(password: secret);
      await _clearOnboardingLocalState();
      ref.read(onboardingCompleteProvider.notifier).set(false);
      ref
          .read(onboardingStatusProvider.notifier)
          .set(OnboardingStatus.incomplete);
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

  Future<void> _clearOnboardingLocalState() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(onboardingCompleteStorageKey);
    await prefs.remove(onboardingContentVersionStorageKey);
    await prefs.remove(onboardingStepStorageKey);
    await prefs.remove(creatorFirstItemCreatedStorageKey);
    await prefs.remove(timelineFirstActionCompletedStorageKey);

    if (!Env.isSupabaseConfigured) {
      return;
    }

    try {
      final String? userId = sb.Supabase.instance.client.auth.currentUser?.id;
      if (userId == null || userId.trim().isEmpty) {
        return;
      }
      await prefs.remove(onboardingCompleteStorageKeyForUser(userId));
      await prefs.remove(onboardingContentVersionStorageKeyForUser(userId));
      await prefs.remove(onboardingStepStorageKeyForUser(userId));
      await prefs.remove(creatorFirstItemCreatedStorageKeyForUser(userId));
      await prefs.remove(timelineFirstActionCompletedStorageKeyForUser(userId));
    } on Object {
      // Keep settings actions non-fatal when auth runtime is unavailable.
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
      case 'recent-sign-in-required':
      case 'account-mismatch':
      case 'local-cleanup-failed':
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
  ) {
    return _openExternalWithFallback(
      context: context,
      ref: ref,
      url: AppUrls.deleteAccount,
      fallbackRoute: RoutePaths.deleteAccount,
      failureLabel: 'Account deletion instructions are unavailable.',
    );
  }

  Future<void> _showAccountDeletionUnavailable(
    BuildContext context,
    WidgetRef ref,
  ) {
    return _openExternalWithFallback(
      context: context,
      ref: ref,
      url: AppUrls.deleteAccount,
      fallbackRoute: RoutePaths.deleteAccount,
      failureLabel: 'Account deletion instructions are unavailable.',
    );
  }
}

bool _hasSecureHttpsEndpoint(String value) {
  final Uri? uri = Uri.tryParse(value.trim());
  return uri != null && uri.hasAuthority && uri.scheme == 'https';
}
