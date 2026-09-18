import 'package:fantastic_guacamole/state/providers/billing_availability_provider.dart';
import 'package:fantastic_guacamole/l10n/journey_copy.dart';
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
            journeyText(
              context,
              'Internal credit test',
              'Prueba interna de créditos',
            ),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            journeyText(
              context,
              'These test buttons send only a fixed fictional tool-shelf prompt to Anthropic through Axiomara. They do not send your profile, saved context, or conversation history. Successful replies spend test-account credits. Smart Planner and SI conversations separately show their app context and credit quote before sending.',
              'Estos botones de prueba solo envían una solicitud ficticia fija sobre un estante de herramientas a Anthropic por medio de Axiomara. No envían tu perfil, contexto guardado ni historial de conversación. Las respuestas exitosas gastan créditos de la cuenta de prueba. Las conversaciones del Planificador Inteligente y SI muestran por separado su contexto y precio en créditos antes de enviar.',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            wallet.when(
              data: (w) => journeyText(
                context,
                'Server credit balance: ${w.balance}',
                'Saldo de créditos del servidor: ${w.balance}',
              ),
              loading: () => journeyText(
                context,
                'Loading credit balance…',
                'Cargando saldo de créditos…',
              ),
              error: (_, _) => journeyText(
                context,
                'Credit balance unavailable.',
                'El saldo de créditos no está disponible.',
              ),
            ),
          ),
          if (!consent)
            Text(
              journeyText(
                context,
                'Enable external AI assistance above to run these tests.',
                'Activa la asistencia de IA externa arriba para ejecutar estas pruebas.',
              ),
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
                child: Text(
                  journeyText(
                    context,
                    'Quote short test',
                    'Cotizar prueba breve',
                  ),
                ),
              ),
              FilledButton.tonal(
                onPressed: allowed
                    ? () => ref
                          .read(internalCreditTestProvider.notifier)
                          .run(twoCredits: true)
                    : null,
                child: Text(
                  journeyText(
                    context,
                    'Quote longer test',
                    'Cotizar prueba larga',
                  ),
                ),
              ),
              if (state.quotedRequest != null)
                FilledButton(
                  onPressed: allowed
                      ? () => ref
                            .read(internalCreditTestProvider.notifier)
                            .run(confirm: true)
                      : null,
                  child: Text(
                    journeyText(
                      context,
                      'Confirm · ${(state.quotedRequest!['quote'] as Map)['credits']} credits',
                      'Confirmar · ${(state.quotedRequest!['quote'] as Map)['credits']} créditos',
                    ),
                  ),
                ),
              OutlinedButton(
                onPressed: allowed && state.lastRequest != null
                    ? () => ref
                          .read(internalCreditTestProvider.notifier)
                          .run(replay: true)
                    : null,
                child: Text(
                  journeyText(
                    context,
                    'Retry same request',
                    'Reintentar la misma solicitud',
                  ),
                ),
              ),
              TextButton(
                onPressed: state.busy
                    ? null
                    : () => ref.invalidate(aiCreditWalletProvider),
                child: Text(
                  journeyText(
                    context,
                    'Refresh credit balance',
                    'Actualizar saldo de créditos',
                  ),
                ),
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
