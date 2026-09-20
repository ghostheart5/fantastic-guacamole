import 'package:fantastic_guacamole/app/app_view.dart';
import 'package:fantastic_guacamole/app/router/app_route_registry.dart';
import 'package:fantastic_guacamole/config/product_identity.dart';
import 'package:fantastic_guacamole/l10n/navigation_copy.dart';
import 'package:fantastic_guacamole/l10n/nexus_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'product identity distinguishes the human decision operating system',
    () {
      expect(ProductIdentity.name, 'Axiomara');
      expect(ProductIdentity.category, 'Human Decision OS');
      expect(ProductIdentity.legacyName, 'ChronoSpark');
    },
  );

  test('Nexus exposes the full decision packet and user-control boundary', () {
    const NexusCopy english = NexusCopy(false);
    const NexusCopy spanish = NexusCopy(true);

    expect(english.currentDecision, 'LIVE DECISION PACKET');
    expect(english.nextMove, contains('Uncertainty'));
    expect(english.loopControlNote, contains('Nothing changes'));
    expect(english.realLifeSituations, hasLength(3));
    expect(english.checkInDisclosure, contains('after you reopen the app'));
    expect(english.checkInDisclosure, contains('Saved on this device'));

    expect(spanish.currentDecision, 'PAQUETE DE DECISIÓN EN VIVO');
    expect(spanish.nextMove, contains('Incertidumbre'));
    expect(spanish.loopControlNote, contains('Nada cambia'));
    expect(spanish.realLifeSituations, hasLength(3));
    expect(spanish.checkInDisclosure, contains('vuelves a abrir'));
    expect(spanish.checkInDisclosure, contains('este dispositivo'));
    expect(english.momentumValue('BUILDING'), 'BUILDING');
    expect(spanish.momentumValue('BUILDING'), 'CRECIENDO');
  });

  test('all nine navigation surfaces use the new product language', () {
    const NavigationCopy english = NavigationCopy(false);
    const NavigationCopy spanish = NavigationCopy(true);
    final Map<AppView, String> expectedEnglish = <AppView, String>{
      AppView.nexus: 'Nexus Core',
      AppView.trajectoryEngine: 'Future Branches',
      AppView.timeline: 'Truth Ledger',
      AppView.profile: 'Human Profile',
      AppView.creator: 'Reality Builder',
      AppView.smartPlanner: 'Now Engine',
      AppView.console: 'Deep Intelligence',
      AppView.progression: 'Capability Matrix',
      AppView.settings: 'Control Center',
    };
    final Map<AppView, String> expectedSpanish = <AppView, String>{
      AppView.nexus: 'Núcleo Nexus',
      AppView.trajectoryEngine: 'Ramas Futuras',
      AppView.timeline: 'Registro de Verdad',
      AppView.profile: 'Perfil Humano',
      AppView.creator: 'Constructor de Realidad',
      AppView.smartPlanner: 'Motor del Ahora',
      AppView.console: 'Inteligencia Profunda',
      AppView.progression: 'Matriz de Capacidades',
      AppView.settings: 'Centro de Control',
    };

    for (final AppRouteDefinition route
        in AppRouteRegistry.visibleNavigationDestinations) {
      expect(english.label(route), expectedEnglish[route.appView]);
      expect(spanish.label(route), expectedSpanish[route.appView]);
    }
  });
}
