import 'package:fantastic_guacamole/features/monetization/providers/monetization_providers.dart';
import 'package:fantastic_guacamole/features/monetization/widgets/ai_credit_balance_card.dart';
import 'package:fantastic_guacamole/features/monetization/widgets/credit_package_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CreditStoreScreen extends ConsumerWidget {
  const CreditStoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paywallAsync = ref.watch(paywallProvider);
    final purchaseState = ref.watch(purchaseProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('AI Credit Store')),
      body: paywallAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) => Center(child: Text(error.toString())),
        data: (content) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AiCreditBalanceCard(wallet: content.wallet),
            const SizedBox(height: 18),
            ...content.creditPackages.map(
              (pack) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: CreditPackageCard(
                  package: pack,
                  busy: purchaseState.isBusy && purchaseState.activeProductId == pack.productId,
                  onPressed: () => ref.read(purchaseProvider.notifier).purchaseCredits(pack.id),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}