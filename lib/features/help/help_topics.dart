import 'package:fantastic_guacamole/l10n/insights_copy.dart';
import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:fantastic_guacamole/tutorial/guidance_catalogue.dart';
import 'package:flutter/foundation.dart';

/// One short Help topic, in both languages. Help only shows these: reading a
/// topic never marks a hint as seen or finished.
@immutable
class HelpTopic {
  const HelpTopic({
    required this.id,
    required this.title,
    required this.body,
    this.place,
    this.whereToTap,
    this.showMe,
  });

  final String id;
  final GuidanceText title;
  final GuidanceText body;

  /// The screen or area the topic is about, named the way the control that
  /// opens it is named.
  final GuidanceText? place;

  /// How to reach a screen or area that has no route of its own.
  final GuidanceText? whereToTap;

  /// The screen "Show me" opens, or null when the topic has no such action.
  final AppView? showMe;

  /// Whether every word of [query] appears in the topic's text in the app
  /// language, ignoring case and accents. An empty query matches.
  bool matches(String query, {required bool spanish}) {
    final String text = _fold(
      <GuidanceText?>[
        title,
        place,
        body,
        whereToTap,
      ].whereType<GuidanceText>().map((t) => t.of(spanish: spanish)).join(' '),
    );
    return _fold(query)
        .split(RegExp(r'\s+'))
        .where((String word) => word.isNotEmpty)
        .every(text.contains);
  }
}

const String _accented = 'áàâäãåéèêëíìîïóòôöõúùûüñç';
const String _plain = 'aaaaaaeeeeiiiiooooouuuunc';

String _fold(String text) {
  final StringBuffer folded = StringBuffer();
  for (final int rune in text.toLowerCase().runes) {
    final String char = String.fromCharCode(rune);
    final int index = _accented.indexOf(char);
    folded.write(index < 0 ? char : _plain[index]);
  }
  return folded.toString();
}

const GuidanceText _today = GuidanceText('Today', 'Hoy');
const GuidanceText _myPlan = GuidanceText('My plan', 'Mi plan');
const GuidanceText _habits = GuidanceText('Habits', 'Hábitos');
const GuidanceText _goals = GuidanceText('Goals', 'Metas');
const GuidanceText _insights = GuidanceText(
  InsightsCopy.tabNameEn,
  InsightsCopy.tabNameEs,
);
const GuidanceText _chat = GuidanceText('Chat', 'Chat');
const GuidanceText _chooseStep = GuidanceText(
  'Choose a step',
  'Elegir un paso',
);
const GuidanceText _patternsPlace = GuidanceText(
  '${InsightsCopy.tabNameEn} › ${InsightsCopy.patternsEn}',
  '${InsightsCopy.tabNameEs} › ${InsightsCopy.patternsEs}',
);
const GuidanceText _patterns = GuidanceText(
  InsightsCopy.patternsEn,
  InsightsCopy.patternsEs,
);
const GuidanceText _notificationSettings = GuidanceText(
  'Settings › Notifications',
  'Ajustes › Notificaciones',
);
const GuidanceText _openNotificationSettings = GuidanceText(
  'In Settings, tap Notifications.',
  'En Ajustes, toca Notificaciones.',
);
const GuidanceText _openHabits = GuidanceText(
  'To open Habits, go to Today and tap Check in with a habit.',
  'Para abrir Hábitos, ve a Hoy y toca Registrar un hábito.',
);

/// The Help topic for a contextual hint: where it appears and how to get
/// there, with the hint's title and plain text unless [title] or [body] give
/// wording that stands on its own away from the hint's screen. Null for a
/// hint Help does not list.
HelpTopic? _hintTopic(GuidanceHint hint) {
  HelpTopic topic({
    required GuidanceText place,
    AppView? showMe,
    GuidanceText? whereToTap,
    GuidanceText? title,
    GuidanceText? body,
  }) => HelpTopic(
    id: 'hint-${hint.id.name}',
    title: title ?? hint.title,
    body: body ?? hint.body,
    place: place,
    whereToTap: whereToTap,
    showMe: showMe,
  );
  return switch (hint.id) {
    // The suggested step and its reasons are on the detailed view of Today.
    GuidanceLessonId.nexus => topic(
      place: _today,
      showMe: AppView.nexus,
      whereToTap: const GuidanceText(
        'On Today, tap Review my day in detail.',
        'En Hoy, toca Revisar mi día en detalle.',
      ),
    ),
    GuidanceLessonId.smartPlanner => topic(
      place: _chooseStep,
      showMe: AppView.smartPlanner,
    ),
    GuidanceLessonId.timelineExecution => topic(
      place: _myPlan,
      showMe: AppView.timeline,
    ),
    GuidanceLessonId.siConsole => topic(place: _chat, showMe: AppView.console),
    GuidanceLessonId.trajectoryEngine => topic(
      place: _insights,
      showMe: AppView.trajectoryEngine,
    ),
    GuidanceLessonId.progression => topic(
      place: _patternsPlace,
      showMe: AppView.progression,
    ),
    // The hint says "Mark here", which only makes sense on Habits itself.
    GuidanceLessonId.habits => topic(
      place: _habits,
      showMe: AppView.nexus,
      whereToTap: _openHabits,
      body: const GuidanceText(
        'A habit is something you repeat every day, week or month. On Habits, mark whether you did it this time. '
            'You can give a habit a reminder time when you add it, or later with Set reminder.',
        'Un hábito es algo que repites cada día, semana o mes. En Hábitos, marca si lo hiciste esta vez. '
            'Puedes ponerle una hora de recordatorio al añadirlo, o después con Poner recordatorio.',
      ),
    ),
    // The full goal reminder rule is in "How goal and habit reminders work".
    GuidanceLessonId.goals => topic(
      place: _goals,
      showMe: AppView.goals,
      body: const GuidanceText(
        'Give a goal a target date to get reminders before it is due and on the day itself. '
            'You can add or change the date when you edit the goal.',
        'Ponle una fecha límite a una meta para recibir avisos antes de que venza y el mismo día. '
            'Puedes añadir o cambiar la fecha al editar la meta.',
      ),
    ),
    // Settings is where Help is opened from, so Back is the way there. The
    // hint's title ("What these settings do") needs its own screen.
    GuidanceLessonId.notificationSettings => topic(
      place: _notificationSettings,
      whereToTap: _openNotificationSettings,
      title: const GuidanceText(
        'The Reminders switch, Task reminder time and Quiet hours',
        'El interruptor Recordatorios, Hora del recordatorio de tareas y Horas de silencio',
      ),
    ),
    // Its text is about the button on its own card; "If reminders do not
    // arrive" covers the same case here.
    GuidanceLessonId.remindersOff => null,
    // First-run guide steps are not hints.
    GuidanceLessonId.createFirstItem ||
    GuidanceLessonId.scheduleFirstItem ||
    GuidanceLessonId.reviewTimeline => null,
  };
}

/// Every Help topic, in the order shown: each screen's own topic is followed
/// by the hint about it.
abstract final class HelpTopics {
  /// The name of a screen "Show me" can open, as its navigation control
  /// names it.
  static GuidanceText screenName(AppView view) => switch (view) {
    AppView.nexus => _today,
    AppView.timeline => _myPlan,
    AppView.goals => _goals,
    AppView.trajectoryEngine => _insights,
    AppView.console => _chat,
    AppView.smartPlanner => _chooseStep,
    AppView.progression => _patterns,
    AppView.settings => const GuidanceText('Settings', 'Ajustes'),
    AppView.profile => const GuidanceText('Profile', 'Perfil'),
    AppView.creator => const GuidanceText('Add something', 'Añadir algo'),
  };

  static const HelpTopic today = HelpTopic(
    id: 'today',
    title: GuidanceText('What Today is for', 'Para qué sirve Hoy'),
    body: GuidanceText(
      'Today shows a few tasks to start with. On Today you can add a goal, task or habit, open Goals, check in with a habit, open Chat, open Insights for your patterns and future outcomes, or review your day in detail.',
      'Hoy muestra algunas tareas por las que empezar. En Hoy puedes añadir una meta, tarea o hábito, abrir Metas, registrar un hábito, abrir Chat, abrir Perspectivas para tus patrones y resultados futuros, o revisar tu día en detalle.',
    ),
    place: _today,
    showMe: AppView.nexus,
  );

  static const HelpTopic myPlan = HelpTopic(
    id: 'my-plan',
    title: GuidanceText('What My plan is for', 'Para qué sirve Mi plan'),
    body: GuidanceText(
      'My plan shows your schedule and the tasks, goals and habits you saved. Open a task to mark it done, move it or change its details.',
      'Mi plan muestra tu agenda y las tareas, metas y hábitos que guardaste. Abre una tarea para marcarla como hecha, moverla o cambiar sus detalles.',
    ),
    place: _myPlan,
    showMe: AppView.timeline,
  );

  static const HelpTopic habits = HelpTopic(
    id: 'habits',
    title: GuidanceText('What Habits is for', 'Para qué sirve Hábitos'),
    body: GuidanceText(
      'Habits lists the things you repeat every day, week or month. Mark whether you did each one this time, and give it a reminder time if you want one.',
      'Hábitos reúne lo que repites cada día, semana o mes. Marca si lo hiciste esta vez y ponle una hora de recordatorio si quieres.',
    ),
    place: _habits,
    whereToTap: _openHabits,
    showMe: AppView.nexus,
  );

  static const HelpTopic goals = HelpTopic(
    id: 'goals',
    title: GuidanceText('What Goals is for', 'Para qué sirve Metas'),
    body: GuidanceText(
      'Goals are the bigger things you are working toward. A goal can have a target date, and tasks linked to it count as its steps.',
      'Las metas son lo más grande por lo que trabajas. Una meta puede tener fecha límite, y las tareas vinculadas a ella cuentan como sus pasos.',
    ),
    place: _goals,
    showMe: AppView.goals,
  );

  static const HelpTopic insights = HelpTopic(
    id: 'insights',
    title: GuidanceText('What Insights is for', 'Para qué sirve Perspectivas'),
    body: GuidanceText(
      'Insights has two parts. Patterns shows what you recorded. Future outcomes shows estimates of what could happen next, and you can compare a different time, amount of work or priority before you change your plan.',
      'Perspectivas tiene dos partes. Patrones muestra lo que registraste. Resultados futuros muestra estimaciones de lo que podría pasar después, y puedes comparar otra hora, otra cantidad de trabajo u otra prioridad antes de cambiar tu plan.',
    ),
    place: _insights,
    showMe: AppView.trajectoryEngine,
  );

  static const HelpTopic chat = HelpTopic(
    id: 'chat',
    title: GuidanceText('What Chat is for', 'Para qué sirve Chat'),
    body: GuidanceText(
      'Ask questions about your saved tasks, goals and plans, and get suggestions based on them.',
      'Haz preguntas sobre tus tareas, metas y planes guardados y recibe sugerencias basadas en ellos.',
    ),
    place: _chat,
    showMe: AppView.console,
  );

  static const HelpTopic notificationSettings = HelpTopic(
    id: 'notification-settings',
    title: GuidanceText(
      'What Notifications settings are for',
      'Para qué sirven los ajustes de Notificaciones',
    ),
    body: GuidanceText(
      'They turn all reminders, or only task, goal or habit reminders, on or off. They also set how early task reminders come, overdue nudges and quiet hours, and show whether reminders can reach this device.',
      'Activan o desactivan todos los recordatorios, o solo los de tareas, metas o hábitos. También fijan con cuánta antelación avisan las tareas, los avisos de vencidos y las horas de silencio, y muestran si los recordatorios pueden llegar a este dispositivo.',
    ),
    place: _notificationSettings,
    whereToTap: _openNotificationSettings,
  );

  static const HelpTopic taskReminders = HelpTopic(
    id: 'task-reminders',
    title: GuidanceText(
      'How task reminders work',
      'Cómo funcionan los recordatorios de tareas',
    ),
    body: GuidanceText(
      'A task reminds you at its start time. Without one, it reminds you when it is due: at its time, or at 9 AM when the deadline has no time. '
          'If you chose a Task reminder time, such as 15 minutes before, the reminder comes that much earlier. '
          'With Overdue nudges on, a task still open the day after it was due gets one more reminder at 9 AM. '
          'Finished tasks stay quiet, and only the next 20 task reminders are set at once.',
      'Una tarea te avisa a su hora de inicio. Si no tiene, te avisa cuando vence: a su hora, o a las 9:00 si la fecha límite no tiene hora. '
          'Si elegiste una Hora del recordatorio de tareas, como 15 minutos antes, el aviso llega ese tiempo antes. '
          'Con Avisos de vencidos activado, una tarea que sigue pendiente el día después de vencer recibe otro aviso a las 9:00. '
          'Las tareas terminadas no avisan y solo se programan los 20 siguientes avisos de tareas a la vez.',
    ),
    place: _notificationSettings,
    whereToTap: _openNotificationSettings,
  );

  static const HelpTopic goalAndHabitReminders = HelpTopic(
    id: 'goal-habit-reminders',
    title: GuidanceText(
      'How goal and habit reminders work',
      'Cómo funcionan los recordatorios de metas y hábitos',
    ),
    body: GuidanceText(
      'A goal with a target date reminds you at 9 AM three days before, the day before and on the morning it is due. '
          'A goal due today that you add after 9 AM gets one reminder at 6 PM instead. '
          'With Overdue nudges on, a goal still open the day after its date gets one more at 9 AM. '
          'A goal also gets one "almost there" reminder when most of its steps are done. '
          'A habit reminds you at the time you set, on the days you chose. A habit without a time stays quiet.',
      'Una meta con fecha límite te avisa a las 9:00 tres días antes, el día anterior y la mañana en que vence. '
          'Si añades después de las 9:00 una meta que vence hoy, recibes un aviso a las 18:00. '
          'Con Avisos de vencidos activado, una meta que sigue pendiente el día después de su fecha recibe otro aviso a las 9:00. '
          'Una meta también recibe un aviso de "ya casi" cuando la mayoría de sus pasos estén hechos. '
          'Un hábito te avisa a la hora que le pusiste, los días que elegiste. Los hábitos sin hora no avisan.',
    ),
    place: _notificationSettings,
    whereToTap: _openNotificationSettings,
  );

  static const HelpTopic lateReminders = HelpTopic(
    id: 'late-reminders',
    title: GuidanceText(
      'Why a reminder can come late',
      'Por qué un recordatorio puede llegar tarde',
    ),
    body: GuidanceText(
      'Android can deliver a reminder several minutes late. '
          'During quiet hours, task and goal reminders, whose time the app picks, wait until quiet hours end. '
          'Times you chose yourself, such as habit times, are not moved.',
      'Android puede entregar un recordatorio varios minutos tarde. '
          'Durante las horas de silencio, los recordatorios de tareas y metas, cuya hora elige la aplicación, esperan a que terminen. '
          'Las horas que elegiste tú, como las de los hábitos, no se mueven.',
    ),
    place: _notificationSettings,
    whereToTap: _openNotificationSettings,
  );

  static const HelpTopic remindersNotArriving = HelpTopic(
    id: 'reminders-not-arriving',
    title: GuidanceText(
      'If reminders do not arrive',
      'Si no llegan los recordatorios',
    ),
    body: GuidanceText(
      'Reminders appear only when notifications are on for Axiomara on this device, the Reminders switch is on, and the switch for that kind is on: Task Reminders, Goal Reminders or Habit Reminders. '
          'A habit without a reminder time stays quiet. '
          'The top of the Notifications settings says whether reminders can reach you and what to change.',
      'Los recordatorios solo aparecen si las notificaciones de Axiomara están activadas en este dispositivo, el interruptor Recordatorios está activado y también el de ese tipo: Recordatorios de tareas, Recordatorios de metas o Recordatorios de ritmos. '
          'Los hábitos sin hora de recordatorio no avisan. '
          'La parte de arriba de los ajustes de Notificaciones dice si los recordatorios pueden llegarte y qué cambiar.',
    ),
    place: _notificationSettings,
    whereToTap: _openNotificationSettings,
  );

  static const HelpTopic restartGuide = HelpTopic(
    id: 'restart-guide',
    title: GuidanceText('Turn the guide back on', 'Volver a activar la guía'),
    body: GuidanceText(
      'If you skipped or paused the guide, restarting it shows its first steps again, starting on Today. Your saved work and activity stay as they are.',
      'Si omitiste o pausaste la guía, al reiniciarla vuelve a mostrar sus primeros pasos, empezando en Hoy. Tu trabajo y tu actividad guardados no cambian.',
    ),
    place: GuidanceText(
      'Settings › Planning & guidance',
      'Ajustes › Planificación y orientación',
    ),
    whereToTap: GuidanceText(
      'In Settings, open Planning & guidance and tap Restart Adaptive Guide.',
      'En Ajustes, abre Planificación y orientación y toca Reiniciar la Guía Adaptativa.',
    ),
  );

  static final List<HelpTopic> all = <HelpTopic?>[
    today,
    _hintTopic(GuidanceCatalogue.nexus),
    myPlan,
    _hintTopic(GuidanceCatalogue.timelineExecution),
    habits,
    _hintTopic(GuidanceCatalogue.habits),
    goals,
    _hintTopic(GuidanceCatalogue.goals),
    insights,
    _hintTopic(GuidanceCatalogue.trajectoryEngine),
    chat,
    _hintTopic(GuidanceCatalogue.siConsole),
    _hintTopic(GuidanceCatalogue.smartPlanner),
    _hintTopic(GuidanceCatalogue.progression),
    notificationSettings,
    _hintTopic(GuidanceCatalogue.notificationSettings),
    taskReminders,
    goalAndHabitReminders,
    lateReminders,
    remindersNotArriving,
    restartGuide,
  ].whereType<HelpTopic>().toList(growable: false);
}
