import 'package:fantastic_guacamole/tutorial/mission/mission_event_bridge.dart';
import 'package:fantastic_guacamole/tutorial/mission/mission_provider.dart';
import 'package:fantastic_guacamole/tutorial/mission/mission_state.dart';
import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MissionOverlay extends ConsumerStatefulWidget {
  const MissionOverlay({super.key});

  @override
  ConsumerState<MissionOverlay> createState() => _MissionOverlayState();
}

class _MissionOverlayState extends ConsumerState<MissionOverlay> {
  static const String _dismissedStorageKey = 'mission_zero_overlay_dismissed';

  bool _dismissScheduled = false;
  bool _dismissed = false;
  bool _dismissedLoaded = false;
  bool _expanded = true;
  bool _wasVisible = false;
  String _lastCheckSignature = '';

  @override
  void initState() {
    super.initState();
    _loadDismissedState();
  }

  Future<void> _loadDismissedState() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }
    setState(() {
      _dismissed = prefs.getBool(_dismissedStorageKey) ?? false;
      _dismissedLoaded = true;
    });
  }

  Future<void> _dismissOverlay({required String reason}) async {
    if (kDebugMode) {
      debugPrint('CHRONOSPARK_TUTORIAL_OVERLAY_REMOVE: reason=$reason');
    }
    if (mounted) {
      setState(() {
        _dismissed = true;
      });
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await SharedPrefsService.saveBoolWithPrefs(
      prefs,
      _dismissedStorageKey,
      true,
    );
  }

  bool _tutorialOverlayAllowedForRoute(String location) {
    return location == RoutePaths.home ||
        location == RoutePaths.creator ||
        location == RoutePaths.plan ||
        location == RoutePaths.insights ||
        location == RoutePaths.timeline;
  }

  String _currentLocation(BuildContext context) {
    final GoRouter? router = GoRouter.maybeOf(context);
    return router?.state.matchedLocation ?? '';
  }

  bool _modalRouteIsSafe(BuildContext context) {
    final ModalRoute<dynamic>? route = ModalRoute.of(context);
    final bool isCurrent = route?.isCurrent ?? true;
    final NavigatorState? rootNavigator = Navigator.maybeOf(
      context,
      rootNavigator: true,
    );
    final bool rootCanPop = rootNavigator?.canPop() ?? false;
    return isCurrent && !rootCanPop;
  }

  void _scheduleAutoDismissIfNeeded(MissionState state) {
    if (!state.isCompletionBannerActive || _dismissScheduled) {
      return;
    }
    _dismissScheduled = true;
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (!mounted) {
        return;
      }
      ref.read(missionEventBridgeProvider).dismissCompletionBanner();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = ref.watch(missionTutorialEnabledProvider);
    final String location = _currentLocation(context);
    final bool routeAllowed = _tutorialOverlayAllowedForRoute(location);
    final bool modalRouteIsSafe = _modalRouteIsSafe(context);
    final OnboardingStatus onboardingStatus = ref.watch(
      onboardingStatusProvider,
    );
    final bool creatorFirstItemCreated = ref.watch(
      creatorFirstItemCreatedProvider,
    );
    final bool timelineFirstActionCompleted = ref.watch(
      timelineFirstActionCompletedProvider,
    );
    final bool missionContextActive =
        onboardingStatus == OnboardingStatus.complete &&
        (!creatorFirstItemCreated || !timelineFirstActionCompleted);

    final String checkSignature =
        '$location|enabled=$enabled|dismissed=$_dismissed|routeAllowed=$routeAllowed|modalSafe=$modalRouteIsSafe|onboarding=$onboardingStatus|creatorFirst=$creatorFirstItemCreated|timelineFirst=$timelineFirstActionCompleted';
    if (kDebugMode && _lastCheckSignature != checkSignature) {
      _lastCheckSignature = checkSignature;
      debugPrint(
        'CHRONOSPARK_TUTORIAL_OVERLAY_CHECK: route=$location allowed=$routeAllowed dismissed=$_dismissed creatorFirstItem=$creatorFirstItemCreated timelineFirstAction=$timelineFirstActionCompleted',
      );
    }

    if (!enabled || !_dismissedLoaded) {
      return const SizedBox.shrink();
    }

    final AsyncValue<MissionState> stateAsync = ref.watch(missionStateProvider);

    return stateAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (MissionState state) {
        final MissionStep? activeMission = state.activeMission;
        final bool shouldShow =
            routeAllowed &&
            modalRouteIsSafe &&
            missionContextActive &&
            !_dismissed &&
            activeMission != null &&
            state.isVisible;

        if (!shouldShow) {
          String reason = 'unknown';
          if (!routeAllowed) {
            reason = 'route_not_allowed:$location';
          } else if (!modalRouteIsSafe) {
            reason = 'modal_or_dialog_open';
          } else if (!missionContextActive) {
            reason = 'mission_context_inactive';
          } else if (_dismissed) {
            reason = 'dismissed';
          } else if (activeMission == null || !state.isVisible) {
            reason = 'no_active_mission';
          }
          if (_wasVisible && kDebugMode) {
            debugPrint('CHRONOSPARK_TUTORIAL_OVERLAY_REMOVE: reason=$reason');
          } else if (kDebugMode) {
            debugPrint(
              'CHRONOSPARK_TUTORIAL_OVERLAY_SUPPRESSED: reason=$reason',
            );
          }
          _wasVisible = false;
          return const SizedBox.shrink();
        }

        _wasVisible = true;

        if (!state.isCompletionBannerActive) {
          _dismissScheduled = false;
        } else {
          _scheduleAutoDismissIfNeeded(state);
        }

        if (kDebugMode) {
          debugPrint(
            'CHRONOSPARK_TUTORIAL_OVERLAY_SHOW: route=$location step=${activeMission.id.name}',
          );
        }

        return Align(
          alignment: Alignment.bottomRight,
          child: SafeArea(
            minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: _expanded ? 360 : 148,
              constraints: const BoxConstraints(maxWidth: 360),
              decoration: BoxDecoration(
                color: const Color(0xEE08131F),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0x4D00E5FF)),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 14,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: _expanded
                  ? _HelperDrawerContent(
                      activeMission: activeMission,
                      isCompletionBannerActive: state.isCompletionBannerActive,
                      onCollapse: () {
                        setState(() {
                          _expanded = false;
                        });
                      },
                      onDismiss: () {
                        _dismissOverlay(reason: 'user_dismissed');
                      },
                      onDismissCompletion: () {
                        ref
                            .read(missionEventBridgeProvider)
                            .dismissCompletionBanner();
                      },
                    )
                  : _HelperDrawerCollapsed(
                      onExpand: () {
                        setState(() {
                          _expanded = true;
                        });
                      },
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _HelperDrawerContent extends StatelessWidget {
  const _HelperDrawerContent({
    required this.activeMission,
    required this.isCompletionBannerActive,
    required this.onCollapse,
    required this.onDismiss,
    required this.onDismissCompletion,
  });

  final MissionStep activeMission;
  final bool isCompletionBannerActive;
  final VoidCallback onCollapse;
  final VoidCallback onDismiss;
  final VoidCallback onDismissCompletion;

  String get _headline {
    return isCompletionBannerActive ? "You're Ready" : 'Need Help?';
  }

  String get _subhead {
    return isCompletionBannerActive ? 'Setup complete.' : activeMission.title;
  }

  bool get _advancedEnabled => isCompletionBannerActive;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Icon(
              Icons.help_outline_rounded,
              size: 18,
              color: Color(0xFF00E5FF),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _headline,
                    style: const TextStyle(
                      color: Color(0xFF00E5FF),
                      fontSize: 10,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _subhead,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Collapse',
              onPressed: onCollapse,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.white70,
              ),
            ),
            IconButton(
              tooltip: 'Dismiss',
              onPressed: onDismiss,
              icon: const Icon(Icons.close_rounded, color: Colors.white70),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _HelperDrawerSection(
          title: 'Build Your First Plan',
          body: 'Create a task, routine, goal, or note.',
          buttonLabel: 'Open Creator',
          onPressed: () => context.go(RoutePaths.creator),
        ),
        const SizedBox(height: 8),
        _HelperDrawerSection(
          title: 'View Timeline',
          body: 'See scheduled work and upcoming items.',
          buttonLabel: 'Open Timeline',
          onPressed: () => context.go(RoutePaths.timeline),
        ),
        const SizedBox(height: 8),
        _HelperDrawerSection(
          title: 'Smart Planner',
          body: _advancedEnabled
              ? 'Get recommendations and guidance.'
              : 'Available after setup is complete.',
          buttonLabel: 'Open Smart Planner',
          onPressed: _advancedEnabled
              ? () => context.go(RoutePaths.plan)
              : null,
        ),
        const SizedBox(height: 8),
        _HelperDrawerSection(
          title: 'SI Console',
          body: _advancedEnabled
              ? 'Ask questions about your plans and progress.'
              : 'Available after setup is complete.',
          buttonLabel: 'Open SI Console',
          onPressed: _advancedEnabled ? () => context.go(RoutePaths.si) : null,
        ),
        if (isCompletionBannerActive) ...<Widget>[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onDismissCompletion,
              child: const Text('Dismiss'),
            ),
          ),
        ],
      ],
    );
  }
}

class _HelperDrawerCollapsed extends StatelessWidget {
  const _HelperDrawerCollapsed({required this.onExpand});

  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onExpand,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.help_outline_rounded,
              size: 18,
              color: Color(0xFF00E5FF),
            ),
            SizedBox(width: 8),
            Text(
              'Need Help?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelperDrawerSection extends StatelessWidget {
  const _HelperDrawerSection({
    required this.title,
    required this.body,
    required this.buttonLabel,
    required this.onPressed,
  });

  final String title;
  final String body;
  final String buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.tonal(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: enabled
                  ? const Color(0x2200E5FF)
                  : const Color(0x14FFFFFF),
              foregroundColor: enabled
                  ? const Color(0xFF00E5FF)
                  : Colors.white54,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}
