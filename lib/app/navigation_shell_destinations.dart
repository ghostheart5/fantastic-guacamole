part of 'navigation_shell.dart';

final List<AppRouteDefinition> _primaryDestinations =
    AppRouteRegistry.navigationDestinations(
      AppNavigationGroup.primary,
    ).toList(growable: false);

extension _NavigationShellDestinations on _NavigationShellState {
  bool _isPrimaryView(AppView view) =>
      AppRouteRegistry.routeForView(view).navigationGroup ==
      AppNavigationGroup.primary;

  Future<void> _restoreDefaultLaunchTab() async {
    final AppRecoveryState? recoveryState = await ref
        .read(appRecoveryProvider)
        .loadState();
    if (!mounted) {
      return;
    }
    final String? savedViewName = recoveryState?.lastPrimaryViewName;
    final AppView? recoveredView =
        AppRouteRegistry.viewForName(savedViewName) ??
        AppRouteRegistry.viewForPath(savedViewName);
    if (recoveredView != null && _isPrimaryView(recoveredView)) {
      _syncAppFlowToRouteView(recoveredView);
      _goToView(recoveredView);
      return;
    }

    final int? restoredTab = _preferenceService.getLastOpenedTab();
    final AppView restoredView =
        restoredTab == null || restoredTab < 0 || restoredTab > 3
        ? AppView.nexus
        : _viewForTabIndex(restoredTab);
    _syncAppFlowToRouteView(restoredView);
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
