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
  );
});
