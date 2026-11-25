import 'package:fantastic_guacamole/domain/entities/assistant_conversation.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:flutter/material.dart';

/// What turning on AI chat means, in plain words. Chat's consent sheet and the
/// Settings switch show the same text. The facts match the conversation
/// screen: the price is on the send button and tapping send confirms it, a
/// different checked price is asked about first, and the full preview opens
/// by itself the first time and whenever the selected information changes.
class AiChatDisclosure {
  const AiChatDisclosure({required this.spanish});

  final bool spanish;

  String _copy(String en, String es) => spanish ? es : en;

  String get featureName => _copy('AI chat', 'Chat con IA');

  String get whatIsSent => _copy(
    'What is sent: your question, up to six recent messages from this conversation, and the information listed above the message box. Once you have typed a question, See what is sent by the message box shows the full preview of what goes whenever sending is available; it also opens by itself before your first message after the app opens and whenever that information changes.',
    'Qué se envía: tu pregunta, hasta seis mensajes recientes de esta conversación y la información que aparece encima del cuadro de mensaje. Cuando hayas escrito una pregunta, Ver qué se envía, junto al cuadro de mensaje, muestra la vista previa completa de lo que se envía siempre que se pueda enviar; también se abre sola antes de tu primer mensaje después de abrir la app y cada vez que cambia esa información.',
  );

  String get toWhom => _copy(
    'Who receives it: when you tap send, Axiomara receives it to check the price, then sends it to Anthropic, the AI provider, for a reply.',
    'Quién lo recibe: cuando tocas enviar, Axiomara lo recibe para comprobar el precio y luego lo envía a Anthropic, el proveedor de IA, para obtener la respuesta.',
  );

  String get howLong => _copy(
    'How long it is kept: Anthropic normally keeps it for up to 30 days.',
    'Cuánto tiempo se guarda: Anthropic normalmente lo conserva hasta 30 días.',
  );

  // The price is on the send button. Tapping send confirms it and sends the
  // question to Axiomara to check it; Anthropic receives it only at the shown
  // price or after a different price is confirmed.
  String get cost => _copy(
    'What it costs: the send button shows the price in credits, for example Send · $conversationMessageCredits credits. Tapping send confirms that price. If the checked price is different, you are asked before anything reaches Anthropic, and nothing is charged unless you confirm it.',
    'Cuánto cuesta: el botón de enviar muestra el precio en créditos, por ejemplo Enviar · $conversationMessageCredits créditos. Tocar enviar confirma ese precio. Si el precio comprobado es distinto, se te pregunta antes de que algo llegue a Anthropic y no se cobra nada si no lo confirmas.',
  );

  // The same preference also allows Choose a step's optional plan
  // explanation (plannerExplanationAvailabilityProvider). It sends the
  // visible plan (PlannerExplanationPacket) for a quote first, then to
  // Anthropic only after the person confirms that quote.
  String get planExplanation => _copy(
    'Also on Choose a step: where it is offered, the optional Explain this plan button sends the plan shown on screen to Axiomara to show you its price in credits, and to Anthropic only after you confirm that price.',
    'También en Elegir un paso: donde se ofrece, el botón opcional Explicar este plan envía el plan que ves en pantalla a Axiomara para mostrarte su precio en créditos, y a Anthropic solo después de que confirmes ese precio.',
  );

  List<String> get lines => [
    whatIsSent,
    toWhom,
    howLong,
    cost,
    planExplanation,
  ];

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
    // The explanation scrolls; the two choices stay visible below it.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
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
                ],
              ),
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
