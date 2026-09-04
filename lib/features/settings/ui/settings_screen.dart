import 'dart:async';
import 'dart:convert';

import 'package:fantastic_guacamole/ui/navigation/app_view_navigation.dart';
import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/config/launch_containment.dart';
import 'package:fantastic_guacamole/core/debug/diagnostics_context_service.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/debug/telemetry_consent.dart';
import 'package:fantastic_guacamole/core/errors/public_failure.dart';
import 'package:fantastic_guacamole/dev/test_data_generator.dart';
import 'package:fantastic_guacamole/domain/entities/app_theme_entity.dart';
import 'package:fantastic_guacamole/domain/entities/decision_outcome_entity.dart';
import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/domain/entities/person_context.dart';
import 'package:fantastic_guacamole/domain/learning/learning_ledger.dart';
import 'package:fantastic_guacamole/domain/release/assistant_release_control.dart';
import 'package:fantastic_guacamole/features/permissions/notification_permission_prompt.dart';
import 'package:fantastic_guacamole/features/permissions/voice_permission_prompt.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/providers/account_onboarding_provider.dart';
import 'package:fantastic_guacamole/ui/constants/app_assets.dart';
import 'package:fantastic_guacamole/state/providers/auth_provider.dart';
import 'package:fantastic_guacamole/state/providers/assistant_release_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart'
    as extended_domain;
import 'package:fantastic_guacamole/state/providers/optimization_provider.dart';
import 'package:fantastic_guacamole/state/providers/memories_provider.dart';
import 'package:fantastic_guacamole/state/providers/onboarding_preferences_provider.dart';
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
part 'settings_screen.planning_sections.dart';
part 'settings_screen.person_context.dart';
part 'settings_screen.governance_sections.dart';
part 'settings_screen.data_sections.dart';
part 'settings_screen.widgets.dart';

String accountDeletionOutcomeMessage(
  AccountDeletionResult result, {
  bool isSpanish = false,
}) {
  if (!result.localCleanupCompleted) {
    if (isSpanish) {
      return result.isCompleted
          ? 'La eliminación de la cuenta terminó en el servidor, pero este dispositivo no pudo borrar todos los datos locales de la cuenta.'
          : 'La eliminación de la cuenta comenzó en el servidor, pero este dispositivo no pudo borrar todos los datos locales de la cuenta.';
    }
    return result.isCompleted
        ? 'Account deletion completed on the server, but this device could not clear all local account data.'
        : 'Account deletion started on the server, but this device could not clear all local account data.';
  }
  if (result.isCompleted) {
    return isSpanish
        ? 'La cuenta se eliminó correctamente.'
        : 'Account deletion completed.';
  }
  if (!result.statusTrackingAvailable) {
    return isSpanish
        ? 'La eliminación de la cuenta comenzó. La limpieza del servidor sigue en curso, pero no se pudo guardar el seguimiento del estado. Contacta con soporte si necesitas confirmación.'
        : 'Account deletion started. Server cleanup is still in progress, but status tracking could not be saved. Contact support if you need confirmation.';
  }
  return isSpanish
      ? 'La eliminación de la cuenta comenzó. La limpieza del servidor sigue en curso y se cerró tu sesión.'
      : 'Account deletion started. Server cleanup is still in progress. You have been signed out.';
}

@immutable
final class SettingsSafetyCopy {
  const SettingsSafetyCopy({required this.isSpanish});

  final bool isSpanish;

  static SettingsSafetyCopy of(BuildContext context) => SettingsSafetyCopy(
    isSpanish: ChronoSparkLocalizations.of(context).isSpanish,
  );

  String get clearDeviceTitle => isSpanish
      ? '¿Borrar los datos de este dispositivo?'
      : 'Clear data from this device?';
  String get cloudAccountRemains => isSpanish
      ? 'Tu cuenta de ChronoSpark en la nube y tu suscripción de Google Play seguirán activas.'
      : 'Your ChronoSpark cloud account and Google Play subscription remain active.';
  String get planningRecordsRemoved => isSpanish
      ? 'Los registros de planificación y el historial de Línea de Tiempo se borrarán de este dispositivo.'
      : 'Planning records and Timeline history are removed from this device.';
  String get offlineActionsRemoved => isSpanish
      ? 'Las acciones sin conexión y los recordatorios programados se borrarán.'
      : 'Offline actions and scheduled reminders are removed.';
  String get localIntelligenceRemoved => isSpanish
      ? 'El progreso del perfil y la inteligencia local se borrarán.'
      : 'Profile progress and local intelligence are removed.';
  String get localRemovalDisclosure => isSpanish
      ? 'La eliminación local no se puede deshacer. Esto no elimina la cuenta.'
      : 'Local removal cannot be undone. This is not account deletion.';
  String get keepLocalData =>
      isSpanish ? 'Conservar datos locales' : 'Keep local data';
  String get clearThisDevice =>
      isSpanish ? 'Borrar este dispositivo' : 'Clear this device';
  String get localDataCleared => isSpanish
      ? 'Los datos locales se borraron de este dispositivo.'
      : 'Local data cleared from this device.';
  String get localDataClearFailed => isSpanish
      ? 'No se pudieron borrar los datos locales. Inténtalo de nuevo.'
      : 'Local data could not be cleared. Retry.';
  String get deletePermanentlyTitle => isSpanish
      ? '¿Eliminar la cuenta permanentemente?'
      : 'Delete account permanently?';
  String get deletePermanentlyBody => isSpanish
      ? 'Tu cuenta de ChronoSpark y los datos de planificación sincronizados se eliminarán permanentemente.'
      : 'Your ChronoSpark account and synced planning data will be permanently removed.';
  String get deletedCloudCannotRestore => isSpanish
      ? 'Los datos eliminados de la nube no se pueden restaurar.'
      : 'Deleted cloud data cannot be restored.';
  String get subscriptionNotCanceled => isSpanish
      ? 'Una suscripción activa de Google Play no se cancela automáticamente. Adminístrala por separado en Google Play.'
      : 'An active Google Play subscription is not canceled automatically. Manage it separately in Google Play.';
  String get nothingDeletedYet => isSpanish
      ? 'Todavía no se ha eliminado nada.'
      : 'Nothing has been deleted yet.';
  String get keepMyAccount =>
      isSpanish ? 'Conservar mi cuenta' : 'Keep my account';
  String get continueLabel => isSpanish ? 'Continuar' : 'Continue';
  String verifyWith(String provider) =>
      isSpanish ? 'Verificar con $provider' : 'Verify with $provider';
  String providerDeleteBody(String provider) => isSpanish
      ? 'Esta cuenta usa $provider y no tiene una contraseña de ChronoSpark para introducir aquí. Continúa a la página segura de eliminación de cuenta y sigue las instrucciones para verificar tu identidad.'
      : 'This account uses $provider, so it does not have a ChronoSpark password to enter here. Continue to the secure account-deletion page and follow its identity-verification instructions.';
  String get cancel => isSpanish ? 'Cancelar' : 'Cancel';
  String get continueSecurely =>
      isSpanish ? 'Continuar de forma segura' : 'Continue securely';
  String get hostedDeleteOpenFailed => isSpanish
      ? 'No se pudo abrir la página alojada para eliminar la cuenta.'
      : 'Unable to open the hosted account-deletion page.';
  String get confirmDeleteTitle => isSpanish
      ? 'Confirmar eliminación de cuenta'
      : 'Confirm account deletion';
  String get accountPassword =>
      isSpanish ? 'Contraseña de la cuenta' : 'Account password';
  String get showPassword => isSpanish ? 'Mostrar contraseña' : 'Show password';
  String get hidePassword => isSpanish ? 'Ocultar contraseña' : 'Hide password';
  String get deleteAccount => isSpanish ? 'Eliminar cuenta' : 'Delete Account';
  String get deletingAccount =>
      isSpanish ? 'Eliminando cuenta…' : 'Deleting account...';
  String get deletionFailed => isSpanish
      ? 'La eliminación de la cuenta falló. Inténtalo de nuevo.'
      : 'Account deletion failed. Retry.';
  String get incorrectPassword =>
      isSpanish ? 'La contraseña es incorrecta.' : 'Password is incorrect.';
  String get deletionCouldNotComplete => isSpanish
      ? 'No se pudo completar la eliminación de la cuenta. Inténtalo de nuevo o usa la vía de solicitud de soporte.'
      : 'Account deletion could not be completed. Retry or use the support request path.';
  String get signInExpired => isSpanish
      ? 'La sesión caducó. Inicia sesión de nuevo antes de eliminar la cuenta.'
      : 'Sign-in expired. Sign in again before deleting the account.';
  String get deleteTemplateCopied => isSpanish
      ? 'No se encontró una aplicación de correo. La plantilla para eliminar la cuenta se copió al portapapeles.'
      : 'No email app found. Account deletion email template copied to clipboard.';

  String friendlyDeleteError(String code) => switch (code) {
    'wrong-password' || 'invalid-credential' => incorrectPassword,
    'missing-password' ||
    'missing-email' ||
    'operation-not-supported' ||
    'operation-failed' ||
    'network-request-failed' ||
    'invalid-response' => deletionCouldNotComplete,
    'no-current-user' => signInExpired,
    _ => deletionFailed,
  };
}

@visibleForTesting
String settingsPublicFailureMessage(
  BuildContext context,
  Object error, {
  required String englishFallback,
  required String spanishFallback,
}) {
  final bool isSpanish = ChronoSparkLocalizations.of(context).isSpanish;
  return PublicFailure.from(
    error,
    fallback: isSpanish ? spanishFallback : englishFallback,
    isSpanish: isSpanish,
  ).message;
}

Future<void> restartFirstSetup(BuildContext context, WidgetRef ref) async {
  final String onboardingRoute = ref.read(routeSurfaceProvider).onboarding;
  await ref.read(onboardingPreferencesRepositoryProvider).resetFirstSetup();
  await ref.read(accountOnboardingCompleteProvider.notifier).reset();
  ref.read(onboardingCompleteProvider.notifier).set(false);
  ref.read(onboardingWelcomeCompleteProvider.notifier).set(false);
  if (context.mounted) context.go(onboardingRoute);
}

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
    final bool openContextFromNexus = ref.watch(
      personContextSettingsEntryProvider,
    );
    if (openContextFromNexus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(personContextSettingsEntryProvider.notifier).clear();
      });
    }
    final String? telemetryAccountId = ref
        .watch(authUserProvider)
        .asData
        ?.value
        ?.id;
    final AsyncValue<TelemetryConsent>? telemetryConsentAsync =
        telemetryAccountId == null
        ? null
        : ref.watch(telemetryConsentProvider(telemetryAccountId));
    final TelemetryConsent telemetryConsent =
        telemetryConsentAsync?.asData?.value ?? const TelemetryConsent();

    Future<void> saveTelemetryConsent(TelemetryConsent next) async {
      final String? accountId = telemetryAccountId;
      if (accountId == null) {
        return;
      }
      await ref
          .read(settingsUiActionsProvider)
          .saveTelemetryConsent(accountId: accountId, consent: next);
      ref.invalidate(telemetryConsentProvider(accountId));
    }

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

              if (LaunchContainment.subscriptionsEnabled) ...<Widget>[
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
              ],

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

              _SettingsCategory(
                title: 'Planning & guidance',
                subtitle:
                    'Context, reminders, planning preferences, memory, and tutorials',
                icon: Icons.auto_awesome_rounded,
                accent: AppColors.neonViolet,
                initiallyExpanded: openContextFromNexus,
                child: const Column(
                  children: <Widget>[
                    _PersonContextSection(),
                    SizedBox(height: 10),
                    _ReflectionReminderSection(),
                    SizedBox(height: 10),
                    _ReminderAutomationSection(),
                    SizedBox(height: 10),
                    _PersonalizationSection(),
                    SizedBox(height: 10),
                    _LearningLedgerSection(),
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
                    if (telemetryAccountId != null) ...<Widget>[
                      _Section(
                        label: 'PRIVATE DIAGNOSTICS',
                        accentColor: AppColors.neonCyan,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Text(
                              'Choose whether this account may share anonymous usage or crash diagnostics. Both services remain off in this release until their separate launch gates are approved.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _NeonToggleTile(
                              title: 'Anonymous usage diagnostics',
                              value: telemetryConsent.analytics,
                              onChanged:
                                  telemetryConsentAsync?.isLoading == true
                                  ? null
                                  : (bool value) => unawaited(
                                      saveTelemetryConsent(
                                        telemetryConsent.copyWith(
                                          analytics: value,
                                        ),
                                      ),
                                    ),
                            ),
                            _NeonToggleTile(
                              title: 'Anonymous crash diagnostics',
                              value: telemetryConsent.crashReporting,
                              onChanged:
                                  telemetryConsentAsync?.isLoading == true
                                  ? null
                                  : (bool value) => unawaited(
                                      saveTelemetryConsent(
                                        telemetryConsent.copyWith(
                                          crashReporting: value,
                                        ),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
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
    final SettingsSafetyCopy copy = SettingsSafetyCopy.of(context);
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            icon: const Icon(
              Icons.phonelink_erase_rounded,
              color: AppColors.memoryAmber,
            ),
            title: Text(copy.clearDeviceTitle),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    copy.cloudAccountRemains,
                    style: const TextStyle(
                      color: AppColors.neonCyan,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TemporalStatusRow(
                    icon: Icons.history_rounded,
                    text: copy.planningRecordsRemoved,
                    color: AppColors.memoryAmber,
                  ),
                  const SizedBox(height: 10),
                  TemporalStatusRow(
                    icon: Icons.notifications_off_outlined,
                    text: copy.offlineActionsRemoved,
                    color: AppColors.memoryAmber,
                  ),
                  const SizedBox(height: 10),
                  TemporalStatusRow(
                    icon: Icons.psychology_outlined,
                    text: copy.localIntelligenceRemoved,
                    color: AppColors.memoryAmber,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    copy.localRemovalDisclosure,
                    style: const TextStyle(color: Colors.white70, height: 1.4),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              FilledButton.icon(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                icon: const Icon(Icons.shield_outlined),
                label: Text(copy.keepLocalData),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.memoryAmber,
                ),
                icon: const Icon(Icons.phonelink_erase_rounded),
                label: Text(copy.clearThisDevice),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(copy.localDataCleared)));
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(copy.localDataClearFailed)));
    }
  }

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final SettingsSafetyCopy copy = SettingsSafetyCopy.of(context);
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
              title: Text(copy.deletePermanentlyTitle),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      copy.deletePermanentlyBody,
                      style: const TextStyle(color: Colors.white, height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    TemporalStatusRow(
                      icon: Icons.cloud_off_outlined,
                      text: copy.deletedCloudCannotRestore,
                      color: AppColors.recallRed,
                    ),
                    const SizedBox(height: 10),
                    TemporalStatusRow(
                      icon: Icons.play_arrow_rounded,
                      text: copy.subscriptionNotCanceled,
                      color: AppColors.memoryAmber,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      copy.nothingDeletedYet,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                FilledButton.icon(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  icon: const Icon(Icons.shield_outlined),
                  label: Text(copy.keepMyAccount),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.recallRed,
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(copy.continueLabel),
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
              title: Text(copy.verifyWith(providerLabel)),
              content: Text(copy.providerDeleteBody(providerLabel)),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(copy.cancel),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: Text(copy.continueSecurely),
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
        failureLabel: copy.hostedDeleteOpenFailed,
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
              title: Text(copy.confirmDeleteTitle),
              content: TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: copy.accountPassword,
                  suffixIcon: IconButton(
                    tooltip: obscurePassword
                        ? copy.showPassword
                        : copy.hidePassword,
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
                  child: Text(copy.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(
                    dialogContext,
                  ).pop(passwordController.text.trim()),
                  child: Text(copy.deleteAccount),
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
    ).showSnackBar(SnackBar(content: Text(copy.deletingAccount)));

    try {
      final AccountDeletionResult result = await ref
          .read(authServiceProvider)
          .deleteCurrentAccount(password: secret);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accountDeletionOutcomeMessage(result, isSpanish: copy.isSpanish),
          ),
        ),
      );
      context.go(routes.login);
    } on FirebaseAuthException catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(copy.friendlyDeleteError(error.code))),
      );
    } on Exception {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(copy.deletionFailed)));
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
    unawaited(context.push<void>(fallbackRoute));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(failureLabel)));
  }

  Future<void> _requestAccountDeletionSupport(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final SettingsSafetyCopy copy = SettingsSafetyCopy.of(context);
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
            'To: ${Env.supportEmail}\nSubject: Account deletion request\n\nPlease delete my ChronoSpark account associated with this email.',
      ),
    );
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(copy.deleteTemplateCopied)));
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
