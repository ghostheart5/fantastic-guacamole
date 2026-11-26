import 'package:fantastic_guacamole/features/assistant/ui/draft_transfer.dart';
import 'package:flutter_test/flutter_test.dart';

// The one rule for typed words moving between the free box and the AI chat
// box. Checked over every combination of texts and flags, then on examples
// with the exact lines.

DraftTransfer _decide({
  String source = '',
  String destination = '',
  bool toAi = true,
  bool planner = false,
  bool spanish = false,
  bool sent = false,
  bool destinationSent = false,
  String suggestion = '',
}) => DraftTransfer.decide(
  source: source,
  destination: destination,
  toAi: toAi,
  planner: planner,
  isSpanish: spanish,
  sourceSent: sent,
  destinationSent: destinationSent,
  suggestion: suggestion,
);

void main() {
  const texts = <String>['', '  ', 'mine', ' mine ', 'other', 'Plan my day'];
  const suggestions = <String>['', 'Plan my day', 'mine'];

  group('every combination', () {
    for (final source in texts) {
      for (final destination in texts) {
        for (final toAi in [true, false]) {
          for (final planner in [true, false]) {
            for (final sent in [true, false]) {
              for (final destSent in [true, false]) {
                for (final suggestion in suggestions) {
                  for (final spanish in [true, false]) {
                    final name =
                        '"$source" -> "$destination" toAi=$toAi planner=$planner '
                        'sent=$sent destSent=$destSent suggestion="$suggestion" '
                        'es=$spanish';
                    test(name, () {
                      final r = _decide(
                        source: source,
                        destination: destination,
                        toAi: toAi,
                        planner: planner,
                        spanish: spanish,
                        sent: sent,
                        destinationSent: destSent,
                        suggestion: suggestion,
                      );
                      final typed = source.trim();
                      // A sent question in the receiving box is not a draft.
                      final held = destSent ? '' : destination.trim();
                      final after = {r.source.trim(), r.destination.trim()};
                      // No typed words are ever lost.
                      if (typed.isNotEmpty) expect(after, contains(typed));
                      if (held.isNotEmpty) expect(after, contains(held));
                      // An empty source with no suggestion changes nothing,
                      // even over a sent question.
                      if (typed.isEmpty && (!toAi || suggestion.isEmpty)) {
                        expect(r.source, source);
                        expect(r.destination, destination);
                        expect(r.notice, isNull);
                      }
                      // A box is emptied only when the other one holds the text.
                      if (r.source.trim().isEmpty && typed.isNotEmpty) {
                        expect(r.destination.trim(), typed);
                      }
                      // A sent question, and the planner's notes, stay put.
                      if (sent || planner) expect(r.source, source);
                      if (sent && (!toAi || suggestion.isEmpty)) {
                        expect(r.destination, destination);
                      }
                      // Different text already there: nothing moves, and the
                      // line says so.
                      if (typed.isNotEmpty && !sent && held.isNotEmpty) {
                        if (held != typed) {
                          expect(r.source, source);
                          expect(r.destination, destination);
                          expect(r.notice, isNotNull);
                        } else {
                          expect(r.destination.trim(), held);
                        }
                      }
                      // A suggestion only ever fills an empty AI chat box.
                      final label = suggestion.trim();
                      if (!toAi || label.isEmpty) {
                        if (typed.isEmpty || sent) {
                          expect(r.source, source);
                          expect(r.destination, destination);
                        }
                      } else if (r.destination.trim() == label &&
                          held != label &&
                          typed != label) {
                        expect(held, isEmpty);
                        expect(typed.isEmpty || sent, isTrue);
                      }
                      if (destSent && typed.isNotEmpty && !sent) {
                        expect(r.destination.trim(), typed);
                      }
                      if (toAi &&
                          label.isNotEmpty &&
                          r.destination.trim() != label) {
                        expect(r.notice, contains('"$label"'));
                      }
                      if (r.notice != null) {
                        expect(r.notice, isNot(contains('null')));
                        expect(
                          RegExp(
                            r'\b(?:sessions?|focus|journals?)\b',
                            caseSensitive: false,
                          ).hasMatch(r.notice!),
                          isFalse,
                        );
                      }
                      // Applying it again changes nothing more: no doubling.
                      final again = _decide(
                        source: r.source,
                        destination: r.destination,
                        toAi: toAi,
                        planner: planner,
                        spanish: spanish,
                        sent: sent,
                        // Still a sent question only if it is still there.
                        destinationSent:
                            destSent &&
                            r.destination == destination &&
                            (typed.isEmpty || sent),
                        suggestion: suggestion,
                      );
                      expect(again.source, r.source);
                      expect(again.destination, r.destination);
                    });
                  }
                }
              }
            }
          }
        }
      }
    }
  });

  group('examples', () {
    test('Chat: words move to an empty box and leave the other', () {
      final r = _decide(source: ' free words ', toAi: true);
      expect(r.source, '');
      expect(r.destination, 'free words');
      expect(r.notice, isNull);
    });

    test('Chat: a round trip with nothing new typed doubles nothing', () {
      final there = _decide(source: 'free words');
      final back = _decide(
        source: there.destination,
        destination: there.source,
        toAi: false,
      );
      expect(back.source, '');
      expect(back.destination, 'free words');
      final again = _decide(source: back.destination, destination: back.source);
      expect(again.destination, 'free words');
      expect(again.source, '');
    });

    test('Chat: the same words in both boxes end in one', () {
      final r = _decide(source: 'same', destination: 'same');
      expect(r.source, '');
      expect(r.destination, 'same');
      expect(r.notice, isNull);
    });

    test('an empty source changes nothing and says nothing', () {
      for (final planner in [true, false]) {
        final r = _decide(
          source: '   ',
          destination: 'restored question',
          planner: planner,
        );
        expect(r.source, '   ');
        expect(r.destination, 'restored question');
        expect(r.notice, isNull);
      }
    });

    for (final spanish in [false, true]) {
      test('Chat: to AI chat holding other text (es=$spanish)', () {
        final r = _decide(
          source: 'my words',
          destination: 'restored question',
          spanish: spanish,
        );
        expect(r.source, 'my words');
        expect(r.destination, 'restored question');
        expect(
          r.notice,
          spanish
              ? 'Tus palabras siguen en el asistente gratis. El chat con IA ya tenía otro texto, que se conservó.'
              : 'Your words are still in the free assistant. AI chat already had other text, which was kept.',
        );
      });

      test('Chat: to the free box holding other text (es=$spanish)', () {
        final r = _decide(
          source: 'ai words',
          destination: 'free words',
          toAi: false,
          spanish: spanish,
        );
        expect(r.source, 'ai words');
        expect(r.destination, 'free words');
        expect(
          r.notice,
          spanish
              ? 'Tus palabras siguen en el chat con IA. El asistente gratis ya tenía otro texto, que se conservó.'
              : 'Your words are still in AI chat. The free assistant already had other text, which was kept.',
        );
      });

      test(
        'Choose a step: notes into AI chat holding a question (es=$spanish)',
        () {
          final r = _decide(
            source: 'notes',
            destination: 'restored question',
            planner: true,
            spanish: spanish,
          );
          expect(r.source, 'notes');
          expect(r.destination, 'restored question');
          expect(
            r.notice,
            spanish
                ? 'Tus notas siguen en el planificador gratis. El chat con IA ya tenía otro texto, que se conservó.'
                : 'Your notes are still in the free planner. AI chat already had other text, which was kept.',
          );
        },
      );

      test('Choose a step: AI words onto typed notes (es=$spanish)', () {
        final r = _decide(
          source: 'ai words',
          destination: 'my notes',
          toAi: false,
          planner: true,
          spanish: spanish,
        );
        expect(r.source, 'ai words');
        expect(r.destination, 'my notes');
        expect(
          r.notice,
          spanish
              ? 'Tus palabras siguen en el chat con IA. Se conservaron tus notas del planificador gratis.'
              : 'Your words are still in AI chat. Your notes in the free planner were kept.',
        );
      });

      test('Ask AI with typed words: the words go, the question does not '
          '(es=$spanish)', () {
        final r = _decide(
          source: 'my words',
          suggestion: 'Help me reach this goal',
          spanish: spanish,
        );
        expect(r.source, '');
        expect(r.destination, 'my words');
        expect(
          r.notice,
          spanish
              ? 'Tus propias palabras están en el chat con IA. La pregunta "Help me reach this goal" no se añadió.'
              : 'Your own words are in AI chat. The question "Help me reach this goal" was not added.',
        );
      });

      test('Ask AI when both boxes hold different words (es=$spanish)', () {
        final r = _decide(
          source: 'free words',
          destination: 'ai words',
          suggestion: 'Plan my day',
          spanish: spanish,
        );
        expect(r.source, 'free words');
        expect(r.destination, 'ai words');
        expect(
          r.notice,
          spanish
              ? 'Tus palabras siguen en el asistente gratis. El chat con IA ya tenía otro texto, que se conservó. La pregunta "Plan my day" no se añadió.'
              : 'Your words are still in the free assistant. AI chat already had other text, which was kept. The question "Plan my day" was not added.',
        );
      });
    }

    test('Ask AI with both boxes empty: the question is the draft', () {
      final r = _decide(suggestion: 'Plan my day');
      expect(r.destination, 'Plan my day');
      expect(r.notice, isNull);
    });

    test('a sent question never moves to the free box', () {
      final r = _decide(
        source: 'What should I do first?',
        toAi: false,
        sent: true,
      );
      expect(r.source, 'What should I do first?');
      expect(r.destination, '');
      expect(r.notice, isNull);
    });

    test('a sent question in AI chat gives way to typed words', () {
      for (final planner in [true, false]) {
        final r = _decide(
          source: 'Carry these notes',
          destination: 'Which step first?',
          planner: planner,
          destinationSent: true,
        );
        expect(r.destination, 'Carry these notes');
        expect(r.source, planner ? 'Carry these notes' : '');
        expect(r.notice, isNull);
      }
    });

    test('Choose a step copies: the notes stay in the free planner', () {
      final r = _decide(source: 'notes', planner: true);
      expect(r.source, 'notes');
      expect(r.destination, 'notes');
    });
  });
}
