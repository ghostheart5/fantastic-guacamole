import 'package:fantastic_guacamole/app/app_view.dart';
import 'package:fantastic_guacamole/app/router/app_route_registry.dart';
import 'package:fantastic_guacamole/app/router/route_access_policy.dart';
import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppRouteRegistry', () {
    test(
      'canonical identities are unique and every AppView is generated once',
      () {
        final List<String> paths = AppRouteRegistry.canonical
            .map((AppRouteDefinition route) => route.path)
            .toList(growable: false);
        final List<String> externalSlugs = AppRouteRegistry.canonical
            .map((AppRouteDefinition route) => route.externalSlug)
            .whereType<String>()
            .toList(growable: false);
        final List<AppRouteDefinition> generatedViews = AppRouteRegistry
            .canonical
            .where((AppRouteDefinition route) => route.generatesAppView)
            .toList(growable: false);

        expect(paths.toSet(), hasLength(paths.length));
        expect(externalSlugs.toSet(), hasLength(externalSlugs.length));
        expect(generatedViews, hasLength(AppView.values.length));
        expect(
          generatedViews
              .map((AppRouteDefinition route) => route.appView)
              .toSet(),
          AppView.values.toSet(),
        );

        for (final AppView view in AppView.values) {
          final AppRouteDefinition route = AppRouteRegistry.routeForView(view);
          expect(route.appView, view);
          expect(route.path, startsWith('/'));
          expect(route.label.trim(), isNotEmpty);
          expect(route.icon, isA<IconData>());
          expect(AppRouteRegistry.viewForPath(route.path), view);
        }
      },
    );

    test('Trajectory Engine has one exact destination identity', () {
      final AppRouteDefinition route = AppRouteRegistry.routeForView(
        AppView.trajectoryEngine,
      );

      expect(route.path, RoutePaths.trajectoryEngine);
      expect(route.label, 'Trajectory Engine');
      expect(route.icon, Icons.alt_route_rounded);
      expect(route.externalSlug, 'trajectory');
      expect(route.accessClass, RouteAccessClass.protectedApplication);
      expect(route.navigationGroup, AppNavigationGroup.primary);
      expect(route.navigationOrder, 1);
    });

    test('Profile and Settings remain separate exact destinations', () {
      final AppRouteDefinition profile = AppRouteRegistry.routeForView(
        AppView.profile,
      );
      final AppRouteDefinition settings = AppRouteRegistry.routeForView(
        AppView.settings,
      );

      expect(profile.path, RoutePaths.profile);
      expect(profile.label, 'Profile');
      expect(profile.icon, Icons.person_outline_rounded);
      expect(profile.externalSlug, 'profile');
      expect(profile.accessClass, RouteAccessClass.protectedApplication);
      expect(profile.navigationGroup, AppNavigationGroup.primary);

      expect(settings.path, RoutePaths.settings);
      expect(settings.label, 'Settings');
      expect(settings.icon, Icons.settings_outlined);
      expect(settings.externalSlug, 'settings');
      expect(settings.accessClass, RouteAccessClass.protectedApplication);
      expect(settings.navigationGroup, AppNavigationGroup.secondary);

      expect(profile.path, isNot(settings.path));
      expect(profile.appView, isNot(settings.appView));
    });

    test('navigation order and metadata come from canonical entries', () {
      final List<AppRouteDefinition> primary =
          AppRouteRegistry.navigationDestinations(
            AppNavigationGroup.primary,
          ).toList(growable: false);
      final List<AppRouteDefinition> secondary =
          AppRouteRegistry.navigationDestinations(
            AppNavigationGroup.secondary,
          ).toList(growable: false);

      expect(primary.map((AppRouteDefinition route) => route.label), <String>[
        'Nexus',
        'Trajectory Engine',
        'Timeline',
        'Profile',
      ]);
      expect(secondary.map((AppRouteDefinition route) => route.label), <String>[
        'Creator',
        'Smart Planner',
        'SI Console',
        'Progression',
        'Settings',
      ]);
      for (final AppRouteDefinition route in <AppRouteDefinition>[
        ...primary,
        ...secondary,
      ]) {
        expect(route.appView, isNotNull);
        expect(route.navigationSubtitle?.trim(), isNotEmpty);
      }
    });

    test('compatibility aliases are separate, valid, unique, and acyclic', () {
      final List<String> paths = AppRouteRegistry.compatibility
          .map((AppRouteCompatibility alias) => alias.path)
          .whereType<String>()
          .toList(growable: false);
      final List<String> externalSlugs = AppRouteRegistry.compatibility
          .map((AppRouteCompatibility alias) => alias.externalSlug)
          .whereType<String>()
          .toList(growable: false);
      final List<String> appViewNames = AppRouteRegistry.compatibility
          .map((AppRouteCompatibility alias) => alias.appViewName)
          .whereType<String>()
          .toList(growable: false);
      final List<String> allExternalSlugs = <String>[
        ...AppRouteRegistry.canonical
            .map((AppRouteDefinition route) => route.externalSlug)
            .whereType<String>(),
        ...externalSlugs,
      ];

      expect(paths.toSet(), hasLength(paths.length));
      expect(externalSlugs.toSet(), hasLength(externalSlugs.length));
      expect(allExternalSlugs.toSet(), hasLength(allExternalSlugs.length));
      expect(appViewNames.toSet(), hasLength(appViewNames.length));

      for (final AppRouteCompatibility alias
          in AppRouteRegistry.compatibility) {
        expect(AppRouteRegistry.routeForPath(alias.targetPath), isNotNull);
        expect(alias.path, isNot(alias.targetPath));
        if (alias.path case final String path) {
          expect(AppRouteRegistry.routeForPath(path), isNull);
          expect(
            AppRouteRegistry.accessClassForPath(path),
            AppRouteRegistry.accessClassForPath(alias.targetPath),
          );
        }
      }
    });

    test('compatibility path and external alias contracts remain exact', () {
      final Map<String, String> canonicalExternalRoutes = <String, String>{
        for (final AppRouteDefinition route in AppRouteRegistry.canonical)
          if (route.externalSlug != null) route.externalSlug!: route.path,
      };
      final Map<String, String> pathRedirects = <String, String>{
        for (final AppRouteCompatibility alias
            in AppRouteRegistry.compatibility)
          if (alias.path != null) alias.path!: alias.targetPath,
      };
      final Map<String, String> externalAliases = <String, String>{
        for (final AppRouteCompatibility alias
            in AppRouteRegistry.compatibility)
          if (alias.externalSlug != null) alias.externalSlug!: alias.targetPath,
      };
      final Set<String> routerRedirects = AppRouteRegistry
          .routerCompatibilityRedirects
          .map((AppRouteCompatibility alias) => alias.path!)
          .toSet();

      expect(canonicalExternalRoutes, <String, String>{
        'nexus': RoutePaths.nexus,
        'creator': RoutePaths.creator,
        'goals': RoutePaths.creatorGoals,
        'settings': RoutePaths.settings,
        'notifications': RoutePaths.notifications,
        'profile': RoutePaths.profile,
        'progression': RoutePaths.progression,
        'si-console': RoutePaths.si,
        'timeline': RoutePaths.timeline,
        'smart-planner': RoutePaths.smartPlanner,
        'trajectory': RoutePaths.trajectoryEngine,
        'paywall': RoutePaths.paywall,
        'privacy': RoutePaths.privacy,
        'delete-account': RoutePaths.deleteAccount,
        'terms': RoutePaths.terms,
        'support': RoutePaths.support,
        'about': RoutePaths.about,
      });

      expect(pathRedirects, <String, String>{
        RoutePaths.shell: RoutePaths.nexus,
        RoutePaths.home: RoutePaths.nexus,
        RoutePaths.plan: RoutePaths.timeline,
        RoutePaths.legacyLogs: RoutePaths.logs,
        RoutePaths.legacyNotifications: RoutePaths.notifications,
        RoutePaths.legacyProgression: RoutePaths.progression,
        RoutePaths.legacySi: RoutePaths.si,
        RoutePaths.legacyTasks: RoutePaths.tasks,
        RoutePaths.legacyProfile: RoutePaths.profile,
        RoutePaths.legacyInsights: RoutePaths.smartPlanner,
      });
      expect(externalAliases, <String, String>{
        'home': RoutePaths.nexus,
        'plan': RoutePaths.timeline,
        'temporal': RoutePaths.timeline,
        'logs': RoutePaths.logs,
        'si': RoutePaths.si,
      });
      expect(routerRedirects, <String>{
        RoutePaths.plan,
        RoutePaths.legacyLogs,
        RoutePaths.legacyNotifications,
        RoutePaths.legacyProgression,
        RoutePaths.legacySi,
        RoutePaths.legacyTasks,
        RoutePaths.legacyProfile,
        RoutePaths.legacyInsights,
      });
    });

    test('access contract is explicit and unknown paths fail closed', () {
      const Map<String, RouteAccessClass> expectedAccess =
          <String, RouteAccessClass>{
            RoutePaths.onboarding: RouteAccessClass.welcome,
            RoutePaths.login: RouteAccessClass.authentication,
            RoutePaths.nexus: RouteAccessClass.protectedApplication,
            RoutePaths.creator: RouteAccessClass.protectedApplication,
            RoutePaths.creatorGoals: RouteAccessClass.protectedApplication,
            RoutePaths.settings: RouteAccessClass.protectedApplication,
            RoutePaths.notifications: RouteAccessClass.protectedApplication,
            RoutePaths.logs: RouteAccessClass.protectedApplication,
            RoutePaths.tasks: RouteAccessClass.protectedApplication,
            RoutePaths.profile: RouteAccessClass.protectedApplication,
            RoutePaths.progression: RouteAccessClass.protectedApplication,
            RoutePaths.si: RouteAccessClass.protectedApplication,
            RoutePaths.advisor: RouteAccessClass.privilegedInternal,
            RoutePaths.timeline: RouteAccessClass.protectedApplication,
            RoutePaths.smartPlanner: RouteAccessClass.protectedApplication,
            RoutePaths.trajectoryEngine: RouteAccessClass.protectedApplication,
            RoutePaths.paywall: RouteAccessClass.commercial,
            RoutePaths.privacy: RouteAccessClass.publicInformation,
            RoutePaths.deleteAccount:
                RouteAccessClass.accountSensitiveInformation,
            RoutePaths.terms: RouteAccessClass.publicInformation,
            RoutePaths.support: RouteAccessClass.publicInformation,
            RoutePaths.about: RouteAccessClass.publicInformation,
          };

      expect(
        AppRouteRegistry.canonical
            .map((AppRouteDefinition route) => route.path)
            .toSet(),
        expectedAccess.keys.toSet(),
      );
      for (final MapEntry<String, RouteAccessClass> entry
          in expectedAccess.entries) {
        expect(
          AppRouteRegistry.accessClassForPath(entry.key),
          entry.value,
          reason: entry.key,
        );
        expect(
          RouteAccessPolicy.classify(entry.key).accessClass,
          entry.value,
          reason: entry.key,
        );
      }
      for (final AppRouteCompatibility alias
          in AppRouteRegistry.compatibility) {
        if (alias.path case final String path) {
          expect(
            AppRouteRegistry.accessClassForPath(path),
            expectedAccess[alias.targetPath],
            reason: path,
          );
        }
      }

      for (final String path in <String>[
        '/unknown-route',
        ' ${RoutePaths.privacy}',
        '${RoutePaths.privacy} ',
      ]) {
        final RouteAccessDecision unknown = RouteAccessPolicy.classify(path);
        expect(
          unknown.accessClass,
          RouteAccessClass.protectedApplication,
          reason: path,
        );
        expect(unknown.requiresAuthentication, isTrue, reason: path);
        expect(unknown.requiresCompletedOnboarding, isTrue, reason: path);
        expect(unknown.allowsSignedOutAccess, isFalse, reason: path);
        expect(
          unknown.reason,
          contains('Unknown routes fail closed'),
          reason: path,
        );
      }
    });
  });
}
