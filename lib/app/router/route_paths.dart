class RoutePaths {
  static const shell = '/';

  // Entry and auth routes.
  static const bootstrap = '/bootstrap';
  static const sessionBlocked = '/session-blocked';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const unsupportedLink = '/unsupported-link';

  // Primary navigation surfaces.
  static const home = '/home';
  static const plan = '/plan';
  static const creator = '/creator';
  static const insights = '/insights';
  static const settings = '/settings';

  // Secondary and advanced surfaces.
  static const notifications = '/settings/notifications';
  static const notificationPermissionRecovery =
      '/settings/notifications/recovery';
  static const advancedRoot = '/settings/advanced';
  static const timeline = '/settings/advanced/logs';
  static const logs = '$advancedRoot/logs';
  static const tasks = '$advancedRoot/tasks';
  static const notes = '$advancedRoot/notes';
  static const profile = '$advancedRoot/profile';
  static const progression = '$advancedRoot/progression';
  static const si = '$advancedRoot/si-console';
  static const advisor = '$advancedRoot/advisor';
  static const completionEvents = '$advancedRoot/completion-events';

  // Legal and account routes.
  static const paywall = '/paywall';
  static const planComparison = '/paywall/compare';
  static const creditStore = '/paywall/credits';
  static const creditHistory = '/paywall/credits/history';
  static const subscriptionManagement = '/paywall/manage';
  static const privacy = '/privacy';
  static const deleteAccount = '/delete-account';
  static const terms = '/terms';
  static const support = '/support';
  static const about = '/about';

  // Legacy aliases for compatibility redirects.
  static const legacyCoach = '/coach';
  static const legacyTimeline = '/logs';
  static const legacyLogs = legacyTimeline;
  static const legacyNotifications = '/notifications';
  static const legacyProgression = '/progression';
  static const legacySi = '/si';
  static const legacyTasks = '/tasks';
  static const legacyProfile = '/profile';
}
