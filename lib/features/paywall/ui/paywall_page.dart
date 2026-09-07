import 'package:fantastic_guacamole/config/app_config.dart';
import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/core/debug/app_analytics.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/debug/runtime_diagnostics.dart';
import 'package:fantastic_guacamole/domain/entities/paywall_entity.dart';
import 'package:fantastic_guacamole/domain/entities/paywall_plan.dart';
import 'package:fantastic_guacamole/domain/entities/subscription_state.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:fantastic_guacamole/state/models/ai_credit_wallet.dart';
import 'package:fantastic_guacamole/state/providers/access_provider.dart';
import 'package:fantastic_guacamole/state/providers/entitlement_provider.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/paywall_provider.dart';
import 'package:fantastic_guacamole/state/providers/route_paths_provider.dart';
import 'package:fantastic_guacamole/ui/constants/app_assets.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:fantastic_guacamole/ui/system/temporal_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

bool resolvePaywallRestoreAvailability({required bool paidCreditPlansEnabled}) {
  return paidCreditPlansEnabled;
}

String resolvePaywallPurchaseResultMessage(
  SubscriptionState subscription, {
  required bool testingMode,
  ChronoSparkLocalizations localizations = const ChronoSparkLocalizations(
    Locale('en'),
  ),
}) {
  final _PaywallCopy copy = _PaywallCopy(localizations);
  switch (subscription.status) {
    case 'purchase_pending':
      return copy.purchasePending;
    case 'purchase_canceled':
    case 'purchase_cancelled':
      return copy.purchaseCanceled;
    case 'verification_failed':
      return copy.purchaseVerificationFailed;
    case 'acknowledgement_failed':
      return copy.purchaseAcknowledgementFailed;
    default:
      if (subscription.isActive) {
        return testingMode ? copy.unlockedForTestingResult : copy.activated;
      }
      return copy.inactive;
  }
}

String resolvePaywallRestoreResultMessage(
  SubscriptionState subscription, {
  required bool testingMode,
  ChronoSparkLocalizations localizations = const ChronoSparkLocalizations(
    Locale('en'),
  ),
}) {
  final _PaywallCopy copy = _PaywallCopy(localizations);
  switch (subscription.status) {
    case 'purchase_pending':
      return copy.restorePending;
    case 'verification_failed':
      return copy.restoreVerificationFailed;
    case 'acknowledgement_failed':
      return copy.restoreAcknowledgementFailed;
    case 'restore_error':
      return copy.restoreFailed;
    case 'nothing_to_restore':
      return copy.nothingToRestore;
    default:
      if (subscription.isActive) {
        return testingMode
            ? copy.unlockedForTestingResult
            : copy.restoredAndActive;
      }
      return copy.nothingToRestore;
  }
}

class _PaywallCopy {
  const _PaywallCopy(this._localizations);

  final ChronoSparkLocalizations _localizations;

  bool get _isSpanish => _localizations.isSpanish;

  String _select(String english, String spanish) =>
      _isSpanish ? spanish : english;

  String get purchasePending => _select(
    'Purchase pending. Your current access stays unchanged while Google Play completes it.',
    'Compra pendiente. Tu acceso actual no cambia mientras Google Play la completa.',
  );

  String get purchaseCanceled => _select(
    'Purchase canceled. Your current access was not changed.',
    'Compra cancelada. Tu acceso actual no ha cambiado.',
  );

  String get purchaseVerificationFailed => _select(
    'Purchase verification could not be confirmed. Your current access stays unchanged; use Restore Purchases to retry.',
    'No se pudo confirmar la verificación de la compra. Tu acceso actual no cambia; usa Restaurar compras para volver a intentarlo.',
  );

  String get purchaseAcknowledgementFailed => _select(
    'Purchase verification succeeded, but final acknowledgement is still pending. Your current access stays unchanged; use Restore Purchases to retry.',
    'La verificación de la compra se completó, pero la confirmación final aún está pendiente. Tu acceso actual no cambia; usa Restaurar compras para volver a intentarlo.',
  );

  String get unlockedForTestingResult =>
      _select('Unlocked for testing.', 'Desbloqueado para pruebas.');

  String get activated =>
      _select('Subscription activated.', 'Suscripción activada.');

  String get inactive => _select(
    'Subscription access is inactive.',
    'El acceso de la suscripción está inactivo.',
  );

  String get restorePending => _select(
    'Restore pending. Your current access stays unchanged while Google Play completes it.',
    'Restauración pendiente. Tu acceso actual no cambia mientras Google Play la completa.',
  );

  String get restoreVerificationFailed => _select(
    'Restore verification could not be confirmed. Your current access stays unchanged; retry Restore Purchases.',
    'No se pudo confirmar la verificación de la restauración. Tu acceso actual no cambia; vuelve a intentar Restaurar compras.',
  );

  String get restoreAcknowledgementFailed => _select(
    'Restore found the purchase, but final acknowledgement is still pending. Your current access stays unchanged; retry Restore Purchases.',
    'La restauración encontró la compra, pero la confirmación final aún está pendiente. Tu acceso actual no cambia; vuelve a intentar Restaurar compras.',
  );

  String get restoreFailed => _select(
    'Purchase restore failed. Retry.',
    'No se pudo restaurar la compra. Vuelve a intentarlo.',
  );

  String get nothingToRestore => _select(
    'No active purchases were found to restore.',
    'No se encontraron compras activas para restaurar.',
  );

  String get restoredAndActive => _select(
    'Subscription restored and active.',
    'Suscripción restaurada y activa.',
  );

  String get signInBeforeSubscription => _select(
    'Sign in before starting a subscription.',
    'Inicia sesión antes de comenzar una suscripción.',
  );

  String get signInBeforeRestore => _select(
    'Sign in before restoring purchases.',
    'Inicia sesión antes de restaurar compras.',
  );

  String get subscriptionActivationFailed => _select(
    'Subscription activation failed. Retry.',
    'No se pudo activar la suscripción. Vuelve a intentarlo.',
  );

  String get plansAndCredits => _select('PLAN & CREDITS', 'PLANES Y CRÉDITOS');

  String subscriptionSubtitle(String localizedTitle) => _select(
    '${localizedTitle.toUpperCase()} · Subscription status and external-assistant credit allowance.',
    '${localizedTitle.toUpperCase()} · Estado de la suscripción y saldo de créditos del asistente externo.',
  );

  String get unlockedForTesting =>
      _select('Unlocked for testing', 'Desbloqueado para pruebas');

  String get temporalCommerce =>
      _select('Temporal commerce', 'Comercio temporal');

  String get subscriptionActive =>
      _select('Subscription active', 'Suscripción activa');

  String creditsAfterVerification(int credits) => _select(
    'Credits after a verified purchase or paid renewal: $credits',
    'Créditos tras una compra verificada o una renovación pagada: $credits',
  );

  String get billingTerms => _select(
    'Google Play confirms billing frequency and renewal terms before purchase.',
    'Google Play confirma la frecuencia de facturación y los términos de renovación antes de la compra.',
  );

  String get simulateUnlock => _select('Simulate unlock', 'Simular desbloqueo');

  String get currentSubscriptionActive =>
      _select('Current subscription active', 'Suscripción actual activa');

  String get choosePlan => _select('Choose plan', 'Elegir plan');

  String get showFewerPlans =>
      _select('Show fewer plans', 'Mostrar menos planes');

  String get showAllPlans =>
      _select('Show all plans', 'Mostrar todos los planes');

  String get restorePurchases =>
      _select('Restore Purchases', 'Restaurar compras');

  String get testingModeNotice => _select(
    'Testing mode is active; purchases are simulated.',
    'El modo de prueba está activo; las compras son simuladas.',
  );

  String get googlePlayPriceNotice => _select(
    'Prices shown above come from Google Play. Google Play confirms billing frequency, renewal terms, and final purchase details before you pay.',
    'Los precios mostrados arriba provienen de Google Play. Google Play confirma la frecuencia de facturación, los términos de renovación y los detalles finales de la compra antes de que pagues.',
  );

  String get subscriptionActiveLabel =>
      _select('SUBSCRIPTION ACTIVE', 'SUSCRIPCIÓN ACTIVA');

  String get creditAllowanceLabel =>
      _select('CREDIT ALLOWANCE', 'SALDO DE CRÉDITOS');

  String get creditsLeft => _select('Credits left', 'Créditos disponibles');

  String get tier => _select('Tier', 'Nivel');

  String get resets => _select('Resets', 'Se renueva');

  String get soon => _select('Soon', 'Pronto');

  String get loadError => _select(
    "Couldn't load the latest plan details. Showing what we have.",
    'No se pudieron cargar los datos más recientes de los planes. Mostramos la información disponible.',
  );

  String get retry => _select('Retry', 'Reintentar');

  String remainingCredits(int credits) =>
      _select('Remaining credits: $credits', 'Créditos restantes: $credits');

  String configTitle(String title) {
    if (!_isSpanish) return title;
    return switch (title) {
      'External-assistant credit plans' =>
        'Planes de créditos del asistente externo',
      'Unlocked for testing' => 'Desbloqueado para pruebas',
      'Billing unavailable' => 'Facturación no disponible',
      'Plans unavailable' => 'Planes no disponibles',
      _ => title,
    };
  }

  String configBody(String body) {
    if (!_isSpanish) return body;
    return switch (body) {
      'Choose a plan. Google Play provides the displayed price and confirms billing frequency and renewal terms before purchase. Credits are granted only after a verified purchase or paid renewal.' =>
        'Elige un plan. Google Play proporciona el precio mostrado y confirma la frecuencia de facturación y los términos de renovación antes de la compra. Los créditos se conceden solo después de una compra verificada o una renovación pagada.',
      'Google Play provides price, billing frequency, and renewal terms before purchase.' =>
        'Google Play proporciona el precio, la frecuencia de facturación y los términos de renovación antes de la compra.',
      'Subscription checks are bypassed in this testing mode.' =>
        'Las comprobaciones de suscripción se omiten en este modo de prueba.',
      'Premium gates are bypassed in this build.' =>
        'Las restricciones Premium se omiten en esta versión.',
      'Purchases are unavailable on this platform.' =>
        'Las compras no están disponibles en esta plataforma.',
      'Subscriptions are disabled while launch-readiness work is completed.' =>
        'Las suscripciones están desactivadas mientras se completa la preparación para el lanzamiento.',
      'Choose a plan to increase the monthly external-assistant credit allowance.' =>
        'Elige un plan para aumentar el saldo mensual de créditos del asistente externo.',
      'Purchases are temporarily unavailable while billing verification is being finalized.' =>
        'Las compras no están disponibles temporalmente mientras finaliza la verificación de la facturación.',
      _ => body,
    };
  }

  String planTitle(PaywallPlan plan) {
    if (!_isSpanish) return plan.title;
    return switch (plan.title) {
      'Monthly' => 'Mensual',
      'Monthly plan' => 'Plan mensual',
      'Annual' => 'Anual',
      'Annual plan' => 'Plan anual',
      _ => plan.title,
    };
  }

  String priceLabel(String label) {
    if (!_isSpanish || label != 'Price unavailable') return label;
    return 'Precio no disponible';
  }

  String walletTier(String value) {
    if (!_isSpanish) return value.toUpperCase();
    return switch (value.toLowerCase()) {
      'free' => 'GRATUITO',
      'premium' => 'PREMIUM',
      'premium_monthly' => 'PREMIUM MENSUAL',
      'unavailable' => 'NO DISPONIBLE',
      _ => value.toUpperCase(),
    };
  }

  String promptTitle(PaywallPrompt prompt) {
    if (!_isSpanish) return prompt.title;
    return switch (prompt.trigger) {
      'ai_credit_limit' || 'ai_limit' => 'Créditos de IA agotados',
      'ai_credit_low' => 'Quedan pocos créditos de IA',
      _ => prompt.title,
    };
  }

  String promptMessage(PaywallPrompt prompt) {
    if (!_isSpanish) return prompt.message;
    return switch (prompt.trigger) {
      'ai_credit_limit' || 'ai_limit' =>
        'Los créditos del asistente externo se han agotado. ChronoSpark continuará con la orientación en el dispositivo.',
      'ai_credit_low' =>
        'Te quedan ${prompt.remainingCredits ?? 0} créditos del asistente externo.',
      _ => prompt.message,
    };
  }

  String purchaseError(String message) {
    if (message.startsWith('Product ') &&
        message.endsWith(' not found in Google Play.')) {
      return _select(
        'That plan could not be found in Google Play. Retry after refreshing plan details.',
        'No se pudo encontrar ese plan en Google Play. Vuelve a intentarlo después de actualizar los datos del plan.',
      );
    }
    return switch (message) {
      'Sign in before starting a subscription.' => signInBeforeSubscription,
      'Purchases are temporarily unavailable. Please update and try again soon.' =>
        _select(
          'Purchases are temporarily unavailable. Please update and try again soon.',
          'Las compras no están disponibles temporalmente. Actualiza la aplicación y vuelve a intentarlo pronto.',
        ),
      'Your current subscription is already active. Manage plan changes in Google Play.' =>
        _select(
          'Your current subscription is already active. Manage plan changes in Google Play.',
          'Tu suscripción actual ya está activa. Administra los cambios de plan en Google Play.',
        ),
      'A pending Google Play purchase belongs to another signed-in account.' =>
        _select(
          'A pending Google Play purchase belongs to another signed-in account.',
          'Hay una compra pendiente de Google Play que pertenece a otra cuenta con sesión iniciada.',
        ),
      'The signed-in account changed during billing.' => _select(
        'The signed-in account changed during billing. Retry with the intended account.',
        'La cuenta con sesión iniciada cambió durante la facturación. Vuelve a intentarlo con la cuenta correcta.',
      ),
      'Google Play could not start the purchase.' => _select(
        'Google Play could not start the purchase. Retry.',
        'Google Play no pudo iniciar la compra. Vuelve a intentarlo.',
      ),
      'Purchases are unavailable on this platform.' => _select(
        'Purchases are unavailable on this platform.',
        'Las compras no están disponibles en esta plataforma.',
      ),
      'Sign in before Google Play purchase verification can continue.' => _select(
        'Sign in before Google Play purchase verification can continue.',
        'Inicia sesión para que pueda continuar la verificación de la compra de Google Play.',
      ),
      'This Google Play purchase belongs to another signed-in account.' =>
        _select(
          'This Google Play purchase belongs to another signed-in account.',
          'Esta compra de Google Play pertenece a otra cuenta con sesión iniciada.',
        ),
      'The signed-in account changed during purchase acknowledgement.' ||
      'The signed-in account changed during purchase verification.' => _select(
        'The signed-in account changed while the purchase was being confirmed. Retry with the intended account.',
        'La cuenta con sesión iniciada cambió mientras se confirmaba la compra. Vuelve a intentarlo con la cuenta correcta.',
      ),
      'Purchase failed.' => _select(
        'Purchase failed. Retry.',
        'No se pudo completar la compra. Vuelve a intentarlo.',
      ),
      _ => subscriptionActivationFailed,
    };
  }

  String restoreError(String message) {
    return switch (message) {
      'Sign in before restoring purchases.' => signInBeforeRestore,
      'Restore is temporarily unavailable. Please update and try again soon.' =>
        _select(
          'Restore is temporarily unavailable. Please update and try again soon.',
          'La restauración no está disponible temporalmente. Actualiza la aplicación y vuelve a intentarlo pronto.',
        ),
      'The signed-in account changed during purchase restore. Retry.' ||
      'The signed-in account changed during purchase restore.' => _select(
        'The signed-in account changed during purchase restore. Retry with the intended account.',
        'La cuenta con sesión iniciada cambió durante la restauración. Vuelve a intentarlo con la cuenta correcta.',
      ),
      'Sign in before Google Play purchase verification can continue.' => _select(
        'Sign in before Google Play purchase verification can continue.',
        'Inicia sesión para que pueda continuar la verificación de la compra de Google Play.',
      ),
      'This Google Play purchase belongs to another signed-in account.' =>
        _select(
          'This Google Play purchase belongs to another signed-in account.',
          'Esta compra de Google Play pertenece a otra cuenta con sesión iniciada.',
        ),
      'The signed-in account changed during purchase acknowledgement.' ||
      'The signed-in account changed during purchase verification.' => _select(
        'The signed-in account changed while the restored purchase was being confirmed. Retry with the intended account.',
        'La cuenta con sesión iniciada cambió mientras se confirmaba la compra restaurada. Vuelve a intentarlo con la cuenta correcta.',
      ),
      _ => restoreFailed,
    };
  }
}

class PaywallPage extends ConsumerStatefulWidget {
  const PaywallPage({super.key});

  @override
  ConsumerState<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends ConsumerState<PaywallPage> {
  String? _statusMessage;
  bool _showAllPlans = false;

  @override
  void initState() {
    super.initState();
    AppAnalytics.track(
      'paywall_viewed',
      params: <String, Object?>{'testing_mode': paywallTestingMode},
    );
  }

  Future<void> _unlock(String planId) async {
    try {
      final String? expectedUserId = (await ref.read(
        authUserProvider.future,
      ))?.id;
      if (expectedUserId == null) {
        if (!mounted) {
          return;
        }
        setState(() {
          _statusMessage = _PaywallCopy(
            ChronoSparkLocalizations.of(context),
          ).signInBeforeSubscription;
        });
        return;
      }
      final SubscriptionState subscription = await ref
          .read(paywallActionsProvider)
          .startSubscription(planId);
      if (subscription.isActive) {
        await ref
            .read(entitlementProvider.notifier)
            .applyPurchaseResult(subscription, expectedUserId: expectedUserId);
      } else {
        ref.invalidate(entitlementProvider);
      }
      ref.invalidate(paywallSubscriptionProvider);
      ref.invalidate(aiCreditWalletProvider);
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = resolvePaywallPurchaseResultMessage(
          subscription,
          testingMode: paywallTestingMode,
          localizations: ChronoSparkLocalizations.of(context),
        );
      });
      if (paywallTestingMode) {
        Logger.log('Paywall', 'Unlocked for testing.');
      }
      AppAnalytics.track(
        'paywall_purchase_result',
        params: <String, Object?>{
          'plan_id': planId,
          'testing_mode': paywallTestingMode,
          'status': subscription.status,
          'is_active': subscription.isActive,
        },
      );
      if (subscription.isActive) {
        AppAnalytics.track(
          'paywall_unlock',
          params: <String, Object?>{
            'plan_id': planId,
            'testing_mode': paywallTestingMode,
          },
        );
        AppAnalytics.track(
          'subscription_purchased',
          params: <String, Object?>{
            'plan_id': planId,
            'testing_mode': paywallTestingMode,
          },
        );
      }
    } on StateError catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = _PaywallCopy(
          ChronoSparkLocalizations.of(context),
        ).purchaseError(error.message.toString());
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = _PaywallCopy(
          ChronoSparkLocalizations.of(context),
        ).subscriptionActivationFailed;
      });
    }
  }

  Future<void> _restore({bool autoPrompt = false}) async {
    try {
      final String? expectedUserId = (await ref.read(
        authUserProvider.future,
      ))?.id;
      if (expectedUserId == null) {
        if (!mounted || autoPrompt) {
          return;
        }
        setState(() {
          _statusMessage = _PaywallCopy(
            ChronoSparkLocalizations.of(context),
          ).signInBeforeRestore;
        });
        return;
      }
      final SubscriptionState subscription = await ref
          .read(paywallActionsProvider)
          .restorePurchases();
      if (subscription.isActive) {
        await ref
            .read(entitlementProvider.notifier)
            .applyPurchaseResult(subscription, expectedUserId: expectedUserId);
      } else {
        ref.invalidate(entitlementProvider);
      }
      ref.invalidate(paywallSubscriptionProvider);
      ref.invalidate(aiCreditWalletProvider);
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = resolvePaywallRestoreResultMessage(
          subscription,
          testingMode: paywallTestingMode,
          localizations: ChronoSparkLocalizations.of(context),
        );
      });
      AppAnalytics.track(
        autoPrompt ? 'paywall_auto_restore' : 'paywall_restore',
        params: <String, Object?>{
          'testing_mode': paywallTestingMode,
          'restored_active': subscription.isActive,
        },
      );
    } on StateError catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        if (!autoPrompt) {
          _statusMessage = _PaywallCopy(
            ChronoSparkLocalizations.of(context),
          ).restoreError(error.message.toString());
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        if (!autoPrompt) {
          _statusMessage = _PaywallCopy(
            ChronoSparkLocalizations.of(context),
          ).restoreFailed;
        }
      });
    }
  }

  void _logProviderError<T>(
    String providerName,
    AsyncValue<T>? previous,
    AsyncValue<T> next,
  ) {
    if (next.hasError && !(previous?.hasError ?? false)) {
      Logger.error('Paywall: $providerName failed to load.', next.error);
      RuntimeDiagnostics.recordState(
        'paywall.provider_error',
        message: providerName,
        data: <String, Object?>{'error': next.error.toString()},
      );
    }
  }

  void _retryFailedProviders({
    required bool config,
    required bool subscription,
    required bool wallet,
  }) {
    if (config) ref.invalidate(paywallConfigProvider);
    if (subscription) ref.invalidate(paywallSubscriptionProvider);
    if (wallet) ref.invalidate(aiCreditWalletProvider);
  }

  @override
  Widget build(BuildContext context) {
    final _PaywallCopy copy = _PaywallCopy(
      ChronoSparkLocalizations.of(context),
    );
    final routes = ref.watch(routeSurfaceProvider);
    final AsyncValue<PaywallEntity> configAsync = ref.watch(
      paywallConfigProvider,
    );
    final AsyncValue<SubscriptionState> subscriptionAsync = ref.watch(
      paywallSubscriptionProvider,
    );
    final AsyncValue<AiCreditWallet> walletAsync = ref.watch(
      aiCreditWalletProvider,
    );
    ref.listen<AsyncValue<PaywallEntity>>(
      paywallConfigProvider,
      (previous, next) =>
          _logProviderError('paywallConfigProvider', previous, next),
    );
    ref.listen<AsyncValue<SubscriptionState>>(
      paywallSubscriptionProvider,
      (previous, next) =>
          _logProviderError('paywallSubscriptionProvider', previous, next),
    );
    ref.listen<AsyncValue<AiCreditWallet>>(
      aiCreditWalletProvider,
      (previous, next) =>
          _logProviderError('aiCreditWalletProvider', previous, next),
    );
    final PaywallPrompt? prompt = ref.watch(paywallPromptProvider);
    final bool isPremium = ref.watch(appAccessProvider).hasPremiumAccess;
    final List<PaywallPlan> prioritizedPlans = _prioritizePlans(
      configAsync.asData?.value.plans ?? const <PaywallPlan>[],
    );

    if (configAsync.isLoading ||
        subscriptionAsync.isLoading ||
        walletAsync.isLoading) {
      return const AnimatedSystemBackground(
        backgroundAssetPath: AppAssets.bgSettings,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Center(
              child: CircularProgressIndicator(
                color: AppColors.neonCyan,
                strokeWidth: 2,
              ),
            ),
          ),
        ),
      );
    }

    final PaywallEntity config =
        configAsync.asData?.value ??
        const PaywallEntity(
          featureId: 'premium',
          title: 'External-assistant credit plans',
          body:
              'Choose a plan. Google Play provides the displayed price and confirms billing frequency and renewal terms before purchase. Credits are granted only after a verified purchase or paid renewal.',
          plans: <PaywallPlan>[],
          isUnlocked: false,
        );
    final SubscriptionState? subscription = subscriptionAsync.asData?.value;
    final AiCreditWallet? wallet = walletAsync.asData?.value;
    final bool configError = configAsync.hasError;
    final bool subscriptionError = subscriptionAsync.hasError;
    final bool walletError = walletAsync.hasError;
    final bool anyError = configError || subscriptionError || walletError;
    final bool hasActiveSubscription = subscription?.isActive == true;
    final bool canRestore = resolvePaywallRestoreAvailability(
      paidCreditPlansEnabled: Env.paidCreditPlansEnabled,
    );
    final String localizedConfigTitle = copy.configTitle(config.title);

    return AnimatedSystemBackground(
      backgroundAssetPath: AppAssets.bgSettingsControlPlane,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TemporalScreenHeader(
                title: copy.plansAndCredits,
                subtitle: copy.subscriptionSubtitle(localizedConfigTitle),
                eyebrow: paywallTestingMode
                    ? copy.unlockedForTesting
                    : copy.temporalCommerce,
                onBack: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                    return;
                  }
                  context.go(routes.settings);
                },
              ),
              const SizedBox(height: 18),
              if (anyError) ...[
                _PaywallErrorBanner(
                  copy: copy,
                  onRetry: () => _retryFailedProviders(
                    config: configError,
                    subscription: subscriptionError,
                    wallet: walletError,
                  ),
                ),
                const SizedBox(height: 14),
              ],
              _HeroCard(
                title: localizedConfigTitle,
                body: copy.configBody(config.body),
                isPremium:
                    isPremium ||
                    paywallTestingMode ||
                    subscription?.isActive == true,
                wallet: wallet,
                copy: copy,
              ),
              if (prompt != null) ...[
                const SizedBox(height: 14),
                _PromptBanner(prompt: prompt, copy: copy),
              ],
              if (_statusMessage != null) ...[
                const SizedBox(height: 14),
                Text(
                  _statusMessage ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
              const SizedBox(height: 18),
              if (paywallTestingMode || subscription?.isActive == true) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.neonCyan.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.neonCyan.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    paywallTestingMode
                        ? copy.unlockedForTesting
                        : copy.subscriptionActive,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.neonCyan,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              ...(_showAllPlans ? config.plans : prioritizedPlans).map(
                (PaywallPlan plan) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF050D1A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: plan.isFeatured
                            ? AppColors.neonViolet.withValues(alpha: 0.35)
                            : Colors.white10,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                copy.planTitle(plan),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          copy.priceLabel(plan.priceLabel),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        if (plan.aiCreditsIncluded > 0) ...[
                          const SizedBox(height: 6),
                          Text(
                            copy.creditsAfterVerification(
                              plan.aiCreditsIncluded,
                            ),
                            style: const TextStyle(
                              color: AppColors.neonCyan,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          copy.billingTerms,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed:
                                    Env.paidCreditPlansEnabled &&
                                        plan.isAvailable &&
                                        !hasActiveSubscription
                                    ? () => _unlock(plan.id)
                                    : null,
                                child: Text(
                                  paywallTestingMode
                                      ? copy.simulateUnlock
                                      : hasActiveSubscription
                                      ? copy.currentSubscriptionActive
                                      : copy.choosePlan,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (config.plans.length > prioritizedPlans.length)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _showAllPlans = !_showAllPlans;
                      });
                    },
                    icon: Icon(
                      _showAllPlans ? Icons.expand_less : Icons.expand_more,
                    ),
                    label: Text(
                      _showAllPlans ? copy.showFewerPlans : copy.showAllPlans,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: canRestore ? _restore : null,
                child: Text(copy.restorePurchases),
              ),
              const SizedBox(height: 10),
              Text(
                paywallTestingMode
                    ? copy.testingModeNotice
                    : copy.googlePlayPriceNotice,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<PaywallPlan> _prioritizePlans(List<PaywallPlan> plans) {
    if (plans.length <= 2) {
      return plans;
    }
    final List<PaywallPlan> featured = plans
        .where((p) => p.isFeatured)
        .toList(growable: false);
    if (featured.isNotEmpty) {
      final PaywallPlan firstFeatured = featured.first;
      final PaywallPlan firstOther = plans.firstWhere(
        (p) => p.id != firstFeatured.id,
      );
      return <PaywallPlan>[firstFeatured, firstOther];
    }
    return plans.take(2).toList(growable: false);
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.title,
    required this.body,
    required this.isPremium,
    required this.wallet,
    required this.copy,
  });

  final String title;
  final String body;
  final bool isPremium;
  final AiCreditWallet? wallet;
  final _PaywallCopy copy;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF050D1A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isPremium
              ? AppColors.neonCyan.withValues(alpha: 0.3)
              : AppColors.neonViolet.withValues(alpha: 0.24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: isPremium ? AppColors.neonCyan : AppColors.neonViolet,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isPremium
                    ? copy.subscriptionActiveLabel
                    : copy.creditAllowanceLabel,
                style: TextStyle(
                  color: isPremium ? AppColors.neonCyan : AppColors.neonViolet,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          if (wallet case final AiCreditWallet safeWallet) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _CreditStat(
                      label: copy.creditsLeft,
                      value: '${safeWallet.balance}',
                    ),
                  ),
                  Expanded(
                    child: _CreditStat(
                      label: copy.tier,
                      value: copy.walletTier(safeWallet.tier),
                    ),
                  ),
                  Expanded(
                    child: _CreditStat(
                      label: copy.resets,
                      value: _formatReset(safeWallet.resetAt),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatReset(DateTime resetAt) {
    final Duration remaining = resetAt.difference(DateTime.now());
    if (remaining.inHours <= 0) {
      return copy.soon;
    }
    if (remaining.inDays > 0) {
      return '${remaining.inDays}d';
    }
    return '${remaining.inHours}h';
  }
}

class _CreditStat extends StatelessWidget {
  const _CreditStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 9,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PaywallErrorBanner extends StatelessWidget {
  const _PaywallErrorBanner({required this.onRetry, required this.copy});

  final VoidCallback onRetry;
  final _PaywallCopy copy;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.recallRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.recallRed.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.recallRed, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              copy.loadError,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: onRetry, child: Text(copy.retry)),
        ],
      ),
    );
  }
}

class _PromptBanner extends StatelessWidget {
  const _PromptBanner({required this.prompt, required this.copy});

  final PaywallPrompt prompt;
  final _PaywallCopy copy;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.neonViolet.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.neonViolet.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            copy.promptTitle(prompt),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            copy.promptMessage(prompt),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          if (prompt.remainingCredits != null) ...[
            const SizedBox(height: 6),
            Text(
              copy.remainingCredits(prompt.remainingCredits ?? 0),
              style: const TextStyle(
                color: AppColors.neonCyan,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
