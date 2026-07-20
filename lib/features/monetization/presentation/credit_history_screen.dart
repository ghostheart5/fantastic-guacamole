import 'package:fantastic_guacamole/features/monetization/models/ai_credit_transaction.dart';
import 'package:fantastic_guacamole/features/monetization/providers/monetization_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CreditHistoryScreen extends ConsumerWidget {
  const CreditHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(creditHistoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Credit History')),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) => Center(child: Text(error.toString())),
        data: (List<AiCreditTransaction> history) {
          if (history.isEmpty) {
            return const Center(child: Text('No credit activity yet.'));
          }
          return ListView.separated(
            itemCount: history.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (BuildContext context, int index) {
              final item = history[index];
              return ListTile(
                title: Text(item.description),
                subtitle: Text('${item.source} • ${item.createdAt.toLocal()}'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(item.amount.toString()),
                    Text('Bal ${item.balanceAfter}'),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}