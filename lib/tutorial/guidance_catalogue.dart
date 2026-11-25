import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:flutter/foundation.dart';

enum GuidanceLessonId {
  createFirstItem,
  scheduleFirstItem,
  reviewTimeline,
  nexus,
  smartPlanner,
  timelineExecution,
  siConsole,
  trajectoryEngine,
  progression,
  habits,
  goals,
  remindersOff,
  notificationSettings,
}

enum GuidanceMilestone {
  firstItem,
  firstSchedule,
  firstTimelineReview,
  firstCompletion,
  firstTaskDeferral,
  firstNexusReview,
  firstPlannerQuestion,
  firstSiQuery,
  firstTrajectoryReview,
  firstProgressionReview,
  firstHabitCheckIn,
  firstGoalTargetDate,
  firstReminderSettingChange,
  guidanceDismissed,
  replayed,

  /// Recorded once when an account with its own tasks, habits or goals
  /// arrives on an install with no setup or guide state for it: the account
  /// already uses the app, so the first-run guide counts as done.
  returningAccount,
}

/// Where a contextual hint can appear that has no router path of its own.
/// These keys are never router paths, so a location can never match them.
abstract final class GuidancePlaces {
  /// The Habits screen, opened on top of Today, Add something or a
  /// notification. It declares this place itself.
  static const String habits = 'place:habits';

  /// The Notifications area of Settings, while it is open.
  static const String notificationSettings = 'place:settings-notifications';

  /// Whichever screen a reminder was just saved on.
  static const String whereReminderWasSaved = 'place:where-reminder-was-saved';

  /// A screen opened on top of another that has no hint of its own. Each
  /// such screen gets its own key, so leaving one for another ends a visit.
  static String undeclaredScreen(Object route) =>
      'place:screen-${identityHashCode(route)}';
}

/// Text in both languages.
@immutable
class GuidanceText {
  const GuidanceText(this.en, this.es);

  final String en;
  final String es;

  String of({required bool spanish}) => spanish ? es : en;
}

/// What a hint's single action does.
enum GuidanceActionKind {
  /// Names the hint's own screen. A card shown on that screen offers
  /// "Got it" instead, because the screen is already open.
  openScreen,

  /// Asks for notification permission in context, or opens device settings
  /// once the system has refused (the same step as the permission notice).
  turnOnNotifications,
}

@immutable
class GuidanceAction {
  const GuidanceAction(this.kind, this.label);

  final GuidanceActionKind kind;
  final GuidanceText label;
}

/// The real interaction that finishes a hint for the account. Showing a hint
/// also counts it as seen, so each one appears at most once.
@immutable
class GuidanceCompletion {
  /// Finished when any of [milestones] is recorded by a real action.
  const GuidanceCompletion.byMilestone(this.milestones) : byHintAction = false;

  /// Finished by doing what the hint's own action offers.
  const GuidanceCompletion.byHintAction()
    : milestones = const <GuidanceMilestone>{},
      byHintAction = true;

  final Set<GuidanceMilestone> milestones;
  final bool byHintAction;
}

/// One contextual hint: a small card shown once, on its own screen only.
@immutable
class GuidanceHint {
  const GuidanceHint({
    required this.id,
    required this.route,
    required this.title,
    required this.body,
    required this.completedBy,
    this.action,
  });

  final GuidanceLessonId id;

  /// The router path of the screen the hint describes, or a
  /// [GuidancePlaces] key for a screen or area without a path of its own.
  final String route;
  final GuidanceText title;
  final GuidanceText body;
  final GuidanceAction? action;
  final GuidanceCompletion completedBy;
}

/// Every contextual hint in the app, in both languages. The first-run guide
/// steps are not hints and are not listed here.
abstract final class GuidanceCatalogue {
  static const GuidanceHint nexus = GuidanceHint(
    id: GuidanceLessonId.nexus,
    route: RoutePaths.nexus,
    title: GuidanceText(
      'Review the suggested next step',
      'Revisa el próximo paso sugerido',
    ),
    body: GuidanceText(
      'Read why it was suggested and what is uncertain before deciding.',
      'Lee por qué se sugirió y qué es incierto antes de decidir.',
    ),
    action: GuidanceAction(
      GuidanceActionKind.openScreen,
      GuidanceText('Review Today', 'Revisar Hoy'),
    ),
    completedBy: GuidanceCompletion.byMilestone(<GuidanceMilestone>{
      GuidanceMilestone.firstNexusReview,
    }),
  );

  /// The Choose a step text when today's plan has a suggested change.
  static const GuidanceText smartPlannerSuggestedChange = GuidanceText(
    'Your plan has a suggested change for today. Ask about it, or type another question to get a suggestion.',
    'Tu plan tiene un cambio sugerido para hoy. Pregunta por él o escribe otra pregunta para recibir una sugerencia.',
  );

  /// Starts the Chat text when today's plan has a warning.
  static const GuidanceText planWarningLead = GuidanceText(
    'Your plan has a warning today.',
    'Tu plan tiene un aviso hoy.',
  );

  static const GuidanceHint smartPlanner = GuidanceHint(
    id: GuidanceLessonId.smartPlanner,
    route: RoutePaths.smartPlanner,
    title: GuidanceText('Ask for help with a plan', 'Pide ayuda con un plan'),
    body: GuidanceText(
      'Ask one clear question about the suggested task, what is holding it back, or what could move. Type a question to get a suggestion.',
      'Haz una pregunta clara sobre la tarea sugerida, lo que la frena o lo que podría moverse. Escribe una pregunta para recibir una sugerencia.',
    ),
    action: GuidanceAction(
      GuidanceActionKind.openScreen,
      GuidanceText('Ask for a next step', 'Pedir un próximo paso'),
    ),
    completedBy: GuidanceCompletion.byMilestone(<GuidanceMilestone>{
      GuidanceMilestone.firstPlannerQuestion,
    }),
  );

  static const GuidanceHint timelineExecution = GuidanceHint(
    id: GuidanceLessonId.timelineExecution,
    route: RoutePaths.timeline,
    title: GuidanceText('Record what happened', 'Registra lo que pasó'),
    body: GuidanceText(
      'Open a scheduled task. Mark it done, move it, or correct its details, then save your change.',
      'Abre una tarea con fecha. Márcala como hecha, muévela o corrige sus detalles y guarda el cambio.',
    ),
    action: GuidanceAction(
      GuidanceActionKind.openScreen,
      GuidanceText('Open My plan', 'Abrir Mi plan'),
    ),
    completedBy: GuidanceCompletion.byMilestone(<GuidanceMilestone>{
      GuidanceMilestone.firstCompletion,
      GuidanceMilestone.firstTaskDeferral,
    }),
  );

  /// Shown on the schedule instead of [timelineExecution] after a task was
  /// moved more than once.
  static const GuidanceHint timelineRecovery = GuidanceHint(
    id: GuidanceLessonId.timelineExecution,
    route: RoutePaths.timeline,
    title: GuidanceText(
      'Try a smaller step or a different time',
      'Prueba un paso más pequeño u otra hora',
    ),
    body: GuidanceText(
      'You moved this more than once. You can make it smaller, choose another time, or record what happened.',
      'Moviste esto más de una vez. Puedes hacerlo más pequeño, elegir otra hora o registrar lo que pasó.',
    ),
    action: GuidanceAction(
      GuidanceActionKind.openScreen,
      GuidanceText('Review in My plan', 'Revisar en Mi plan'),
    ),
    completedBy: GuidanceCompletion.byMilestone(<GuidanceMilestone>{
      GuidanceMilestone.firstCompletion,
      GuidanceMilestone.firstTaskDeferral,
    }),
  );

  static const GuidanceHint siConsole = GuidanceHint(
    id: GuidanceLessonId.siConsole,
    route: RoutePaths.siConsole,
    title: GuidanceText('Ask what is missing', 'Pregunta qué falta'),
    body: GuidanceText(
      'Ask what is missing from your plan, or what would change the suggestion. '
          'Free tools use no credits; questions to cloud AI show their price, up to 5 credits, before you confirm. Eligible free plans include 20 credits per month without rollover; check Settings for your allowance and reset date.',
      'Pregunta qué falta en tu plan o qué cambiaría la sugerencia. '
          'Las herramientas gratuitas no usan créditos; las preguntas a la IA en la nube muestran su precio, de hasta 5 créditos, antes de confirmar. Los planes gratuitos elegibles incluyen 20 créditos al mes sin acumulación; consulta tu asignación y fecha de renovación en Ajustes.',
    ),
    action: GuidanceAction(
      GuidanceActionKind.openScreen,
      GuidanceText('Ask in Chat', 'Preguntar en Chat'),
    ),
    completedBy: GuidanceCompletion.byMilestone(<GuidanceMilestone>{
      GuidanceMilestone.firstSiQuery,
    }),
  );

  static const GuidanceHint trajectoryEngine = GuidanceHint(
    id: GuidanceLessonId.trajectoryEngine,
    route: RoutePaths.trajectoryEngine,
    title: GuidanceText('Compare another option', 'Compara otra opción'),
    body: GuidanceText(
      'Try a different time, amount of work, or priority. Compare the estimate before changing your plan.',
      'Prueba otra hora, otra cantidad de trabajo u otra prioridad. Compara la estimación antes de cambiar tu plan.',
    ),
    action: GuidanceAction(
      GuidanceActionKind.openScreen,
      GuidanceText('Compare options', 'Comparar opciones'),
    ),
    completedBy: GuidanceCompletion.byMilestone(<GuidanceMilestone>{
      GuidanceMilestone.firstTrajectoryReview,
    }),
  );

  static const GuidanceHint progression = GuidanceHint(
    id: GuidanceLessonId.progression,
    route: RoutePaths.progression,
    title: GuidanceText('Review your activity', 'Revisa tu actividad'),
    body: GuidanceText(
      'See the tasks and milestones you recorded. Open the details to review them.',
      'Ve las tareas y los hitos que registraste. Abre los detalles para revisarlos.',
    ),
    action: GuidanceAction(
      GuidanceActionKind.openScreen,
      GuidanceText('Review activity', 'Revisar actividad'),
    ),
    completedBy: GuidanceCompletion.byMilestone(<GuidanceMilestone>{
      GuidanceMilestone.firstProgressionReview,
    }),
  );

  static const GuidanceHint habits = GuidanceHint(
    id: GuidanceLessonId.habits,
    route: GuidancePlaces.habits,
    title: GuidanceText('Your habits', 'Tus hábitos'),
    body: GuidanceText(
      'A habit is something you repeat every day, week or month. Mark here whether you did it this time. '
          'You can give a habit a reminder time when you add it, or later with Set reminder.',
      'Un hábito es algo que repites cada día, semana o mes. Marca aquí si lo hiciste esta vez. '
          'Puedes ponerle una hora de recordatorio al añadirlo, o después con Poner recordatorio.',
    ),
    completedBy: GuidanceCompletion.byMilestone(<GuidanceMilestone>{
      GuidanceMilestone.firstHabitCheckIn,
    }),
  );

  static const GuidanceHint goals = GuidanceHint(
    id: GuidanceLessonId.goals,
    route: RoutePaths.creatorGoals,
    title: GuidanceText(
      'Goals can have a date',
      'Las metas pueden tener fecha',
    ),
    body: GuidanceText(
      'Give a goal a target date to get reminders three days before, the day before and on the morning it is due. '
          'You can add or change the date when you edit the goal.',
      'Ponle una fecha límite a una meta para recibir avisos tres días antes, el día anterior y la mañana en que vence. '
          'Puedes añadir o cambiar la fecha al editar la meta.',
    ),
    completedBy: GuidanceCompletion.byMilestone(<GuidanceMilestone>{
      GuidanceMilestone.firstGoalTargetDate,
    }),
  );

  /// Shown the first time something with a reminder is saved while
  /// notifications are off and this account already said no to the request.
  static const GuidanceHint remindersOff = GuidanceHint(
    id: GuidanceLessonId.remindersOff,
    route: GuidancePlaces.whereReminderWasSaved,
    title: GuidanceText(
      'This reminder cannot reach you yet',
      'Este recordatorio aún no puede llegarte',
    ),
    body: GuidanceText(
      'Notifications are off for Axiomara, so reminders will not appear. '
          'Tap Turn on notifications, or go to Settings › Notifications later.',
      'Las notificaciones de Axiomara están desactivadas, así que los recordatorios no aparecerán. '
          'Toca Activar notificaciones o ve más tarde a Ajustes › Notificaciones.',
    ),
    action: GuidanceAction(
      GuidanceActionKind.turnOnNotifications,
      GuidanceText('Turn on notifications', 'Activar notificaciones'),
    ),
    completedBy: GuidanceCompletion.byHintAction(),
  );

  static const GuidanceHint notificationSettings = GuidanceHint(
    id: GuidanceLessonId.notificationSettings,
    route: GuidancePlaces.notificationSettings,
    title: GuidanceText('What these settings do', 'Qué hacen estos ajustes'),
    body: GuidanceText(
      'The Reminders switch turns every reminder on or off. '
          'Task reminder time sets how early a task reminds you. '
          'Quiet hours hold task and goal reminders until the quiet time ends.',
      'El interruptor Recordatorios activa o desactiva todos los recordatorios. '
          'Hora del recordatorio de tareas fija con cuánta antelación te avisa una tarea. '
          'Las horas de silencio retienen los avisos de tareas y metas hasta que terminan.',
    ),
    completedBy: GuidanceCompletion.byMilestone(<GuidanceMilestone>{
      GuidanceMilestone.firstReminderSettingChange,
    }),
  );

  /// One hint per contextual lesson.
  static const List<GuidanceHint> hints = <GuidanceHint>[
    nexus,
    smartPlanner,
    timelineExecution,
    siConsole,
    trajectoryEngine,
    progression,
    habits,
    goals,
    remindersOff,
    notificationSettings,
  ];

  /// Every hint, including the schedule's alternative wording.
  static const List<GuidanceHint> all = <GuidanceHint>[
    ...hints,
    timelineRecovery,
  ];

  static GuidanceHint? forLesson(GuidanceLessonId id) {
    for (final GuidanceHint hint in hints) {
      if (hint.id == id) return hint;
    }
    return null;
  }

  /// The hint about the screen or area at [place], if it has one.
  static GuidanceHint? forPlace(String place) {
    for (final GuidanceHint hint in hints) {
      if (hint.route == place) return hint;
    }
    return null;
  }

  /// The lesson a real action finishes, if any.
  static GuidanceLessonId? lessonCompletedBy(GuidanceMilestone milestone) {
    for (final GuidanceHint hint in hints) {
      if (hint.completedBy.milestones.contains(milestone)) return hint.id;
    }
    return null;
  }
}
