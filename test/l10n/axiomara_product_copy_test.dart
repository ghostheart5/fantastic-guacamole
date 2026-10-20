import 'package:fantastic_guacamole/app/app_view.dart';
import 'package:fantastic_guacamole/app/router/app_route_registry.dart';
import 'package:fantastic_guacamole/config/product_identity.dart';
import 'package:fantastic_guacamole/l10n/navigation_copy.dart';
import 'package:fantastic_guacamole/l10n/nexus_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('product identity describes reflection and planning', () {
    expect(ProductIdentity.name, 'Axiomara');
    expect(ProductIdentity.category, 'Reflection and planning');
    expect(ProductIdentity.legacyName, 'ChronoSpark');
  });

  test('Home names the next step and keeps the user-control boundary', () {
    const NexusCopy english = NexusCopy(false);
    const NexusCopy spanish = NexusCopy(true);

    expect(english.currentDecision, 'Suggested next step');
    expect(english.nextMove, contains('Review'));
    expect(english.loopControlNote, contains('You choose'));
    expect(english.realLifeSituations, hasLength(3));
    expect(english.checkInDisclosure, contains('after you reopen the app'));
    expect(english.checkInDisclosure, contains('Saved on this device'));

    expect(spanish.currentDecision, 'Próximo paso sugerido');
    expect(spanish.nextMove, contains('Revísalo'));
    expect(spanish.loopControlNote, contains('Tú eliges'));
    expect(spanish.realLifeSituations, hasLength(3));
    expect(spanish.checkInDisclosure, contains('vuelves a abrir'));
    expect(spanish.checkInDisclosure, contains('este dispositivo'));
    expect(english.momentumValue('BUILDING'), 'BUILDING');
    expect(spanish.momentumValue('BUILDING'), 'CRECIENDO');
  });

  test('all nine navigation surfaces use the same everyday names', () {
    const NavigationCopy english = NavigationCopy(false);
    const NavigationCopy spanish = NavigationCopy(true);
    final Map<AppView, String> expectedEnglish = <AppView, String>{
      AppView.nexus: 'Today',
      AppView.trajectoryEngine: 'Insights',
      AppView.timeline: 'My plan',
      AppView.profile: 'Profile',
      AppView.creator: 'Add something',
      AppView.smartPlanner: 'Choose a step',
      AppView.console: 'Chat',
      AppView.progression: 'Activity',
      AppView.settings: 'Settings',
    };
    final Map<AppView, String> expectedSpanish = <AppView, String>{
      AppView.nexus: 'Hoy',
      AppView.trajectoryEngine: 'Perspectivas',
      AppView.timeline: 'Mi plan',
      AppView.profile: 'Perfil',
      AppView.creator: 'Añadir algo',
      AppView.smartPlanner: 'Elegir un paso',
      AppView.console: 'Chat',
      AppView.progression: 'Actividad',
      AppView.settings: 'Ajustes',
    };

    for (final AppRouteDefinition route
        in AppRouteRegistry.visibleNavigationDestinations) {
      expect(english.label(route), expectedEnglish[route.appView]);
      expect(spanish.label(route), expectedSpanish[route.appView]);
    }
  });
}
