import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/core/debug/app_analytics.dart';
import 'package:fantastic_guacamole/features/monetization/models/subscription_status.dart';
import 'package:fantastic_guacamole/features/monetization/providers/monetization_providers.dart';
import 'package:fantastic_guacamole/features/monetization/services/credit_service.dart'
    as monetization;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

Future<monetization.CreditBalanceCheck> checkCreditBalance(
  Ref ref, {
  required int amount,
}) {
  return ref.read(monetizationCreditServiceProvider).checkBalance(amount);
}

Future<monetization.CreditConsumeResult> consumeCredits(
  Ref ref, {
  required int amount,
  required String reason,
  Map<String, dynamic> metadata = const <String, dynamic>{},
}) {
  return ref.read(monetizationCreditServiceProvider).consume(
    amount: amount,
    reason: reason,
    metadata: metadata,
  );
}

Future<SubscriptionStatus> checkSubscriptionStatus(Ref ref) {
  return ref.read(subscriptionProvider.future);
}