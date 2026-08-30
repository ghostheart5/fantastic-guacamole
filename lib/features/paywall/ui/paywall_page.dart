import 'package:fantastic_guacamole/config/app_config.dart';
import 'package:fantastic_guacamole/config/launch_containment.dart';
import 'package:fantastic_guacamole/core/debug/app_analytics.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/debug/runtime_diagnostics.dart';
import 'package:fantastic_guacamole/domain/entities/paywall_entity.dart';
import 'package:fantastic_guacamole/domain/entities/paywall_plan.dart';
import 'package:fantastic_guacamole/domain/entities/subscription_state.dart';
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
}) {
  switch (subscription.status) {
    case 'purchase_pending':
      return 'Purchase pending. Your current access stays unchanged while Google Play completes it.';
    case 'purchase_canceled':
    case 'purchase_cancelled':
      return 'Purchase canceled. Your current access was not changed.';
    case 'verification_failed':
      return 'Purchase verification could not be confirmed. Your current access stays unchanged; use Restore Purchases to retry.';
    case 'acknowledgement_failed':
      return 'Purchase verification succeeded, but final acknowledgement is still pending. Your current access stays unchanged; use Restore Purchases to retry.';
    default:
      if (subscription.isActive) {
        return testingMode
            ? 'Unlocked for testing.'
            : 'Subscription activated.';
      }
      return 'Subscription access is inactive.';
  }
}

String resolvePaywallRestoreResultMessage(
  SubscriptionState subscription, {
  required bool testingMode,
}) {
  switch (subscription.status) {
    case 'purchase_pending':
      return 'Restore pending. Your current access stays unchanged while Google Play completes it.';
    case 'verification_failed':
      return 'Restore verification could not be confirmed. Your current access stays unchanged; retry Restore Purchases.';
    case 'acknowledgement_failed':
      return 'Restore found the purchase, but final acknowledgement is still pending. Your current access stays unchanged; retry Restore Purchases.';
    case 'restore_error':
      return 'Purchase restore failed. Retry.';
    case 'nothing_to_restore':
      return 'No active purchases were found to restore.';
    default:
      if (subscription.isActive) {
        return testingMode
            ? 'Unlocked for testing.'
            : 'Subscription restored and active.';
      }
      return 'No active purchases were found to restore.';
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
        throw StateError('Sign in before starting a subscription.');
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
        _statusMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = 'Subscription activation failed. Retry.';
      });
    }
  }

  Future<void> _restore({bool autoPrompt = false}) async {
    try {
      final String? expectedUserId = (await ref.read(
        authUserProvider.future,
      ))?.id;
      if (expectedUserId == null) {
        throw StateError('Sign in before restoring purchases.');
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
          _statusMessage = error.message;
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        if (!autoPrompt) {
          _statusMessage = 'Purchase restore failed. Retry.';
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
      paidCreditPlansEnabled: LaunchContainment.paidCreditPlansEnabled,
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
                title: 'PLAN & CREDITS',
                subtitle:
                    '${config.title.toUpperCase()} · Subscription status and external-assistant credit allowance.',
                eyebrow: paywallTestingMode
                    ? 'Unlocked for testing'
                    : 'Temporal commerce',
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
                  onRetry: () => _retryFailedProviders(
                    config: configError,
                    subscription: subscriptionError,
                    wallet: walletError,
                  ),
                ),
                const SizedBox(height: 14),
              ],
              _HeroCard(
                title: config.title,
                body: config.body,
                isPremium:
                    isPremium ||
                    paywallTestingMode ||
                    subscription?.isActive == true,
                wallet: wallet,
              ),
              if (prompt != null) ...[
                const SizedBox(height: 14),
                _PromptBanner(prompt: prompt),
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
                        ? 'Unlocked for testing'
                        : 'Subscription active',
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
                                plan.title,
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
                          plan.priceLabel,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        if (plan.aiCreditsIncluded > 0) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Credits after a verified purchase or paid renewal: ${plan.aiCreditsIncluded}',
                            style: const TextStyle(
                              color: AppColors.neonCyan,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        const Text(
                          'Google Play confirms billing frequency and renewal terms before purchase.',
                          style: TextStyle(
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
                                    LaunchContainment.paidCreditPlansEnabled &&
                                        plan.isAvailable &&
                                        !hasActiveSubscription
                                    ? () => _unlock(plan.id)
                                    : null,
                                child: Text(
                                  paywallTestingMode
                                      ? 'Simulate unlock'
                                      : hasActiveSubscription
                                      ? 'Current subscription active'
                                      : 'Choose plan',
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
                      _showAllPlans ? 'Show fewer plans' : 'Show all plans',
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: canRestore ? _restore : null,
                child: const Text('Restore Purchases'),
              ),
              const SizedBox(height: 10),
              Text(
                paywallTestingMode
                    ? 'Testing mode is active; purchases are simulated.'
                    : 'Prices shown above come from Google Play. Google Play confirms billing frequency, renewal terms, and final purchase details before you pay.',
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
  });

  final String title;
  final String body;
  final bool isPremium;
  final AiCreditWallet? wallet;

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
                isPremium ? 'SUBSCRIPTION ACTIVE' : 'CREDIT ALLOWANCE',
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
                      label: 'Credits left',
                      value: '${safeWallet.balance}',
                    ),
                  ),
                  Expanded(
                    child: _CreditStat(
                      label: 'Tier',
                      value: safeWallet.tier.toUpperCase(),
                    ),
                  ),
                  Expanded(
                    child: _CreditStat(
                      label: 'Resets',
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
      return 'Soon';
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
  const _PaywallErrorBanner({required this.onRetry});

  final VoidCallback onRetry;

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
          const Expanded(
            child: Text(
              "Couldn't load the latest plan details. Showing what we have.",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _PromptBanner extends StatelessWidget {
  const _PromptBanner({required this.prompt});

  final PaywallPrompt prompt;

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
            prompt.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            prompt.message,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          if (prompt.remainingCredits != null) ...[
            const SizedBox(height: 6),
            Text(
              'Remaining credits: ${prompt.remainingCredits}',
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
