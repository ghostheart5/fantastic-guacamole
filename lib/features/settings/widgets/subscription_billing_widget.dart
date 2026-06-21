import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/state/app_state.dart';
import '../../../core/system/subscription_model.dart';

class SubscriptionBillingWidget extends StatefulWidget {
  const SubscriptionBillingWidget({super.key});

  @override
  State<SubscriptionBillingWidget> createState() => _SubscriptionBillingWidgetState();
}

class _SubscriptionBillingWidgetState extends State<SubscriptionBillingWidget> {
  BillingCycle _cycle = BillingCycle.monthly;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final AppState appState = context.watch<AppState>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _card(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Current Plan: ${appState.currentPlan.displayName}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                appState.isPremium
                    ? appState.getNextBillingDateFormatted()
                    : 'Base includes limited trials for premium modules.',
                style: const TextStyle(color: Color(0xFFD8D0E6)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _card(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Billing Cycle',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              SegmentedButton<BillingCycle>(
                showSelectedIcon: false,
                segments: const <ButtonSegment<BillingCycle>>[
                  ButtonSegment<BillingCycle>(value: BillingCycle.monthly, label: Text('Monthly')),
                  ButtonSegment<BillingCycle>(value: BillingCycle.yearly, label: Text('Yearly')),
                ],
                selected: <BillingCycle>{_cycle},
                onSelectionChanged: (Set<BillingCycle> next) {
                  setState(() {
                    _cycle = next.first;
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _tierCard(
          context,
          appState: appState,
          plan: SubscriptionPlan.premium,
          title: 'Premium',
          monthly: 7.99,
          yearly: 59.99,
          bullets: const <String>[
            'Unlimited Temporal Ops',
            'Unlimited SI Console',
            'Full SI output and learning',
            '30-day history',
          ],
        ),
        const SizedBox(height: 10),
        _tierCard(
          context,
          appState: appState,
          plan: SubscriptionPlan.ultimate,
          title: 'Ultimate',
          monthly: 12.99,
          yearly: 99.99,
          highlight: true,
          bullets: const <String>[
            'Everything in Premium',
            'Unlimited history',
            'Advanced analytics',
            'Predictive SI insights',
          ],
        ),
        if (appState.isPremium) ...<Widget>[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : () async => _downgrade(appState),
              icon: const Icon(Icons.arrow_downward),
              label: const Text('Downgrade to Base'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _tierCard(
    BuildContext context, {
    required AppState appState,
    required SubscriptionPlan plan,
    required String title,
    required double monthly,
    required double yearly,
    required List<String> bullets,
    bool highlight = false,
  }) {
    final bool isCurrent = appState.currentPlan == plan;
    final double price = _cycle == BillingCycle.monthly ? monthly : yearly;
    final String suffix = _cycle == BillingCycle.monthly ? '/mo' : '/yr';

    return _card(
      context,
      borderColor: highlight ? const Color(0xFFEFA6FF) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              if (highlight)
                const Text('BEST VALUE', style: TextStyle(color: Color(0xFFEFA6FF), fontSize: 11)),
              if (isCurrent)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Text('CURRENT', style: TextStyle(color: Color(0xFF9BC6FF), fontSize: 11)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '\$${price.toStringAsFixed(2)}$suffix',
            style: const TextStyle(
              color: Color(0xFFC2A7FF),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ...bullets.map(
            (String b) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $b', style: const TextStyle(color: Color(0xFFD8D0E6))),
            ),
          ),
          const SizedBox(height: 8),
          if (!isCurrent)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : () async => _upgrade(appState, plan),
                child: Text(_busy ? 'Processing...' : 'Upgrade'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, {required Widget child, Color? borderColor}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF171427).withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor ?? const Color(0xFF312A49)),
      ),
      child: child,
    );
  }

  Future<void> _upgrade(AppState appState, SubscriptionPlan plan) async {
    setState(() => _busy = true);
    await appState.upgradeToPlan(plan, _cycle);
    if (mounted && (appState.runtimeError ?? '').isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(appState.runtimeError!)));
    }
    if (mounted) {
      setState(() => _busy = false);
    }
  }

  Future<void> _downgrade(AppState appState) async {
    setState(() => _busy = true);
    await appState.downgradePlan();
    if (mounted && (appState.runtimeError ?? '').isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(appState.runtimeError!)));
    }
    if (mounted) {
      setState(() => _busy = false);
    }
  }
}
