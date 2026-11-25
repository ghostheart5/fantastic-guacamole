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
const GuidanceText _insights = GuidanceText('Insights', 'Perspectivas');
const GuidanceText _chat = GuidanceText('Chat', 'Chat');
const GuidanceText _chooseStep = GuidanceText(
  'Choose a step',
  'Elegir un paso',
);
const GuidanceText _activity = GuidanceText('Activity', 'Actividad');
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

/// The Help topic for a contextual hint: its title and plain text, where it
/// appears and how to get there. Null for a hint Help does not list.
HelpTopic? _hintTopic(GuidanceHint hint) {
  HelpTopic topic({
    required GuidanceText place,
    AppView? showMe,
    GuidanceText? whereToTap,
  }) => HelpTopic(
    id: 'hint-${hint.id.name}',
    title: hint.title,
    body: hint.body,
    place: place,
    whereToTap: whereToTap,
    showMe: showMe,
  );
  return switch (hint.id) {
    GuidanceLessonId.nexus => topic(place: _today, showMe: AppView.nexus),
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
      place: _activity,
      showMe: AppView.progression,
    ),
    GuidanceLessonId.habits => topic(
      place: _habits,
      showMe: AppView.nexus,
      whereToTap: _openHabits,
    ),
    GuidanceLessonId.goals => topic(place: _goals, showMe: AppView.goals),
    // Settings is where Help is opened from, so Back is the way there.
    GuidanceLessonId.notificationSettings => topic(
      place: _notificationSettings,
      whereToTap: _openNotificationSettings,
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
    AppView.progression => _activity,
    AppView.settings => const GuidanceText('Settings', 'Ajustes'),
    AppView.profile => const GuidanceText('Profile', 'Perfil'),
    AppView.creator => const GuidanceText('Add something', 'Añadir algo'),
  };

  static const HelpTopic today = HelpTopic(
    id: 'today',
    title: GuidanceText('What Today is for', 'Para qué sirve Hoy'),
    body: GuidanceText(
      'Today shows a few tasks to start with. From here you can add a goal, task or habit, open your goals, check in with a habit or ask in Chat.',
      'Hoy muestra algunas tareas por las que empezar. Desde aquí puedes añadir una meta, tarea o hábito, abrir tus metas, registrar un hábito o preguntar en Chat.',
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
      'Goals are the bigger things you are working toward. Give a goal a target date to get reminders before it is due.',
      'Las metas son lo más grande por lo que trabajas. Ponle una fecha límite a una meta para recibir avisos antes de que venza.',
    ),
    place: _goals,
    showMe: AppView.goals,
  );

  static const HelpTopic insights = HelpTopic(
    id: 'insights',
    title: GuidanceText('What Insights is for', 'Para qué sirve Perspectivas'),
    body: GuidanceText(
      'Insights shows patterns in what you recorded and estimates what may happen next. You can compare a different time, amount of work or priority before you change your plan.',
      'Perspectivas muestra patrones en lo que registraste y estima lo que puede pasar después. Puedes comparar otra hora, otra cantidad de trabajo u otra prioridad antes de cambiar tu plan.',
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
      'They turn reminders on or off, set how early task reminders come and set quiet hours. They also show whether reminders can reach this device.',
      'Activan o desactivan los recordatorios, fijan con cuánta antelación avisan las tareas y fijan las horas de silencio. También muestran si los recordatorios pueden llegar a este dispositivo.',
    ),
    place: _notificationSettings,
    whereToTap: _openNotificationSettings,
  );

  static const HelpTopic reminders = HelpTopic(
    id: 'reminders',
    title: GuidanceText(
      'How reminders work',
      'Cómo funcionan los recordatorios',
    ),
    body: GuidanceText(
      'A task gets one reminder at its start time, or when it is due if it has no start time. '
          'A goal with a target date is reminded at 9 AM three days before, the day before and on the day. '
          'A habit is reminded at the time and on the days you chose. '
          'Android can deliver a reminder several minutes late. '
          'During quiet hours, task and goal reminders wait until quiet hours end; habit times you chose are not moved.',
      'Una tarea recibe un recordatorio a su hora de inicio o, si no tiene, cuando vence. '
          'Una meta con fecha límite avisa a las 9:00 tres días antes, el día anterior y el mismo día. '
          'Un hábito avisa a la hora y los días que elegiste. '
          'Android puede entregar un recordatorio varios minutos tarde. '
          'Durante las horas de silencio, los avisos de tareas y metas esperan a que terminen; las horas de hábitos que elegiste no se mueven.',
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
      'Reminders appear only when notifications are on for Axiomara on this device and the Reminders switch is on. '
          'The top of the Notifications settings says whether reminders can reach you and what to change.',
      'Los recordatorios solo aparecen si las notificaciones de Axiomara están activadas en este dispositivo y el interruptor Recordatorios está activado. '
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
    reminders,
    remindersNotArriving,
    restartGuide,
  ].whereType<HelpTopic>().toList(growable: false);
}
