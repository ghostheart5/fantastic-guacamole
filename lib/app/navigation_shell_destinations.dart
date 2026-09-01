part of 'navigation_shell.dart';

final List<AppRouteDefinition> _primaryDestinations =
    AppRouteRegistry.navigationDestinations(
      AppNavigationGroup.primary,
    ).toList(growable: false);

extension _NavigationShellDestinations on _NavigationShellState {
  bool _isPrimaryView(AppView view) =>
      AppRouteRegistry.routeForView(view).navigationGroup ==
      AppNavigationGroup.primary;

  void _restoreDefaultLaunchTab() {
    final int? restoredTab = _preferenceService.getLastOpenedTab();
    final AppView restoredView =
        restoredTab == null || restoredTab < 0 || restoredTab > 3
        ? AppView.nexus
        : _viewForTabIndex(restoredTab);
    _goToView(restoredView);
  }

  int _tabIndexForView(AppView view) {
    final AppRouteDefinition route = AppRouteRegistry.routeForView(view);
    return route.navigationGroup == AppNavigationGroup.primary
        ? route.navigationOrder
        : 0;
  }

  AppView _viewForTabIndex(int index) {
    if (index < 0 || index >= _primaryDestinations.length) {
      return AppView.nexus;
    }
    return _primaryDestinations[index].appView!;
  }

  void _onTabSelected(int index) {
    _initializedTabIndexes.add(index);
    _runBackgroundTask(
      'primary tab preference save',
      () => _preferenceService.setLastOpenedTab(index),
    );
    _goToView(_viewForTabIndex(index));
  }
}
