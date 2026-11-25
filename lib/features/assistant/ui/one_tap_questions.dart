import 'package:fantastic_guacamole/domain/entities/assistant_conversation.dart';
import 'package:fantastic_guacamole/domain/entities/si_one_tap_question.dart';
import 'package:fantastic_guacamole/domain/entities/si_v2_contract.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:flutter/material.dart';

/// The questions shown in the row inside Chat. "Help me reach this goal" asks
/// which goal first when there are several.
const List<SIOneTapQuestion> chatOneTapQuestions = SIOneTapQuestion.values;

/// A shorter set for Today.
const List<SIOneTapQuestion> todayOneTapQuestions = <SIOneTapQuestion>[
  SIOneTapQuestion.planMyDay,
  SIOneTapQuestion.whatsComingUp,
  SIOneTapQuestion.fallingBehind,
];

enum OneTapRowLayout {
  /// One line that scrolls sideways, for the fixed area above a conversation.
  scroll,

  /// Wraps onto as many lines as needed, for a list that already scrolls.
  wrap,
}

/// A row of one-tap question buttons. Tapping one only asks the question: it
/// is answered on this device, for free, and nothing is sent to a server.
class OneTapQuestionRow extends StatelessWidget {
  const OneTapQuestionRow({
    super.key,
    required this.questions,
    required this.onAsk,
    this.enabled = true,
    this.layout = OneTapRowLayout.wrap,
    this.trailing,
  });

  final List<SIOneTapQuestion> questions;
  final ValueChanged<SIOneTapQuestion> onAsk;
  final bool enabled;
  final OneTapRowLayout layout;

  /// An extra last button, for example "More questions" on Today.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final bool isSpanish = ChronoSparkLocalizations.of(context).isSpanish;
    final List<Widget> buttons = <Widget>[
      for (final SIOneTapQuestion question in questions)
        OutlinedButton(
          key: ValueKey<String>('one-tap-${question.name}'),
          onPressed: enabled ? () => onAsk(question) : null,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(question.label(isSpanish: isSpanish)),
        ),
      ?trailing,
    ];
    if (layout == OneTapRowLayout.wrap) {
      return Wrap(spacing: 8, runSpacing: 8, children: buttons);
    }
    // At large text a sideways row is too long to use: one button opens the
    // same questions as a list that fits the screen.
    if (MediaQuery.textScalerOf(context).scale(1) > 1.3) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: OutlinedButton(
          key: const Key('one-tap-more-sheet'),
          onPressed: enabled
              ? () => _chooseFromSheet(context, questions, onAsk, isSpanish)
              : null,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            isSpanish ? 'Preguntas rápidas · gratis' : 'Quick questions · free',
          ),
        ),
      );
    }
    return SizedBox(
      height: 48,
      child: SingleChildScrollView(
        key: const Key('one-tap-row-scroll'),
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            for (int i = 0; i < buttons.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: 8),
              buttons[i],
            ],
          ],
        ),
      ),
    );
  }
}

Future<void> _chooseFromSheet(
  BuildContext context,
  List<SIOneTapQuestion> questions,
  ValueChanged<SIOneTapQuestion> onAsk,
  bool isSpanish,
) async {
  final SIOneTapQuestion? picked = await showModalBottomSheet<SIOneTapQuestion>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (BuildContext sheet) => SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Semantics(
                  header: true,
                  child: Text(
                    isSpanish
                        ? 'Preguntas rápidas · gratis, respondidas en este dispositivo'
                        : 'Quick questions · free, answered on this device',
                    style: Theme.of(sheet).textTheme.titleMedium,
                  ),
                ),
              ),
              for (final SIOneTapQuestion question in questions)
                ListTile(
                  key: ValueKey<String>('one-tap-sheet-${question.name}'),
                  minVerticalPadding: 12,
                  title: Text(question.label(isSpanish: isSpanish)),
                  onTap: () => Navigator.pop(sheet, question),
                ),
            ],
          ),
        ),
      ),
    ),
  );
  if (picked != null) onAsk(picked);
}

/// The line and buttons under a one-tap answer: it says plainly that the
/// answer was made on this device for free, and offers the two follow-ups that
/// need the person's own tap. Neither follow-up changes anything by itself.
class OneTapAnswerFooter extends StatelessWidget {
  const OneTapAnswerFooter({
    super.key,
    required this.answer,
    this.onAddSomething,
    this.onAskAi,
  });

  final SIOneTapAnswer answer;

  /// Opens the existing Add something review step. Null hides the button.
  final VoidCallback? onAddSomething;

  /// Moves the question to AI chat, where the price is shown and a send needs
  /// its own confirmation. Null hides the button (AI chat is not available).
  final VoidCallback? onAskAi;

  @override
  Widget build(BuildContext context) {
    final bool isSpanish = ChronoSparkLocalizations.of(context).isSpanish;
    return Padding(
      key: const Key('one-tap-footer'),
      padding: const EdgeInsetsDirectional.fromSTEB(40, 0, 0, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(
            container: true,
            child: Text(
              isSpanish
                  ? 'Respondido en este dispositivo · gratis. No se envió nada y no se usaron créditos.'
                  : 'Answered on this device · free. Nothing was sent and no credits were used.',
              key: const Key('one-tap-free-line'),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
          if (onAddSomething != null || onAskAi != null) ...<Widget>[
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                if (onAddSomething != null)
                  OutlinedButton(
                    key: const Key('one-tap-add'),
                    onPressed: onAddSomething,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    child: Text(
                      isSpanish ? 'Abrir Añadir algo' : 'Open Add something',
                    ),
                  ),
                if (onAskAi != null)
                  OutlinedButton(
                    key: const Key('one-tap-ask-ai'),
                    onPressed: onAskAi,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    child: Text(
                      isSpanish
                          ? 'Preguntar a la IA · $conversationMessageCredits créditos'
                          : 'Ask AI · $conversationMessageCredits credits',
                    ),
                  ),
              ],
            ),
            if (onAskAi != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  isSpanish
                      ? 'Esto solo abre el chat con IA con tu pregunta. No se envía nada hasta que confirmes el precio.'
                      : 'This only opens AI chat with your question. Nothing is sent until you confirm the price.',
                  key: const Key('one-tap-ai-note'),
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Asks which goal, when there are several. Returns the chosen goal id, or
/// null when the person closes the sheet.
Future<String?> chooseOneTapGoal(
  BuildContext context,
  List<SIV2GoalEvidence> goals,
) {
  final bool isSpanish = ChronoSparkLocalizations.of(context).isSpanish;
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (BuildContext sheet) => SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Semantics(
                  header: true,
                  child: Text(
                    isSpanish ? '¿Con qué meta?' : 'Which goal?',
                    style: Theme.of(sheet).textTheme.titleMedium,
                  ),
                ),
              ),
              for (final SIV2GoalEvidence goal in goals)
                ListTile(
                  key: ValueKey<String>('one-tap-goal-${goal.id}'),
                  minVerticalPadding: 12,
                  title: Text(goal.title),
                  onTap: () => Navigator.pop(sheet, goal.id),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
