import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:flutter/material.dart';

/// What turning on AI chat means, in plain words. Chat's consent sheet and the
/// Settings switch show the same text. The facts match the per-request review
/// in the conversation screen: the provider, retention and that every message
/// shows its credit price before anything is sent or charged.
class AiChatDisclosure {
  const AiChatDisclosure({required this.spanish});

  final bool spanish;

  String _copy(String en, String es) => spanish ? es : en;

  String get featureName => _copy('AI chat', 'Chat con IA');

  String get whatIsSent => _copy(
    'What is sent: your question, up to six recent messages from this conversation, and the information shown in the preview before you send.',
    'Qué se envía: tu pregunta, hasta seis mensajes recientes de esta conversación y la información que se muestra en la vista previa antes de enviar.',
  );

  String get toWhom => _copy(
    'Who receives it: Axiomara, to work out the price. If you confirm the price, Axiomara sends it to Anthropic, the AI provider, for a reply.',
    'Quién lo recibe: Axiomara, para calcular el precio. Si confirmas el precio, Axiomara lo envía a Anthropic, el proveedor de IA, para obtener la respuesta.',
  );

  String get howLong => _copy(
    'How long it is kept: Anthropic normally keeps it for up to 30 days.',
    'Cuánto tiempo se guarda: Anthropic normalmente lo conserva hasta 30 días.',
  );

  String get cost => _copy(
    'What it costs: each message shows its price in credits before anything is sent. Nothing is charged until you confirm that price.',
    'Cuánto cuesta: cada mensaje muestra su precio en créditos antes de enviar nada. No se cobra nada hasta que confirmes ese precio.',
  );

  List<String> get lines => [whatIsSent, toWhom, howLong, cost];

  /// The whole explanation as one block, for the Settings switch.
  String get summary => lines.join('\n');
}

/// Asks once whether to turn on AI chat. Returns true only when the person
/// taps Allow. Opening or answering the sheet sends nothing anywhere; the
/// caller saves the choice. [onRoute] receives the sheet's context while it is
/// open (null once closed) so an account change can close it.
Future<bool> showAiChatConsentSheet(
  BuildContext context, {
  ValueChanged<BuildContext?>? onRoute,
}) async {
  try {
    return await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          showDragHandle: true,
          builder: (sheet) {
            onRoute?.call(sheet);
            return const _AiChatConsentSheet();
          },
        ) ??
        false;
  } finally {
    onRoute?.call(null);
  }
}

class _AiChatConsentSheet extends StatelessWidget {
  const _AiChatConsentSheet();

  @override
  Widget build(BuildContext context) {
    final spanish = ChronoSparkLocalizations.of(context).isSpanish;
    final disclosure = AiChatDisclosure(spanish: spanish);
    String copy(String en, String es) => spanish ? es : en;
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            header: true,
            child: Text(
              copy('Turn on AI chat?', '¿Activar el chat con IA?'),
              style: theme.textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 12),
          for (final line in disclosure.lines) ...[
            Text(line),
            const SizedBox(height: 8),
          ],
          Text(
            copy(
              'Turning it on sends nothing by itself. You can turn it off again in Settings › Planning & guidance.',
              'Activarlo no envía nada por sí solo. Puedes volver a desactivarlo en Ajustes › Planificación y orientación.',
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                key: const Key('ai-chat-consent-decline'),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () => Navigator.pop(context, false),
                child: Text(copy('Not now', 'Ahora no')),
              ),
              FilledButton(
                key: const Key('ai-chat-consent-allow'),
                style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () => Navigator.pop(context, true),
                child: Text(copy('Allow AI chat', 'Permitir el chat con IA')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
