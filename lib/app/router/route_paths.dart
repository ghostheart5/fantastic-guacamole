class RoutePaths {
  static const shell = '/';

  // Entry and auth routes.
  static const onboarding = '/onboarding';
  static const login = '/login';

  // Primary navigation surfaces.
  static const home = '/home';
  static const plan = '/plan';
  static const creator = '/creator';
  static const insights = '/insights';
  static const settings = '/settings';

  // Secondary and advanced surfaces.
  static const notifications = '/settings/notifications';
  static const advancedRoot = '/settings/advanced';
  static const logs = '$advancedRoot/logs';
  static const tasks = '$advancedRoot/tasks';
  static const profile = '$advancedRoot/profile';
  static const progression = '$advancedRoot/progression';
  static const si = '$advancedRoot/si-console';

  // Legal and account routes.
  static const paywall = '/paywall';
  static const privacy = '/privacy';
  static const terms = '/terms';
  static const support = '/support';
  static const about = '/about';

  // Legacy aliases for compatibility redirects.
  static const legacyCoach = '/coach';
  static const legacyLogs = '/logs';
  static const legacyNotifications = '/notifications';
  static const legacyProgression = '/progression';
  static const legacySi = '/si';
  static const legacyTasks = '/tasks';
  static const legacyProfile = '/profile';
}
