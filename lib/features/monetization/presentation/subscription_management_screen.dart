import 'package:fantastic_guacamole/core/debug/app_analytics.dart';
import 'package:fantastic_guacamole/features/monetization/models/entitlement_event.dart';
import 'package:fantastic_guacamole/features/monetization/providers/monetization_providers.dart';
import 'package:fantastic_guacamole/ui/constants/app_urls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class SubscriptionManagementScreen extends ConsumerWidget {
  const SubscriptionManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionAsync = ref.watch(subscriptionProvider);
    final eventsAsync = ref.watch(entitlementEventsProvider);
    final purchaseState = ref.watch(purchaseProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Subscription Management')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          subscriptionAsync.when(
            loading: () => const CircularProgressIndicator(),
            error: (Object error, StackTrace stackTrace) => Text(error.toString()),
            data: (status) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Plan: ${status.planId}'),
                    Text('Status: ${status.status}'),
                    if (status.expiresAt != null)
                      Text('Renews/ends: ${status.expiresAt!.toLocal()}'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton(
                          onPressed: purchaseState.isBusy
                              ? null
                              : () => ref.read(purchaseProvider.notifier).restorePurchases(),
                          child: const Text('Restore Purchases'),
                        ),
                        OutlinedButton(
                          onPressed: () async {
                            AppAnalytics.track('subscription_cancelled');
                            await launchUrl(Uri.parse(AppUrls.googlePlay));
                          },
                          child: const Text('Manage in Google Play'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Entitlement Timeline',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          eventsAsync.when(
            loading: () => const CircularProgressIndicator(),
            error: (Object error, StackTrace stackTrace) => Text(error.toString()),
            data: (List<EntitlementEvent> events) {
              if (events.isEmpty) {
                return const Text('No entitlement events recorded yet.');
              }
              return Column(
                children: events
                    .map(
                      (EntitlementEvent event) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(event.eventType),
                        subtitle: Text(
                          '${event.planId ?? 'n/a'} • ${event.createdAt.toLocal()}',
                        ),
                        trailing: Text(event.isActive ? 'ACTIVE' : 'INACTIVE'),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }
}