import 'package:fantastic_guacamole/features/monetization/providers/monetization_feature_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SubscriptionManagementScreen extends ConsumerWidget {
  const SubscriptionManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionAsync = ref.watch(currentSubscriptionProvider);
    final entitlementAsync = ref.watch(premiumEntitlementProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Subscription Management')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          entitlementAsync.when(
            data: (entitlement) => Card(
              child: ListTile(
                title: Text('Plan: ${entitlement.planId}'),
                subtitle: Text('Source: ${entitlement.source}'),
                trailing: Text(entitlement.isActive ? 'ACTIVE' : 'INACTIVE'),
              ),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (Object error, StackTrace stackTrace) => Text(error.toString()),
          ),
          const SizedBox(height: 16),
          subscriptionAsync.when(
            data: (sub) {
              if (sub == null) {
                return const Text('No active subscription record found.');
              }
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Status: ${sub.status}'),
                      Text('Plan: ${sub.planId}'),
                      Text('Product: ${sub.productId ?? 'n/a'}'),
                      Text('Auto-renew: ${sub.autoRenews}'),
                      if (sub.expiresAt != null)
                        Text('Expires: ${sub.expiresAt}'),
                    ],
                  ),
                ),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (Object error, StackTrace stackTrace) => Text(error.toString()),
          ),
        ],
      ),
    );
  }
}
