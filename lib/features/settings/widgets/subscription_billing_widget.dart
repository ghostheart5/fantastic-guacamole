import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/state/app_state.dart';
import '../../../core/system/subscription_model.dart';
import '../../../data/services/paywall_service.dart';

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
    final PaywallProduct? premiumProduct = _productForCycle(appState);

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
                    : 'Premium access syncs from verified store purchases.',
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
          product: premiumProduct,
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
      ],
    );
  }

  Widget _tierCard(
    BuildContext context, {
    required AppState appState,
    required SubscriptionPlan plan,
    required PaywallProduct? product,
    required String title,
    required double monthly,
    required double yearly,
    required List<String> bullets,
    bool highlight = false,
  }) {
    final bool isCurrent = appState.currentPlan == plan;
    final double fallbackPrice = _cycle == BillingCycle.monthly ? monthly : yearly;
    final String fallbackPriceLabel =
        '\$${fallbackPrice.toStringAsFixed(2)}${_cycle == BillingCycle.monthly ? '/mo' : '/yr'}';
    final String priceLabel = product?.price ?? fallbackPriceLabel;

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
            priceLabel,
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
                onPressed: _busy
                    ? null
                    : () async {
                        if (product == null) {
                          await _loadProducts(appState);
                          return;
                        }
                        await _purchase(appState, product.id);
                      },
                child: Text(_buttonLabel(product)),
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

  PaywallProduct? _productForCycle(AppState appState) {
    final String cycleSuffix = _cycle == BillingCycle.monthly ? '_monthly' : '_yearly';
    for (final PaywallProduct product in appState.paywallProducts) {
      if (product.id.toLowerCase().endsWith(cycleSuffix)) {
        return product;
      }
    }
    return null;
  }

  String _buttonLabel(PaywallProduct? product) {
    if (_busy) {
      return 'Processing...';
    }
    if (product == null) {
      return 'Load Store Plan';
    }
    return 'Continue in Store';
  }

  Future<void> _loadProducts(AppState appState) async {
    setState(() => _busy = true);
    await appState.refreshPaywallProducts();
    if (mounted && (appState.runtimeError ?? '').isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(appState.runtimeError!)));
    }
    if (mounted) {
      setState(() => _busy = false);
    }
  }

  Future<void> _purchase(AppState appState, String productId) async {
    setState(() => _busy = true);
    await appState.purchase(productId);
    if (mounted && (appState.runtimeError ?? '').isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(appState.runtimeError!)));
    }
    if (mounted) {
      setState(() => _busy = false);
    }
  }
}
