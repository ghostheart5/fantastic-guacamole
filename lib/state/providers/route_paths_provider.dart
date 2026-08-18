import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RouteSurface {
  const RouteSurface({
    required this.onboarding,
    required this.login,
    required this.settings,
    required this.paywall,
    required this.privacy,
    required this.deleteAccount,
    required this.terms,
    required this.support,
    required this.advisor,
    required this.notifications,
    required this.nexus,
    required this.creator,
    required this.timeline,
    required this.smartPlanner,
    required this.siConsole,
    required this.trajectoryEngine,
    required this.progression,
  });

  final String onboarding;
  final String login;
  final String settings;
  final String paywall;
  final String privacy;
  final String deleteAccount;
  final String terms;
  final String support;
  final String advisor;
  final String notifications;
  final String nexus;
  final String creator;
  final String timeline;
  final String smartPlanner;
  final String siConsole;
  final String trajectoryEngine;
  final String progression;
}

final routeSurfaceProvider = Provider<RouteSurface>((_) {
  return const RouteSurface(
    onboarding: RoutePaths.onboarding,
    login: RoutePaths.login,
    settings: RoutePaths.settings,
    paywall: RoutePaths.paywall,
    privacy: RoutePaths.privacy,
    deleteAccount: RoutePaths.deleteAccount,
    terms: RoutePaths.terms,
    support: RoutePaths.support,
    advisor: RoutePaths.advisor,
    notifications: RoutePaths.notifications,
    nexus: RoutePaths.nexus,
    creator: RoutePaths.creator,
    timeline: RoutePaths.timeline,
    smartPlanner: RoutePaths.smartPlanner,
    siConsole: RoutePaths.siConsole,
    trajectoryEngine: RoutePaths.trajectoryEngine,
    progression: RoutePaths.progression,
  );
});
