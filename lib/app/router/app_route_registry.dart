import 'package:fantastic_guacamole/app/app_view.dart';
import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:flutter/material.dart';

enum RouteAccessClass {
  welcome,
  authentication,
  publicInformation,
  accountSensitiveInformation,
  protectedApplication,
  commercial,
  privilegedInternal,
}

enum AppNavigationGroup { primary, secondary, hidden }

@immutable
class AppRouteDefinition {
  const AppRouteDefinition({
    required this.path,
    required this.label,
    required this.icon,
    required this.accessClass,
    this.appView,
    this.generatesAppView = false,
    this.externalSlug,
    this.navigationGroup = AppNavigationGroup.hidden,
    this.navigationOrder = 0,
    this.navigationSubtitle,
    this.allowSavedTabRestore = false,
  });

  final String path;
  final String label;
  final IconData icon;
  final RouteAccessClass accessClass;
  final AppView? appView;
  final bool generatesAppView;
  final String? externalSlug;
  final AppNavigationGroup navigationGroup;
  final int navigationOrder;
  final String? navigationSubtitle;
  final bool allowSavedTabRestore;
}

@immutable
class AppRouteCompatibility {
  const AppRouteCompatibility({
    required this.targetPath,
    this.path,
    this.externalSlug,
    this.appViewName,
    this.registerWithRouter = false,
  });

  final String targetPath;
  final String? path;
  final String? externalSlug;
  final String? appViewName;
  final bool registerWithRouter;
}

abstract final class AppRouteRegistry {
  static const List<AppRouteDefinition> canonical = <AppRouteDefinition>[
    AppRouteDefinition(
      path: RoutePaths.onboarding,
      label: 'Welcome',
      icon: Icons.waving_hand_outlined,
      accessClass: RouteAccessClass.welcome,
    ),
    AppRouteDefinition(
      path: RoutePaths.login,
      label: 'Sign in',
      icon: Icons.login_rounded,
      accessClass: RouteAccessClass.authentication,
    ),
    AppRouteDefinition(
      path: RoutePaths.nexus,
      label: 'Nexus',
      icon: Icons.hub_outlined,
      accessClass: RouteAccessClass.protectedApplication,
      appView: AppView.nexus,
      generatesAppView: true,
      externalSlug: 'nexus',
      navigationGroup: AppNavigationGroup.primary,
      navigationOrder: 0,
      navigationSubtitle: 'Connected planning home',
      allowSavedTabRestore: true,
    ),
    AppRouteDefinition(
      path: RoutePaths.creator,
      label: 'Creator',
      icon: Icons.add_task_rounded,
      accessClass: RouteAccessClass.protectedApplication,
      appView: AppView.creator,
      generatesAppView: true,
      externalSlug: 'creator',
      navigationGroup: AppNavigationGroup.secondary,
      navigationOrder: 0,
      navigationSubtitle: 'Turn intention into connected action',
    ),
    AppRouteDefinition(
      path: RoutePaths.creatorGoals,
      label: 'Goals',
      icon: Icons.flag_outlined,
      accessClass: RouteAccessClass.protectedApplication,
      appView: AppView.goals,
      generatesAppView: true,
      externalSlug: 'goals',
    ),
    AppRouteDefinition(
      path: RoutePaths.settings,
      label: 'Settings',
      icon: Icons.settings_outlined,
      accessClass: RouteAccessClass.protectedApplication,
      appView: AppView.settings,
      generatesAppView: true,
      externalSlug: 'settings',
      navigationGroup: AppNavigationGroup.secondary,
      navigationOrder: 4,
      navigationSubtitle: 'Preferences and controls',
    ),
    AppRouteDefinition(
      path: RoutePaths.notifications,
      label: 'Notifications',
      icon: Icons.notifications_outlined,
      accessClass: RouteAccessClass.protectedApplication,
      externalSlug: 'notifications',
    ),
    AppRouteDefinition(
      path: RoutePaths.logs,
      label: 'Logs',
      icon: Icons.history_rounded,
      accessClass: RouteAccessClass.protectedApplication,
      appView: AppView.timeline,
    ),
    AppRouteDefinition(
      path: RoutePaths.tasks,
      label: 'Tasks',
      icon: Icons.task_alt_rounded,
      accessClass: RouteAccessClass.protectedApplication,
      appView: AppView.creator,
    ),
    AppRouteDefinition(
      path: RoutePaths.profile,
      label: 'Profile',
      icon: Icons.person_outline_rounded,
      accessClass: RouteAccessClass.protectedApplication,
      appView: AppView.profile,
      generatesAppView: true,
      externalSlug: 'profile',
      navigationGroup: AppNavigationGroup.primary,
      navigationOrder: 3,
      navigationSubtitle: 'Identity and progression',
    ),
    AppRouteDefinition(
      path: RoutePaths.progression,
      label: 'Progression',
      icon: Icons.trending_up_rounded,
      accessClass: RouteAccessClass.protectedApplication,
      appView: AppView.progression,
      generatesAppView: true,
      externalSlug: 'progression',
      navigationGroup: AppNavigationGroup.secondary,
      navigationOrder: 3,
      navigationSubtitle: 'See capabilities built through action',
    ),
    AppRouteDefinition(
      path: RoutePaths.si,
      label: 'SI Console',
      icon: Icons.psychology_alt_outlined,
      accessClass: RouteAccessClass.protectedApplication,
      appView: AppView.console,
      generatesAppView: true,
      externalSlug: 'si-console',
      navigationGroup: AppNavigationGroup.secondary,
      navigationOrder: 2,
      navigationSubtitle: 'Turn context into a decision brief',
    ),
    AppRouteDefinition(
      path: RoutePaths.advisor,
      label: 'Product Advisor',
      icon: Icons.admin_panel_settings_outlined,
      accessClass: RouteAccessClass.privilegedInternal,
    ),
    AppRouteDefinition(
      path: RoutePaths.timeline,
      label: 'Timeline',
      icon: Icons.view_timeline_outlined,
      accessClass: RouteAccessClass.protectedApplication,
      appView: AppView.timeline,
      generatesAppView: true,
      externalSlug: 'timeline',
      navigationGroup: AppNavigationGroup.primary,
      navigationOrder: 2,
      navigationSubtitle: 'Decision memory and context history',
    ),
    AppRouteDefinition(
      path: RoutePaths.smartPlanner,
      label: 'Smart Planner',
      icon: Icons.event_note_outlined,
      accessClass: RouteAccessClass.protectedApplication,
      appView: AppView.smartPlanner,
      generatesAppView: true,
      externalSlug: 'smart-planner',
      navigationGroup: AppNavigationGroup.secondary,
      navigationOrder: 1,
      navigationSubtitle: 'Reconcile constraints into a next move',
    ),
    AppRouteDefinition(
      path: RoutePaths.trajectoryEngine,
      label: 'Trajectory Engine',
      icon: Icons.alt_route_rounded,
      accessClass: RouteAccessClass.protectedApplication,
      appView: AppView.trajectoryEngine,
      generatesAppView: true,
      externalSlug: 'trajectory',
      navigationGroup: AppNavigationGroup.primary,
      navigationOrder: 1,
      navigationSubtitle: 'Future scenarios and execution',
    ),
    AppRouteDefinition(
      path: RoutePaths.paywall,
      label: 'Plans and credits',
      icon: Icons.workspace_premium_outlined,
      accessClass: RouteAccessClass.commercial,
      externalSlug: 'paywall',
    ),
    AppRouteDefinition(
      path: RoutePaths.privacy,
      label: 'Privacy',
      icon: Icons.privacy_tip_outlined,
      accessClass: RouteAccessClass.publicInformation,
      externalSlug: 'privacy',
    ),
    AppRouteDefinition(
      path: RoutePaths.deleteAccount,
      label: 'Delete account',
      icon: Icons.person_remove_outlined,
      accessClass: RouteAccessClass.accountSensitiveInformation,
      externalSlug: 'delete-account',
    ),
    AppRouteDefinition(
      path: RoutePaths.terms,
      label: 'Terms',
      icon: Icons.gavel_outlined,
      accessClass: RouteAccessClass.publicInformation,
      externalSlug: 'terms',
    ),
    AppRouteDefinition(
      path: RoutePaths.support,
      label: 'Support',
      icon: Icons.support_agent_outlined,
      accessClass: RouteAccessClass.publicInformation,
      externalSlug: 'support',
    ),
    AppRouteDefinition(
      path: RoutePaths.about,
      label: 'About',
      icon: Icons.info_outline_rounded,
      accessClass: RouteAccessClass.publicInformation,
      externalSlug: 'about',
    ),
  ];

  static const List<AppRouteCompatibility> compatibility =
      <AppRouteCompatibility>[
        AppRouteCompatibility(
          path: RoutePaths.shell,
          targetPath: RoutePaths.nexus,
        ),
        AppRouteCompatibility(
          path: RoutePaths.home,
          externalSlug: 'home',
          targetPath: RoutePaths.nexus,
        ),
        AppRouteCompatibility(
          path: RoutePaths.plan,
          externalSlug: 'plan',
          appViewName: 'plan',
          targetPath: RoutePaths.timeline,
          registerWithRouter: true,
        ),
        AppRouteCompatibility(
          externalSlug: 'temporal',
          targetPath: RoutePaths.timeline,
        ),
        AppRouteCompatibility(
          path: RoutePaths.legacyLogs,
          externalSlug: 'logs',
          appViewName: 'logs',
          targetPath: RoutePaths.logs,
          registerWithRouter: true,
        ),
        AppRouteCompatibility(
          path: RoutePaths.legacyNotifications,
          targetPath: RoutePaths.notifications,
          registerWithRouter: true,
        ),
        AppRouteCompatibility(
          path: RoutePaths.legacyProgression,
          targetPath: RoutePaths.progression,
          registerWithRouter: true,
        ),
        AppRouteCompatibility(
          path: RoutePaths.legacySi,
          externalSlug: 'si',
          targetPath: RoutePaths.si,
          registerWithRouter: true,
        ),
        AppRouteCompatibility(
          path: RoutePaths.legacyTasks,
          appViewName: 'tasks',
          targetPath: RoutePaths.tasks,
          registerWithRouter: true,
        ),
        AppRouteCompatibility(
          path: RoutePaths.legacyProfile,
          targetPath: RoutePaths.profile,
          registerWithRouter: true,
        ),
        AppRouteCompatibility(
          path: RoutePaths.legacyInsights,
          targetPath: RoutePaths.smartPlanner,
          registerWithRouter: true,
        ),
        AppRouteCompatibility(
          appViewName: 'memories',
          targetPath: RoutePaths.timeline,
        ),
        AppRouteCompatibility(
          appViewName: 'milestones',
          targetPath: RoutePaths.timeline,
        ),
      ];

  static AppRouteDefinition? routeForPath(String? path) {
    final String target = path ?? '';
    for (final AppRouteDefinition route in canonical) {
      if (route.path == target) {
        return route;
      }
    }
    return null;
  }

  static AppRouteDefinition routeForView(AppView view) => canonical.singleWhere(
    (AppRouteDefinition route) =>
        route.generatesAppView && route.appView == view,
  );

  static AppView? viewForPath(String? path) {
    final String target = path?.trim() ?? '';
    final AppRouteDefinition? direct = routeForPath(target);
    if (direct?.appView case final AppView view) {
      return view;
    }
    for (final AppRouteCompatibility alias in compatibility) {
      if (alias.path == target) {
        return routeForPath(alias.targetPath)?.appView;
      }
    }
    return null;
  }

  static AppView? viewForName(String? name) {
    final String target = name?.trim() ?? '';
    if (target.isEmpty) {
      return null;
    }
    for (final AppView view in AppView.values) {
      if (view.name == target) {
        return view;
      }
    }
    for (final AppRouteCompatibility alias in compatibility) {
      if (alias.appViewName == target) {
        return routeForPath(alias.targetPath)?.appView;
      }
    }
    return null;
  }

  static AppRouteDefinition? routeForExternalSlug(String slug) {
    for (final AppRouteDefinition route in canonical) {
      if (route.externalSlug == slug) {
        return route;
      }
    }
    for (final AppRouteCompatibility alias in compatibility) {
      if (alias.externalSlug == slug) {
        return routeForPath(alias.targetPath);
      }
    }
    return null;
  }

  static RouteAccessClass? accessClassForPath(String path) {
    final AppRouteDefinition? direct = routeForPath(path);
    if (direct != null) {
      return direct.accessClass;
    }
    for (final AppRouteCompatibility alias in compatibility) {
      if (alias.path == path) {
        return routeForPath(alias.targetPath)?.accessClass;
      }
    }
    return null;
  }

  static bool isExternallyReachablePath(String path) {
    if (canonical.any(
      (AppRouteDefinition route) =>
          route.path == path && route.externalSlug != null,
    )) {
      return true;
    }
    return compatibility.any(
      (AppRouteCompatibility alias) =>
          alias.externalSlug != null && alias.targetPath == path,
    );
  }

  static Iterable<AppRouteCompatibility> get routerCompatibilityRedirects =>
      compatibility.where(
        (AppRouteCompatibility alias) =>
            alias.registerWithRouter && alias.path != null,
      );

  static Iterable<AppRouteDefinition> navigationDestinations(
    AppNavigationGroup group,
  ) {
    final List<AppRouteDefinition> routes =
        canonical
            .where((AppRouteDefinition route) => route.navigationGroup == group)
            .toList(growable: false)
          ..sort(
            (AppRouteDefinition a, AppRouteDefinition b) =>
                a.navigationOrder.compareTo(b.navigationOrder),
          );
    return routes;
  }

  static Iterable<AppRouteDefinition> get visibleNavigationDestinations sync* {
    yield* navigationDestinations(AppNavigationGroup.primary);
    yield* navigationDestinations(AppNavigationGroup.secondary);
  }
}
