/// The one rule for moving typed words between the free box and the AI chat
/// box, on Chat and on Choose a step, in both directions:
///
/// - Typed words are never destroyed. A box is emptied only when the other
///   box holds the text. When the other box already holds different text,
///   nothing moves: both texts stay where they were and [notice] says where
///   each one is.
/// - Empty words change nothing; the same words change nothing in the
///   receiving box (no doubling on round trips).
/// - A question that was sent and is waiting for its reply is not a draft:
///   it never moves, and in the receiving box it gives way (it is kept with
///   its request and in the conversation).
/// - A suggested question fills only an empty AI chat box; when it is not
///   added, [notice] says so and where the person's own words are.
///
/// Pure: the caller applies [source] and [destination] to its boxes and shows
/// [notice] when it is not null.
class DraftTransfer {
  const DraftTransfer._(this.source, this.destination, this.notice);

  /// Decides a transfer from the box being left ([source]) to the box being
  /// shown ([destination]). [toAi] is true when the AI chat box receives.
  /// On Choose a step ([planner]) the words are copied (the notes stay in
  /// the free planner); on Chat they move. [suggestion] is a suggested
  /// question for the AI chat box, used only when [toAi]. [sourceSent] and
  /// [destinationSent] mark a box that shows a sent question.
  factory DraftTransfer.decide({
    required String source,
    required String destination,
    required bool toAi,
    required bool planner,
    required bool isSpanish,
    bool sourceSent = false,
    bool destinationSent = false,
    String suggestion = '',
  }) {
    String copy(String en, String es) => isSpanish ? es : en;
    final String typed = source.trim();
    final String held = destinationSent ? '' : destination.trim();
    String newSource = source;
    String newDestination = destination;
    String? notice;
    bool kept = false;
    bool placed = false;
    if (typed.isEmpty || sourceSent) {
      // Nothing typed to move.
    } else if (held.isEmpty || held == typed) {
      placed = true;
      newDestination = typed;
      if (!planner) newSource = '';
    } else {
      kept = true;
      notice = toAi
          ? (planner
                ? copy(
                    'Your notes are still in the free planner. AI chat already had other text, which was kept.',
                    'Tus notas siguen en el planificador gratis. El chat con IA ya tenía otro texto, que se conservó.',
                  )
                : copy(
                    'Your words are still in the free assistant. AI chat already had other text, which was kept.',
                    'Tus palabras siguen en el asistente gratis. El chat con IA ya tenía otro texto, que se conservó.',
                  ))
          : (planner
                ? copy(
                    'Your words are still in AI chat. Your notes in the free planner were kept.',
                    'Tus palabras siguen en el chat con IA. Se conservaron tus notas del planificador gratis.',
                  )
                : copy(
                    'Your words are still in AI chat. The free assistant already had other text, which was kept.',
                    'Tus palabras siguen en el chat con IA. El asistente gratis ya tenía otro texto, que se conservó.',
                  ));
    }
    final String label = suggestion.trim();
    if (toAi && label.isNotEmpty) {
      final String inBox = placed ? typed : held;
      if (inBox.isEmpty) {
        newDestination = label;
      } else if (inBox != label) {
        final String notAdded = copy(
          'The question "$label" was not added.',
          'La pregunta "$label" no se añadió.',
        );
        notice = kept
            ? '$notice $notAdded'
            : copy(
                'Your own words are in AI chat. $notAdded',
                'Tus propias palabras están en el chat con IA. $notAdded',
              );
      }
    }
    return DraftTransfer._(newSource, newDestination, notice);
  }

  /// The new text of the box being left.
  final String source;

  /// The new text of the box being shown.
  final String destination;

  /// A plain line to show, or null when nothing needs saying.
  final String? notice;
}
