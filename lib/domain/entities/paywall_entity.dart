import 'package:fantastic_guacamole/domain/entities/paywall_plan.dart';

class PaywallEntity {
  const PaywallEntity({
    required this.featureId,
    required this.title,
    required this.body,
    required this.plans,
    required this.isUnlocked,
  });

  final String featureId;
  final String title;
  final String body;
  final List<PaywallPlan> plans;
  final bool isUnlocked;
}
