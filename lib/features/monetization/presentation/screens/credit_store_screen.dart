import 'package:fantastic_guacamole/core/debug/app_analytics.dart';
import 'package:fantastic_guacamole/features/monetization/data/models/ai_credit_package.dart';
import 'package:fantastic_guacamole/features/monetization/data/services/analytics_events.dart';
import 'package:fantastic_guacamole/features/monetization/presentation/controllers/credit_store_controller.dart';
import 'package:fantastic_guacamole/features/monetization/presentation/widgets/credit_balance_widget.dart';
import 'package:fantastic_guacamole/features/monetization/providers/monetization_feature_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CreditStoreScreen extends ConsumerStatefulWidget {
  const CreditStoreScreen({super.key});

  @override
  ConsumerState<CreditStoreScreen> createState() => _CreditStoreScreenState();
}

class _CreditStoreScreenState extends ConsumerState<CreditStoreScreen> {
  @override
  void initState() {
    super.initState();
    AppAnalytics.track(MonetizationEvents.creditStoreViewed);
  }

  @override
  Widget build(BuildContext context) {
    final packagesAsync = ref.watch(aiCreditPackagesProvider);
    final walletAsync = ref.watch(aiCreditWalletProvider);
    final wallet = walletAsync.maybeWhen(
      data: (value) => value,
      orElse: () => null,
    );
    final controller = ref.watch(creditStoreControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('AI Credit Store')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CreditBalanceWidget(wallet: wallet),
          const SizedBox(height: 12),
          packagesAsync.when(
            data: (List<AiCreditPackage> packages) {
              if (packages.isEmpty) {
                return const Text('No credit packs are currently available.');
              }
              return Column(
                children: packages
                    .map(
                      (AiCreditPackage pack) => Card(
                        child: ListTile(
                          title: Text(pack.name),
                          subtitle: Text(
                            'Credits: ${pack.totalCredits} • ${pack.currencyCode}',
                          ),
                          trailing: controller.isBusy &&
                                  controller.activeProductId == pack.productId
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : FilledButton(
                                  onPressed: () => ref
                                      .read(creditStoreControllerProvider.notifier)
                                      .purchasePack(pack),
                                  child: const Text('Buy'),
                                ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object error, StackTrace stackTrace) => Text(error.toString()),
          ),
          if (controller.error != null)
            Text(controller.error!, style: const TextStyle(color: Colors.red)),
        ],
      ),
    );
  }
}
