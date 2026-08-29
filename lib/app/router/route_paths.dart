class RoutePaths {
  static const shell = '/';

  // Entry and auth routes.
  static const onboarding = '/onboarding';
  static const login = '/login';

  // Primary navigation surfaces.
  static const home = '/home';
  static const nexus = '/nexus';
  // Compatibility-only path. It redirects to Timeline and is never generated.
  static const plan = '/plan';
  static const creator = '/creator';
  static const settings = '/settings';

  // Secondary and advanced surfaces.
  static const notifications = '/settings/notifications';
  static const advancedRoot = '/settings/advanced';
  static const logs = '$advancedRoot/logs';
  static const tasks = '$advancedRoot/tasks';
  static const profile = '$advancedRoot/profile';
  static const progression = '$advancedRoot/progression';
  static const si = '$advancedRoot/si-console';
  static const advisor = '$advancedRoot/advisor';

  // Canonical routes and the aliases required by operating-system contracts.
  static const smartPlanner = '/smart-planner';
  static const siConsole = si;
  static const timeline = '/timeline';
  static const trajectoryEngine = '/trajectory';
  static const creatorGoals = '$creator/goals';

  // Legal and account routes.
  static const paywall = '/paywall';
  static const privacy = '/privacy';
  static const deleteAccount = '/delete-account';
  static const terms = '/terms';
  static const support = '/support';
  static const about = '/about';

  // Legacy aliases for compatibility redirects.
  static const legacyLogs = '/logs';
  static const legacyNotifications = '/notifications';
  static const legacyProgression = '/progression';
  static const legacySi = '/si';
  static const legacyTasks = '/tasks';
  static const legacyProfile = '/profile';
  static const legacyInsights = '/insights';
}
