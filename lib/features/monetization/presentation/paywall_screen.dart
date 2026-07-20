import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/core/debug/app_analytics.dart';
import 'package:fantastic_guacamole/features/monetization/domain/paywall_content.dart';
import 'package:fantastic_guacamole/features/monetization/providers/monetization_providers.dart';
import 'package:fantastic_guacamole/features/monetization/widgets/ai_credit_balance_card.dart';
import 'package:fantastic_guacamole/features/monetization/widgets/plan_card.dart';
import 'package:fantastic_guacamole/features/monetization/widgets/premium_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  @override
  void initState() {
    super.initState();
    AppAnalytics.track('subscription_viewed');
    AppAnalytics.track('credit_pack_viewed');
  }

  @override
  Widget build(BuildContext context) {
    final paywallAsync = ref.watch(paywallProvider);
    final purchaseState = ref.watch(purchaseProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Monetization')),
      body: paywallAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) => Center(
          child: Text(error.toString()),
        ),
        data: (PaywallContent content) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            PremiumBadge(active: content.status.isPremium && content.status.isActive),
            const SizedBox(height: 16),
            Text(
              content.title,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(content.body),
            const SizedBox(height: 18),
            AiCreditBalanceCard(wallet: content.wallet),
            const SizedBox(height: 18),
            ...content.plans.map(
              (plan) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: PlanCard(
                  plan: plan,
                  currentStatus: content.status,
                  busy: purchaseState.isBusy && purchaseState.activeProductId == plan.productId,
                  onPressed: () => ref.read(purchaseProvider.notifier).purchasePlan(plan.id),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton(
                  onPressed: () => context.push(RoutePaths.planComparison),
                  child: const Text('Compare Plans'),
                ),
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
            if (purchaseState.message != null) ...[
              const SizedBox(height: 16),
              Text(
                purchaseState.message!,
                style: TextStyle(
                  color: purchaseState.lastResult?.success == true
                      ? Colors.green
                      : Colors.orange,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}