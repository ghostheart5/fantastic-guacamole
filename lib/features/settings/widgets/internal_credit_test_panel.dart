import 'package:fantastic_guacamole/state/providers/billing_availability_provider.dart';
import 'package:fantastic_guacamole/l10n/journey_copy.dart';
import 'package:fantastic_guacamole/state/providers/internal_credit_test_provider.dart';
import 'package:fantastic_guacamole/state/providers/paywall_provider.dart';
import 'package:fantastic_guacamole/state/providers/personalization_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

String _localizedCreditTestMessage(BuildContext context, String message) {
  if (Localizations.localeOf(context).languageCode != 'es') return message;
  const Map<String, String> exact = <String, String>{
    'Ready for a synthetic credit test.':
        'Lista para una prueba sintética de créditos.',
    'An authorized account and external AI consent are required.':
        'Se requieren una cuenta autorizada y el consentimiento para usar IA externa.',
    'Waiting for the server result...':
        'Esperando el resultado del servidor...',
    'Result not confirmed. Refresh the balance, then retry the same request.':
        'Resultado sin confirmar. Actualiza el saldo y reintenta la misma solicitud.',
    'A credit quote could not be confirmed. No credits were spent.':
        'No se pudo confirmar el precio en créditos. No se gastaron créditos.',
    'Insufficient credits. The server rejected this request.':
        'Créditos insuficientes. El servidor rechazó esta solicitud.',
    'The quote expired or changed. Request a new quote before confirming.':
        'El precio caducó o cambió. Solicita uno nuevo antes de confirmar.',
    'The server already completed this request. No second charge was made.':
        'El servidor ya completó esta solicitud. No se hizo un segundo cargo.',
    'The original request is still unresolved. Refresh the balance and retry this same request.':
        'La solicitud original sigue sin resolverse. Actualiza el saldo y reintenta la misma solicitud.',
  };
  final String? translated = exact[message];
  if (translated != null) return translated;
  final RegExpMatch? quote = RegExp(
    r'^This test will use (\d+) credits\. Confirm to send it, or choose another quote\. Quote expires in five minutes\.$',
  ).firstMatch(message);
  if (quote != null) {
    return 'Esta prueba usará ${quote.group(1)} créditos. Confirma para enviarla o solicita otro precio. El precio caduca en cinco minutos.';
  }
  final RegExpMatch? http = RegExp(
    r'^The server did not confirm a reply \(HTTP (\d+)\)\. Refresh the balance before retrying this request\.$',
  ).firstMatch(message);
  if (http != null) {
    return 'El servidor no confirmó una respuesta (HTTP ${http.group(1)}). Actualiza el saldo antes de reintentar.';
  }
  return message;
}

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
          Semantics(
            liveRegion: true,
            child: Text(_localizedCreditTestMessage(context, state.message)),
          ),
        ],
      ),
    );
  }
}
