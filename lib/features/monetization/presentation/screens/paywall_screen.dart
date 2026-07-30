import 'package:fantastic_guacamole/config/app_config.dart';
import 'package:fantastic_guacamole/core/debug/app_analytics.dart';
import 'package:fantastic_guacamole/features/monetization/data/models/subscription_plan.dart';
import 'package:fantastic_guacamole/features/monetization/data/services/analytics_events.dart';
import 'package:fantastic_guacamole/features/monetization/providers/monetization_feature_providers.dart';
import 'package:fantastic_guacamole/features/monetization/providers/monetization_providers.dart';
import 'package:fantastic_guacamole/features/monetization/presentation/controllers/paywall_controller.dart';
import 'package:fantastic_guacamole/features/monetization/presentation/widgets/credit_balance_widget.dart';
import 'package:fantastic_guacamole/state/providers/access_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fantastic_guacamole/app/router/route_paths.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  @override
  void initState() {
    super.initState();
    AppAnalytics.track(MonetizationEvents.paywallViewed);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<SubscriptionPlan>> plansAsync = ref.watch(
      subscriptionPlansProvider,
    );
    final entitlementAsync = ref.watch(premiumEntitlementProvider);
    final walletAsync = ref.watch(aiCreditWalletProvider);
    final wallet = walletAsync.maybeWhen(
      data: (value) => value,
      orElse: () => null,
    );
    final controller = ref.watch(paywallControllerProvider);
    final appAccess = ref.watch(appAccessProvider);
    final PaywallPrompt? paywallPrompt = ref.watch(paywallPromptProvider);
    final bool testingUnlocked =
        paywallTestingMode || !appAccess.paywallEnabled;

    return Scaffold(
      appBar: AppBar(title: const Text('Billing Center')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (testingUnlocked)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
              ),
              child: const Text(
                'Testing mode active: premium is unlocked and purchases are disabled.',
                style: TextStyle(color: Colors.amber),
              ),
            ),
          if (testingUnlocked) const SizedBox(height: 12),
          if (paywallPrompt != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withValues(alpha: 0.30)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    paywallPrompt.title,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    paywallPrompt.message,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  if (paywallPrompt.remainingCredits != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Remaining credits: ${paywallPrompt.remainingCredits}',
                        style: const TextStyle(color: Colors.white60),
                      ),
                    ),
                ],
              ),
            ),
          if (paywallPrompt != null) const SizedBox(height: 12),
          entitlementAsync.when(
            data: (entitlement) => Text(
              entitlement.isPremium && entitlement.isActive
                  ? 'Premium active (${entitlement.planId})'
                  : 'Free plan',
            ),
            loading: () => const LinearProgressIndicator(),
            error: (Object error, StackTrace stackTrace) =>
                Text(error.toString()),
          ),
          const SizedBox(height: 12),
          CreditBalanceWidget(wallet: wallet),
          const SizedBox(height: 12),
          plansAsync.when(
            data: (List<SubscriptionPlan> plans) {
              if (plans.isEmpty) {
                return const Text('No subscription plans available right now.');
              }
              return Column(
                children: plans
                    .map(
                      (SubscriptionPlan plan) => Card(
                        child: ListTile(
                          title: Text(plan.name),
                          subtitle: Text(
                            '${plan.billingPeriod} | ${plan.currencyCode} | credits ${plan.creditsPerPeriod}',
                          ),
                          trailing:
                              controller.isBusy &&
                                  controller.activeProductId == plan.productId
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : FilledButton(
                                  onPressed: testingUnlocked
                                      ? null
                                      : () => ref
                                            .read(
                                              paywallControllerProvider
                                                  .notifier,
                                            )
                                            .purchasePlan(plan),
                                  child: const Text('Select'),
                                ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object error, StackTrace stackTrace) =>
                Text(error.toString()),
          ),
          const SizedBox(height: 12),
          if (controller.error != null)
            Text(controller.error!, style: const TextStyle(color: Colors.red)),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => context.push(RoutePaths.creditStore),
                child: const Text('Buy Credits'),
              ),
              OutlinedButton(
                onPressed: () => context.push(RoutePaths.creditHistory),
                child: const Text('Credit History'),
              ),
              OutlinedButton(
                onPressed: () =>
                    context.push(RoutePaths.subscriptionManagement),
                child: const Text('Subscription Details'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
