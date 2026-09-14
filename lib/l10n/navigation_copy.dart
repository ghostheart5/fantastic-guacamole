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

  String get openMap =>
      isSpanish ? 'Abrir mapa de navegación' : 'Open navigation map';
  String get closeMap =>
      isSpanish ? 'Cerrar mapa de navegación' : 'Close navigation map';
  String get mapTitle => isSpanish ? 'Mapa de navegación' : 'Navigation Map';
  String get railMapTitle =>
      isSpanish ? 'Mapa de navegación' : 'Navigation map';
  String get mapSubtitle => isSpanish
      ? 'Primero lo esencial; lo avanzado cuando lo necesites.'
      : 'Core first, advanced when needed.';

  String label(AppRouteDefinition destination) => !isSpanish
      ? destination.label
      : switch (destination.appView) {
          AppView.nexus => 'Nexus',
          AppView.trajectoryEngine => 'Motor de Trayectoria',
          AppView.timeline => 'Línea de Tiempo',
          AppView.profile => 'Perfil',
          AppView.creator => 'Creador',
          AppView.smartPlanner => 'Planificador Inteligente',
          AppView.console => 'Consola SI',
          AppView.progression => 'Progresión',
          AppView.settings => 'Configuración',
          AppView.goals => 'Metas',
          null => destination.label,
        };

  String subtitle(AppRouteDefinition destination) => !isSpanish
      ? destination.navigationSubtitle ?? ''
      : switch (destination.appView) {
          AppView.nexus => 'Inicio de planificación conectada',
          AppView.trajectoryEngine => 'Escenarios futuros y ejecución',
          AppView.timeline => 'Memoria de decisiones e historial de contexto',
          AppView.profile => 'Identidad y progreso',
          AppView.creator => 'Convierte tu intención en acciones conectadas',
          AppView.smartPlanner =>
            'Concilia tus límites para dar el próximo paso',
          AppView.console => 'Convierte el contexto en una decisión informada',
          AppView.progression =>
            'Descubre capacidades desarrolladas con la acción',
          AppView.settings => 'Preferencias y controles',
          AppView.goals => 'Metas y resultados',
          null => destination.navigationSubtitle ?? '',
        };
}
