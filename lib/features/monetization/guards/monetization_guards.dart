import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/core/debug/app_analytics.dart';
import 'package:fantastic_guacamole/features/monetization/data/models/models.dart';
import 'package:fantastic_guacamole/features/monetization/providers/monetization_feature_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CreditBalanceCheck {
  const CreditBalanceCheck({required this.allowed, required this.wallet});

  final bool allowed;
  final AiCreditWallet wallet;
}

class CreditConsumeResult {
  const CreditConsumeResult({required this.allowed, required this.wallet});

  final bool allowed;
  final AiCreditWallet wallet;
}

const AiCreditWallet _emptyWallet = AiCreditWallet(
  userId: '',
  balance: 0,
  allowanceRemaining: 0,
  bonusBalance: 0,
  periodCredits: 0,
  lifetimeEarned: 0,
  lifetimeSpent: 0,
  tier: 'free',
);

Future<bool> premiumFeatureGuard(
  WidgetRef ref,
  BuildContext context, {
  required String featureId,
}) async {
  final bool allowed = ref.read(premiumAccessProvider);
  if (allowed) {
    return true;
  }
  AppAnalytics.track(
    'subscription_viewed',
    params: <String, Object?>{'feature_id': featureId, 'trigger': 'guard'},
  );
  if (context.mounted) {
    context.push(RoutePaths.paywall);
  }
  return false;
}

Future<CreditBalanceCheck> checkCreditBalance(
  Ref ref, {
  required int amount,
}) {
  return () async {
    final AiCreditWallet? wallet = await ref.read(aiCreditWalletProvider.future);
    final AiCreditWallet resolvedWallet = wallet ?? _emptyWallet;
    return CreditBalanceCheck(
      allowed: resolvedWallet.balance >= amount,
      wallet: resolvedWallet,
    );
  }();
}

Future<CreditConsumeResult> consumeCredits(
  Ref ref, {
  required int amount,
  required String reason,
  Map<String, dynamic> metadata = const <String, dynamic>{},
}) {
  return () async {
    final AiCreditWallet? wallet = await ref
        .read(aiCreditServiceProvider)
        .spendCredits(amount: amount, reason: reason, metadata: metadata);
    if (wallet == null) {
      return const CreditConsumeResult(allowed: false, wallet: _emptyWallet);
    }
    return CreditConsumeResult(allowed: true, wallet: wallet);
  }();
}

Future<UserSubscription?> checkSubscriptionStatus(Ref ref) {
  return ref.read(currentSubscriptionProvider.future);
}
