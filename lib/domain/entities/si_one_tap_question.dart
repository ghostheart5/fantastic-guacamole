// CHRONOSPARK-CLASS: SHIPPING | Feature: One-tap questions
import 'package:fantastic_guacamole/domain/entities/si_v2_contract.dart';

/// The fixed set of one-tap questions. Each is answered on the device, for
/// free, from records the app already has. Nothing here is ever sent to a
/// server and nothing here changes a record.
enum SIOneTapQuestion {
  planMyDay,
  whatsComingUp,
  fallingBehind,
  reachGoal,
  improveRoutine,
  explainPatterns,
  getBackOnTrack,
  reviewWeek;

  /// The words on the button and the first line of the conversation.
  String label({required bool isSpanish}) => switch (this) {
    SIOneTapQuestion.planMyDay => isSpanish ? 'Planear mi día' : 'Plan my day',
    SIOneTapQuestion.whatsComingUp =>
      isSpanish ? 'Qué viene' : "What's coming up",
    SIOneTapQuestion.fallingBehind =>
      isSpanish ? 'Qué estoy dejando atrás' : 'What am I falling behind on',
    SIOneTapQuestion.reachGoal =>
      isSpanish ? 'Ayúdame a lograr esta meta' : 'Help me reach this goal',
    SIOneTapQuestion.improveRoutine =>
      isSpanish ? 'Mejorar mi rutina' : 'Improve my routine',
    SIOneTapQuestion.explainPatterns =>
      isSpanish ? 'Explicar mis patrones' : 'Explain my patterns',
    SIOneTapQuestion.getBackOnTrack =>
      isSpanish ? 'Ayúdame a retomar el rumbo' : 'Help me get back on track',
    SIOneTapQuestion.reviewWeek =>
      isSpanish ? 'Revisar mi semana' : 'Review my week',
  };
}

/// What the on-device engine returns for one tapped question.
final class SIOneTapAnswer {
  const SIOneTapAnswer({
    required this.question,
    required this.response,
    this.offerAddSomething = false,
    this.offerAi = false,
  });

  final SIOneTapQuestion question;

  /// The same typed answer the free Chat card already shows: facts, what is
  /// missing and how certain.
  final SIV2Response response;

  /// The answer suggests adding something. The person is pointed to the
  /// existing Add something review step; nothing is added by the answer.
  final bool offerAddSomething;

  /// The device can say what the records show but cannot go further: a second,
  /// deliberate step offers AI chat with its price.
  final bool offerAi;
}
