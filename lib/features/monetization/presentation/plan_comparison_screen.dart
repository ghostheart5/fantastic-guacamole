import 'package:fantastic_guacamole/features/monetization/domain/monetization_catalog.dart';
import 'package:fantastic_guacamole/features/monetization/providers/monetization_feature_providers.dart';
import 'package:fantastic_guacamole/features/monetization/widgets/feature_comparison_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PlanComparisonScreen extends ConsumerWidget {
  const PlanComparisonScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paywallAsync = ref.watch(paywallProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Plan Comparison')),
      body: paywallAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) =>
            Center(child: Text(error.toString())),
        data: (_) => const Padding(
          padding: EdgeInsets.all(16),
          child: FeatureComparisonTable(rows: MonetizationCatalog.comparisonRows),
        ),
      ),
    );
  }
}
