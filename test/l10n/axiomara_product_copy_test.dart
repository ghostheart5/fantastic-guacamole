import 'package:fantastic_guacamole/app/app_view.dart';
import 'package:fantastic_guacamole/app/router/app_route_registry.dart';
import 'package:fantastic_guacamole/config/product_identity.dart';
import 'package:fantastic_guacamole/l10n/navigation_copy.dart';
import 'package:fantastic_guacamole/l10n/nexus_copy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/domain/strategic/si_console_shortcut_registry.dart';
import 'package:fantastic_guacamole/domain/entities/si_v2_contract.dart';

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

  test(
    'SI status keeps source counts and read-only limits with plain labels',
    () {
      for (final spanish in [false, true]) {
        final copy = SIRoutineCopy(spanish);
        final status = copy.statusReady(
          tasks: 2,
          goals: 3,
          milestones: 4,
          timeline: 5,
          unavailableSources: 1,
          revision: 'rev-fixture',
          aliases: '/timeline, /trajectory',
        );
        expect(
          status,
          contains(spanish ? 'Chat de solo lectura:' : 'Read-only Chat:'),
        );
        for (final value in [
          '2',
          '3',
          '4',
          '5',
          '1',
          'rev-fixture',
          '/timeline, /trajectory',
        ]) {
          expect(status, contains(value));
        }
        expect(status, isNot(contains('Evidence Lens')));
        final help = copy.shortcutHelp(filter: '');
        for (final old in ['/timeline', '/trajectory', '/progression']) {
          expect(help, isNot(contains(old)));
        }
        for (final current in ['/schedule', '/insights', '/activity']) {
          expect(help, contains(current));
        }
        expect(
          copy.shortcutLabel(
            SIConsoleShortcutRegistry.parse('/timeline').definition!,
          ),
          spanish ? 'Agenda' : 'Schedule',
        );
        expect(
          copy.shortcutLabel(
            SIConsoleShortcutRegistry.parse('/trajectory').definition!,
          ),
          spanish ? 'Perspectivas' : 'Insights',
        );
        expect(
          copy.shortcutLabel(
            SIConsoleShortcutRegistry.parse('/progression').definition!,
          ),
          spanish ? 'Actividad' : 'Activity',
        );
      }
      expect(SIV2Source.timeline.label, 'Schedule');
      expect(SIV2Source.timeline.name, 'timeline');
    },
  );

  test(
    'legacy app-authored actions render current English and Spanish names',
    () {
      const english = NexusCopy(false);
      const spanish = NexusCopy(true);
      const oldPlannerAction = 'Reconcile unscheduled work in Smart Planner.';
      expect(english.systemAction(oldPlannerAction), contains('Choose a step'));
      expect(
        spanish.systemAction(oldPlannerAction),
        contains('Elegir un paso'),
      );
      expect(
        spanish.systemAction('Capture one actionable task in Creator.'),
        contains('Añadir algo'),
      );
      const userTitle = 'Work on: My Smart Planner migration notes';
      expect(english.systemAction(userTitle), userTitle);
      expect(
        spanish.systemAction(userTitle),
        'Trabaja en: My Smart Planner migration notes',
      );
    },
  );

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
