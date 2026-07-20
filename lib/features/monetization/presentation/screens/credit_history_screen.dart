import 'package:fantastic_guacamole/features/monetization/providers/monetization_feature_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CreditHistoryScreen extends ConsumerWidget {
  const CreditHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(aiCreditTransactionsProvider);
    final purchasesAsync = ref.watch(purchaseHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Credit History')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Transactions',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          transactionsAsync.when(
            data: (transactions) => Column(
              children: transactions
                  .map(
                    (tx) => ListTile(
                      title: Text(tx.description),
                      subtitle: Text('${tx.type} • ${tx.source}'),
                      trailing: Text('${tx.amount}'),
                    ),
                  )
                  .toList(growable: false),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (Object error, StackTrace stackTrace) => Text(error.toString()),
          ),
          const SizedBox(height: 16),
          const Text(
            'Purchase History',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          purchasesAsync.when(
            data: (purchases) => Column(
              children: purchases
                  .map(
                    (purchase) => ListTile(
                      title: Text(purchase.productId),
                      subtitle: Text('${purchase.purchaseType} • ${purchase.purchaseState}'),
                      trailing: Text('+${purchase.creditsGranted}'),
                    ),
                  )
                  .toList(growable: false),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (Object error, StackTrace stackTrace) => Text(error.toString()),
          ),
        ],
      ),
    );
  }
}
