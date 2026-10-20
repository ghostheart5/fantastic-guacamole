import 'package:fantastic_guacamole/app/app_view.dart';
import 'package:fantastic_guacamole/app/router/app_route_registry.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:flutter/widgets.dart';

/// Locale-dependent presentation of canonical, locale-independent routes.
class NavigationCopy {
  const NavigationCopy(this.isSpanish);

  factory NavigationCopy.of(BuildContext context) =>
      NavigationCopy(ChronoSparkLocalizations.of(context).isSpanish);

  final bool isSpanish;

  String get openMap => isSpanish ? 'Ver herramientas' : 'Browse tools';
  String get closeMap => isSpanish ? 'Cerrar herramientas' : 'Close tools';
  String get mapTitle => isSpanish ? 'Herramientas' : 'Tools';
  String get railMapTitle => isSpanish ? 'Herramientas' : 'Tools';
  String get mapSubtitle => isSpanish
      ? 'Elige una herramienta para ver qué hace.'
      : 'Choose a tool to see what it does.';

  String label(AppRouteDefinition destination) => !isSpanish
      ? destination.label
      : switch (destination.appView) {
          AppView.nexus => 'Hoy',
          AppView.trajectoryEngine => 'Perspectivas',
          AppView.timeline => 'Mi plan',
          AppView.profile => 'Perfil',
          AppView.creator => 'Añadir algo',
          AppView.smartPlanner => 'Elegir un paso',
          AppView.console => 'Chat',
          AppView.progression => 'Actividad',
          AppView.settings => 'Ajustes',
          AppView.goals => 'Metas',
          null => destination.label,
        };

  String subtitle(AppRouteDefinition destination) => !isSpanish
      ? destination.navigationSubtitle ?? ''
      : switch (destination.appView) {
          AppView.nexus => 'Empieza aquí y elige qué te ayudaría hoy',
          AppView.trajectoryEngine =>
            'Revisa tus patrones, predicciones y resultados futuros',
          AppView.timeline => 'Encuentra tareas, metas, hábitos y tu agenda',
          AppView.profile => 'Ve tu nombre y tu actividad registrada',
          AppView.creator => 'Guarda una tarea, nota, meta o hábito',
          AppView.smartPlanner => 'Encuentra un próximo paso manejable',
          AppView.console => 'Pregunta sobre tus planes guardados',
          AppView.progression =>
            'Revisa tareas completadas y avances registrados',
          AppView.settings => 'Gestiona tu cuenta, privacidad y preferencias',
          AppView.goals => 'Metas y resultados',
          null => destination.navigationSubtitle ?? '',
        };
}
