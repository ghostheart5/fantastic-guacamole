import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/state/app_state.dart';
import '../../../features/auth/auth_session_controller.dart';
import '../../settings/controllers/settings_controller.dart';
import '../../settings/widgets/subscription_billing_widget.dart';
import '../../../ui/system/glass_panel.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState appState = context.watch<AppState>();
    final SettingsController settingsController = context.watch<SettingsController>();
    final SettingsState settings = settingsController.read();
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _SettingsSection(
          title: 'Interface',
          lines: <String>[
            settings.neonRecall ? 'Theme: Neon Recall' : 'Theme: Dark',
            'Typography scale: ${settings.textScale.toStringAsFixed(2)}x',
            'Motion intensity: standard',
          ],
        ),
        const SizedBox(height: 10),
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Live Theme Controls',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Neon Recall Theme'),
                subtitle: Text(
                  'Switch between classic dark and neon recall visuals.',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.82),
                  ),
                ),
                value: settings.neonRecall,
                onChanged: (bool value) {
                  settingsController.setNeonRecall(value);
                },
              ),
              const SizedBox(height: 4),
              Text(
                'Text Scale: ${settings.textScale.toStringAsFixed(2)}x',
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.82),
                ),
              ),
              Slider(
                value: settings.textScale,
                min: 0.85,
                max: 1.35,
                divisions: 10,
                label: settings.textScale.toStringAsFixed(2),
                onChanged: (double value) {
                  settingsController.setTextScale(value);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const _SettingsSection(
          title: 'Synthetic Intelligence',
          lines: <String>['Energy sensitivity', 'Workload threshold', 'Decision cadence'],
        ),
        const SizedBox(height: 10),
        _SettingsSection(
          title: 'Privacy and Data',
          lines: <String>[
            settings.notifications ? 'Notifications: enabled' : 'Notifications: disabled',
            'Local storage',
            'Access controls',
          ],
        ),
        const SizedBox(height: 10),
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Notifications',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enable In-App Alerts'),
                subtitle: Text(
                  'Show mission and system notifications while you work.',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.82),
                  ),
                ),
                value: settings.notifications,
                onChanged: (bool value) {
                  settingsController.setNotifications(value);
                },
              ),
              const SizedBox(height: 8),
              Text(
                appState.notifications.isEmpty
                    ? 'No recent notifications yet.'
                    : 'Latest: ${appState.notifications.first.message}',
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.82),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Billing and Subscription',
                style: TextStyle(fontWeight: FontWeight.w600),
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
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                appState.isPremium
                    ? 'Premium is active on this account.'
                    : 'Premium is locked. Choose a plan below.',
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.82),
                ),
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
                              Text(product.title, style: textTheme.bodyLarge),
                              Text(
                                product.price,
                                style: textTheme.bodySmall?.copyWith(
                                  color: scheme.secondary.withValues(alpha: 0.9),
                                ),
                              ),
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
                Text(
                  appState.runtimeError!,
                  style: textTheme.bodySmall?.copyWith(color: scheme.error),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Account',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                context.watch<AuthSessionController>().email ?? 'Not signed in',
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.82),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  context.read<AuthSessionController>().signOut();
                },
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
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
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ...lines.map(
            (String line) => Text(
              line,
              style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.82)),
            ),
          ),
        ],
      ),
    );
  }
}
