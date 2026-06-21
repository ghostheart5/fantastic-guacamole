import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/state/app_state.dart';
import '../../settings/widgets/subscription_billing_widget.dart';
import '../../../ui/system/glass_panel.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState appState = context.watch<AppState>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const _SettingsSection(
          title: 'Interface',
          lines: <String>['Theme accents', 'Typography scale', 'Motion intensity'],
        ),
        const SizedBox(height: 10),
        const _SettingsSection(
          title: 'Synthetic Intelligence',
          lines: <String>['Energy sensitivity', 'Workload threshold', 'Decision cadence'],
        ),
        const SizedBox(height: 10),
        const _SettingsSection(
          title: 'Privacy and Data',
          lines: <String>['Local storage', 'Export logs', 'Access controls'],
        ),
        const SizedBox(height: 10),
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Billing and Subscription',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              const SubscriptionBillingWidget(),
            ],
          ),
        ),
        const SizedBox(height: 10),
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Paywall and Access',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                appState.hasPremiumAccess
                    ? 'Premium is active on this account.'
                    : 'Premium is locked. Choose a plan below.',
                style: const TextStyle(color: Color(0xFFD8D0E6)),
              ),
              const SizedBox(height: 10),
              if (appState.paywallProducts.isEmpty)
                OutlinedButton.icon(
                  onPressed: () {
                    appState.refreshPaywallProducts();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Load Plans'),
                )
              else
                ...appState.paywallProducts.map(
                  (final product) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(product.title, style: const TextStyle(color: Colors.white)),
                              Text(product.price, style: const TextStyle(color: Color(0xFFBFAED9))),
                            ],
                          ),
                        ),
                        FilledButton(
                          onPressed: () {
                            appState.purchase(product.id);
                          },
                          child: const Text('Buy'),
                        ),
                      ],
                    ),
                  ),
                ),
              Wrap(
                spacing: 8,
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: () {
                      appState.restorePurchases();
                    },
                    icon: const Icon(Icons.lock_open),
                    label: const Text('Restore Purchases'),
                  ),
                ],
              ),
              if ((appState.runtimeError ?? '').isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Text(appState.runtimeError!, style: const TextStyle(color: Color(0xFFFF9AB9))),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ...lines.map(
            (String line) => Text(line, style: const TextStyle(color: Color(0xFFD8D0E6))),
          ),
        ],
      ),
    );
  }
}
