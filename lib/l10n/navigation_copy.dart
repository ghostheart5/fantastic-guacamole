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
  String get mapTitle => isSpanish ? 'Mapa del sistema' : 'System Map';
  String get railMapTitle => isSpanish ? 'Mapa del sistema' : 'System map';
  String get mapSubtitle => isSpanish
      ? 'Un sistema humano: decide, actúa, observa y aprende.'
      : 'One human system: decide, act, observe and learn.';

  String label(AppRouteDefinition destination) => !isSpanish
      ? destination.label
      : switch (destination.appView) {
          AppView.nexus => 'Núcleo Nexus',
          AppView.trajectoryEngine => 'Ramas Futuras',
          AppView.timeline => 'Registro de Verdad',
          AppView.profile => 'Perfil Humano',
          AppView.creator => 'Constructor de Realidad',
          AppView.smartPlanner => 'Motor del Ahora',
          AppView.console => 'Inteligencia Profunda',
          AppView.progression => 'Matriz de Capacidades',
          AppView.settings => 'Centro de Control',
          AppView.goals => 'Metas',
          null => destination.label,
        };

  String subtitle(AppRouteDefinition destination) => !isSpanish
      ? destination.navigationSubtitle ?? ''
      : switch (destination.appView) {
          AppView.nexus => 'Decisiones, señales y control en vivo',
          AppView.trajectoryEngine =>
            'Compara caminos posibles sin fingir certeza',
          AppView.timeline =>
            'Recibos de decisiones, resultados e historial corregible',
          AppView.profile => 'Identidad, continuidad y capacidad',
          AppView.creator =>
            'Convierte intención en metas, tareas y contexto vinculados',
          AppView.smartPlanner =>
            'Resuelve límites reales en un movimiento ejecutable',
          AppView.console =>
            'Interroga contexto, evidencia y resultados posibles',
          AppView.progression =>
            'Descubre capacidades demostradas mediante la acción',
          AppView.settings =>
            'Controles de privacidad, memoria, inteligencia y cuenta',
          AppView.goals => 'Metas y resultados',
          null => destination.navigationSubtitle ?? '',
        };
}
