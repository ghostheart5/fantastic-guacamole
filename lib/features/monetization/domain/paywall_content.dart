import 'package:fantastic_guacamole/features/monetization/domain/monetization_catalog.dart';
import 'package:fantastic_guacamole/features/monetization/models/ai_credit_package.dart';
import 'package:fantastic_guacamole/features/monetization/models/ai_credit_wallet.dart';
import 'package:fantastic_guacamole/features/monetization/models/subscription_plan.dart';
import 'package:fantastic_guacamole/features/monetization/models/subscription_status.dart';

class PaywallContent {
  const PaywallContent({
    required this.title,
    required this.body,
    required this.status,
    required this.wallet,
    required this.plans,
    required this.creditPackages,
    required this.comparisonRows,
  });

  final String title;
  final String body;
  final SubscriptionStatus status;
  final AiCreditWallet wallet;
  final List<SubscriptionPlan> plans;
  final List<AiCreditPackage> creditPackages;
  final List<FeatureComparisonRow> comparisonRows;
}