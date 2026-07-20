import 'package:fantastic_guacamole/core/debug/app_analytics.dart';
import 'package:fantastic_guacamole/features/monetization/data/models/subscription_plan.dart';
import 'package:fantastic_guacamole/features/monetization/data/services/analytics_events.dart';
import 'package:fantastic_guacamole/features/monetization/providers/monetization_feature_providers.dart';
import 'package:fantastic_guacamole/features/monetization/presentation/controllers/paywall_controller.dart';
import 'package:fantastic_guacamole/features/monetization/presentation/widgets/credit_balance_widget.dart';
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
    final AsyncValue<List<SubscriptionPlan>> plansAsync =
        ref.watch(subscriptionPlansProvider);
    final entitlementAsync = ref.watch(premiumEntitlementProvider);
    final walletAsync = ref.watch(aiCreditWalletProvider);
    final wallet = walletAsync.maybeWhen(
      data: (value) => value,
      orElse: () => null,
    );
    final controller = ref.watch(paywallControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Paywall')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          entitlementAsync.when(
            data: (entitlement) => Text(
              entitlement.isPremium && entitlement.isActive
                  ? 'Premium active (${entitlement.planId})'
                  : 'Free plan',
            ),
            loading: () => const LinearProgressIndicator(),
            error: (Object error, StackTrace stackTrace) => Text(error.toString()),
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
                            '${plan.billingPeriod} • ${plan.currencyCode} • credits ${plan.creditsPerPeriod}',
                          ),
                          trailing: controller.isBusy &&
                                  controller.activeProductId == plan.productId
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : FilledButton(
                                  onPressed: () => ref
                                      .read(paywallControllerProvider.notifier)
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
            error: (Object error, StackTrace stackTrace) => Text(error.toString()),
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
                child: const Text('Credit Store'),
              ),
              OutlinedButton(
                onPressed: () => context.push(RoutePaths.creditHistory),
                child: const Text('Credit History'),
              ),
              OutlinedButton(
                onPressed: () => context.push(RoutePaths.subscriptionManagement),
                child: const Text('Manage Subscription'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
