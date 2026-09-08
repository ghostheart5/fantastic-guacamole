import 'package:fantastic_guacamole/state/providers/billing_availability_provider.dart';
import 'package:fantastic_guacamole/state/providers/internal_credit_test_provider.dart';
import 'package:fantastic_guacamole/state/providers/paywall_provider.dart';
import 'package:fantastic_guacamole/state/providers/personalization_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class InternalCreditTestPanel extends ConsumerWidget {
  const InternalCreditTestPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(internalCreditTestEnabledProvider)) {
      return const SizedBox.shrink();
    }
    final state = ref.watch(internalCreditTestProvider);
    final consent = ref.watch(personalizationProfileProvider).externalAiAllowed;
    final allowed = consent && !state.busy;
    final wallet = ref.watch(aiCreditWalletProvider);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Internal credit test',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Sends only a fixed fictional tool-shelf prompt to Anthropic through ChronoSpark. No profile, saved context, or conversation history is sent. Successful replies spend real test-account credits. SI Console guidance remains local.',
          ),
          const SizedBox(height: 8),
          Text(
            wallet.when(
              data: (w) => 'Server credit balance: ${w.balance}',
              loading: () => 'Loading credit balance…',
              error: (_, _) => 'Credit balance unavailable.',
            ),
          ),
          if (!consent)
            const Text(
              'Enable external AI assistance above to run these tests.',
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: allowed
                    ? () => ref.read(internalCreditTestProvider.notifier).run()
                    : null,
                child: const Text('Test 1 credit'),
              ),
              FilledButton.tonal(
                onPressed: allowed
                    ? () => ref
                          .read(internalCreditTestProvider.notifier)
                          .run(twoCredits: true)
                    : null,
                child: const Text('Test 2 credits'),
              ),
              OutlinedButton(
                onPressed: allowed && state.lastRequest != null
                    ? () => ref
                          .read(internalCreditTestProvider.notifier)
                          .run(replay: true)
                    : null,
                child: const Text('Retry same request'),
              ),
              TextButton(
                onPressed: state.busy
                    ? null
                    : () => ref.invalidate(aiCreditWalletProvider),
                child: const Text('Refresh credit balance'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Semantics(liveRegion: true, child: Text(state.message)),
        ],
      ),
    );
  }
}
