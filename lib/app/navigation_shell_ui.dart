part of 'navigation_shell.dart';

extension _NavigationShellUi on _NavigationShellState {
  Widget _buildTabbedBody(int tabIndex) {
    Widget tabAt(int index) {
      if (!_initializedTabIndexes.contains(index)) {
        return const SizedBox.shrink();
      }
      final AppView view = _viewForTabIndex(index);
      final Widget tab = switch (view) {
        AppView.trajectoryEngine => const TrajectoryEngineScreen(),
        AppView.timeline => const TimelineScreen(),
        AppView.profile => const ProfileScreen(),
        _ => const NexusScreen(),
      };
      final bool isActive = index == tabIndex;
      return TickerMode(
        enabled: isActive,
        child: ExcludeFocus(excluding: !isActive, child: tab),
      );
    }

    return IndexedStack(
      index: tabIndex,
      children: <Widget>[tabAt(0), tabAt(1), tabAt(2), tabAt(3)],
    );
  }

  Color _navigationAccent(int index) {
    return switch (index) {
      1 || 3 => AppColors.neonViolet,
      _ => AppColors.neonCyan,
    };
  }

  Widget _destinationIcon({
    required AppRouteDefinition destination,
    required bool selected,
    required Color accent,
    double size = 24,
  }) {
    return Icon(
      destination.icon,
      size: size,
      color: selected ? accent : const Color(0xFFA8B5CA),
    );
  }

  Widget _buildPhoneDestination(int index, int currentIndex) {
    final AppRouteDefinition destination = _primaryDestinations[index];
    final bool selected = index == currentIndex;
    final Color accent = _navigationAccent(index);

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: destination.label,
        child: Tooltip(
          message: destination.label,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _onTabSelected(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.all(2),
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                decoration: BoxDecoration(
                  color: selected
                      ? accent.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected
                        ? accent.withValues(alpha: 0.38)
                        : Colors.transparent,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    _destinationIcon(
                      destination: destination,
                      selected: selected,
                      accent: accent,
                      size: 25,
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        destination.label,
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          color: selected ? accent : const Color(0xFFA8B5CA),
                          fontSize: 11,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneNavigation(int currentIndex) {
    return SafeArea(
      key: const ValueKey<String>('phone-bottom-navigation'),
      top: false,
      minimum: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: TemporalGlassSurface(
        padding: const EdgeInsets.all(4),
        opacity: 0.94,
        blur: 18,
        child: SizedBox(
          height: 64,
          child: Row(
            children: <Widget>[
              for (int index = 0; index < _primaryDestinations.length; index++)
                _buildPhoneDestination(index, currentIndex),
              const SizedBox(width: 4),
              _buildPhoneMapAction(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRailDestination({
    required int index,
    required int currentIndex,
    required bool extended,
  }) {
    final AppRouteDefinition destination = _primaryDestinations[index];
    final bool selected = index == currentIndex;
    final Color accent = _navigationAccent(index);

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: Tooltip(
        message: destination.label,

        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _onTabSelected(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              height: 56,
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: extended ? 12 : 8),
              decoration: BoxDecoration(
                color: selected
                    ? accent.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected
                      ? accent.withValues(alpha: 0.38)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                mainAxisAlignment: extended
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: <Widget>[
                  _destinationIcon(
                    destination: destination,
                    selected: selected,
                    accent: accent,
                    size: 26,
                  ),
                  if (extended) ...<Widget>[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        destination.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected ? accent : const Color(0xFFA8B5CA),
                          fontSize: 14,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRailMapAction({required bool extended}) {
    return Semantics(
      button: true,
      label: 'Open navigation map',
      child: Tooltip(
        message: 'Open navigation map',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _showNavigationMap,
            child: SizedBox(
              height: 56,
              width: double.infinity,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: extended ? 12 : 8),
                child: Row(
                  mainAxisAlignment: extended
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
                  children: <Widget>[
                    const Icon(
                      Icons.map_outlined,
                      size: 26,
                      color: Color(0xFFA8B5CA),
                    ),
                    if (extended) ...<Widget>[
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Navigation map',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xFFA8B5CA),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationRail({
    required int currentIndex,
    required bool extended,
  }) {
    final double width = extended ? 224 : 72;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: SizedBox(
        width: width,
        height: double.infinity,
        child: TemporalGlassSurface(
          width: width,
          padding: const EdgeInsets.all(8),
          opacity: 0.94,
          blur: 18,
          child: SafeArea(
            child: Column(
              children: <Widget>[
                const SizedBox(height: 4),
                for (
                  int index = 0;
                  index < _primaryDestinations.length;
                  index++
                ) ...<Widget>[
                  _buildRailDestination(
                    index: index,
                    currentIndex: currentIndex,
                    extended: extended,
                  ),
                  if (index < _primaryDestinations.length - 1)
                    const SizedBox(height: 8),
                ],
                const Spacer(),
                Divider(
                  height: 17,
                  color: AppColors.panelBorder.withValues(alpha: 0.52),
                ),
                _buildRailMapAction(extended: extended),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneMapAction() {
    return TemporalGlassSurface(
      width: AppSizes.touchTarget,
      padding: EdgeInsets.zero,
      opacity: 0.94,
      blur: 18,
      child: SizedBox.square(
        dimension: AppSizes.touchTarget,
        child: IconButton(
          tooltip: 'Open navigation map',
          onPressed: _showNavigationMap,
          icon: const Icon(Icons.map_outlined),
          color: AppColors.neonCyan,
          style: IconButton.styleFrom(
            minimumSize: const Size.square(AppSizes.touchTarget),
            maximumSize: const Size.square(AppSizes.touchTarget),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryShell(int tabIndex) {
    final Widget tabbedBody = _buildTabbedBody(tabIndex);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 600) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: tabbedBody,
            bottomNavigationBar: _buildPhoneNavigation(tabIndex),
          );
        }

        final bool extended = constraints.maxWidth >= 1024;
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildNavigationRail(currentIndex: tabIndex, extended: extended),
              Expanded(child: tabbedBody),
            ],
          ),
        );
      },
    );
  }

  void _showNavigationMap() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.68),
      builder: (BuildContext context) {
        Widget navItem(AppRouteDefinition destination) {
          final AppView target = destination.appView!;
          final bool selected = target == widget.initialView;
          return ListTile(
            minVerticalPadding: 8,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            selected: selected,
            selectedColor: AppColors.neonCyan,
            selectedTileColor: AppColors.neonCyan.withValues(alpha: 0.08),
            leading: Icon(
              destination.icon,
              color: selected ? AppColors.neonCyan : const Color(0xFFA8B5CA),
            ),
            title: Text(
              destination.label,
              style: TextStyle(
                color: selected ? AppColors.neonCyan : Colors.white,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
            subtitle: Text(
              destination.navigationSubtitle ?? '',
              style: const TextStyle(
                color: Color(0xFFA8B5CA),
                letterSpacing: 0,
                height: 1.3,
              ),
            ),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFA8B5CA),
            ),
            onTap: () {
              Navigator.of(context).pop();
              _goToView(target);
            },
          );
        }

        final double maxHeight = MediaQuery.sizeOf(context).height * 0.86;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Center(
              heightFactor: 1,
              child: TemporalGlassSurface(
                width: 560,
                padding: EdgeInsets.zero,
                opacity: 0.96,
                blur: 20,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: Material(
                    color: Colors.transparent,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 14, 8, 10),
                          child: Row(
                            children: <Widget>[
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      'Navigation Map',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Core first, advanced when needed.',

                                      style: TextStyle(
                                        color: Color(0xFFA8B5CA),
                                        letterSpacing: 0,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Close navigation map',
                                onPressed: () => Navigator.of(context).pop(),
                                constraints: const BoxConstraints.tightFor(
                                  width: AppSizes.touchTarget,
                                  height: AppSizes.touchTarget,
                                ),
                                icon: const Icon(Icons.close_rounded),
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                        Divider(
                          height: 1,
                          color: AppColors.panelBorder.withValues(alpha: 0.52),
                        ),
                        Flexible(
                          child: ListView(
                            shrinkWrap: true,
                            padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                            children: <Widget>[
                              for (final AppRouteDefinition destination
                                  in _primaryDestinations)
                                navItem(destination),
                              Divider(
                                color: AppColors.panelBorder.withValues(
                                  alpha: 0.42,
                                ),
                              ),
                              for (final AppRouteDefinition destination
                                  in AppRouteRegistry.navigationDestinations(
                                    AppNavigationGroup.secondary,
                                  ))
                                navItem(destination),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
