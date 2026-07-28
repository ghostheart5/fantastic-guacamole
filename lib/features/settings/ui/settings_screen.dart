import 'dart:async';

import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/domain/entities/app_theme_entity.dart';
import 'package:fantastic_guacamole/features/permissions/notification_permission_prompt.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/providers/auth_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart'
    as extended_domain;
import 'package:fantastic_guacamole/state/providers/route_paths_provider.dart';
import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/state/providers/settings_ui_provider.dart';
import 'package:fantastic_guacamole/state/services/auth_gateway_support.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_target_registry.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/constants/app_urls.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

part 'settings_screen.sections.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(extended_domain.extendedDomainBootstrapProvider);
    final int legalPoliciesCount = ref
        .watch(extended_domain.privacyPoliciesProvider)
        .length;
    final routes = ref.watch(routeSurfaceProvider);
    final soundEnabled = ref.watch(soundEnabledProvider);
    final themeAsync = ref.watch(currentThemeProvider);
    final bool isDarkMode = themeAsync.asData?.value.isDark ?? true;
    final access = ref.watch(appAccessProvider);
    final hasMockSession = ref.watch(mockAuthSessionProvider);
    final bool accountDeletionConfigured = _hasSecureHttpsEndpoint(
      Env.accountDeleteEndpoint,
    );
    final bool allowDeletionSupportFallback = !kReleaseMode;

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
                            colors: [AppColors.neonCyan, AppColors.neonViolet],
                          ).createShader(bounds),
                          child: const Text(
                            'SYSTEM CONSOLE',
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
                          'CHRONOSPARK CONTROL CENTER',
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

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
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
                      'SYSTEM STATUS',
                      style: TextStyle(
                        color: AppColors.neonCyan,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'ChronoSpark systems online',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Core controls, account access, and support links are consolidated here.',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              _Section(
                label: 'SYSTEM CORE',
                accentColor: AppColors.neonCyan,
                child: Column(
                  children: [
                    _NeonToggleTile(
                      title: 'Dark Mode',
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
                    ValueListenableBuilder<NotificationPermissionState>(
                      valueListenable: ref.watch(
                        notificationPermissionStateListenableProvider,
                      ),
                      builder: (context, permissionState, _) {
                        final bool? granted = ref
                            .watch(notificationPermissionListenableProvider)
                            .value;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            NotificationPermissionPrompt(
                              permissionGranted: granted,
                              permissionState: permissionState,
                              onRequestPermission: () async {
                                final NotificationPermissionState
                                state = await ref
                                    .read(settingsUiActionsProvider)
                                    .requestNotificationPermissionDetailed();
                                return state ==
                                    NotificationPermissionState.granted;
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
                            if (granted == false)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    context.push(
                                      RoutePaths.notificationPermissionRecovery,
                                    );
                                  },
                                  icon: const Icon(Icons.build_circle_outlined),
                                  label: const Text(
                                    'Open Notification Recovery',
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              _Section(
                label: 'OPERATOR ACCOUNT',
                accentColor: AppColors.neonViolet,
                child: Column(
                  children: [
                    _NeonNavTile(
                      title: 'Subscription & Paywall',
                      subtitle: access.subscriptionStatusDetail,
                      onTap: () => context.push(routes.paywall),
                    ),
                    _NeonNavTile(
                      title: 'Log Out',
                      subtitle: 'End the current session.',
                      onTap: () => unawaited(
                        _signOut(context, ref, hasMockSession: hasMockSession),
                      ),
                    ),
                    if (!hasMockSession)
                      _NeonNavTile(
                        title: 'Delete Account',
                        subtitle: accountDeletionConfigured
                            ? 'Permanent deletion of account and synced data.'
                            : (allowDeletionSupportFallback
                                  ? 'Deletion endpoint unavailable in this build; request deletion via support.'
                                  : 'Deletion endpoint unavailable in this release build.'),
                        onTap: () => unawaited(
                          accountDeletionConfigured
                              ? _confirmDeleteAccount(context, ref)
                              : (allowDeletionSupportFallback
                                    ? _requestAccountDeletionSupport(
                                        context,
                                        ref,
                                      )
                                    : _showAccountDeletionUnavailable(context)),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              _Section(
                label: 'NETWORK & SUPPORT',
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
                  ],
                ),
              ),
            ],
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

  Future<void> _showAccountDeletionUnavailable(BuildContext context) async {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Account deletion is temporarily unavailable in this release build. Contact support@chronospark.app.',
        ),
      ),
    );
  }
}

bool _hasSecureHttpsEndpoint(String value) {
  final Uri? uri = Uri.tryParse(value.trim());
  return uri != null && uri.hasAuthority && uri.scheme == 'https';
}
