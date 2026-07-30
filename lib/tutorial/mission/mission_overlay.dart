import 'package:fantastic_guacamole/tutorial/mission/mission_event_bridge.dart';
import 'package:fantastic_guacamole/tutorial/mission/mission_provider.dart';
import 'package:fantastic_guacamole/tutorial/mission/mission_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MissionOverlay extends ConsumerStatefulWidget {
  const MissionOverlay({super.key});

  @override
  ConsumerState<MissionOverlay> createState() => _MissionOverlayState();
}

class _MissionOverlayState extends ConsumerState<MissionOverlay> {
  bool _dismissScheduled = false;

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
    if (!enabled) {
      return const SizedBox.shrink();
    }

    final AsyncValue<MissionState> stateAsync = ref.watch(missionStateProvider);

    return stateAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (MissionState state) {
        if (!state.isCompletionBannerActive) {
          _dismissScheduled = false;
        } else {
          _scheduleAutoDismissIfNeeded(state);
        }

        final MissionStep? activeMission = state.activeMission;
        if (activeMission == null || !state.isVisible) {
          return const SizedBox.shrink();
        }

        return Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 560),
              decoration: BoxDecoration(
                color: const Color(0xEE08131F),
                borderRadius: BorderRadius.circular(14),
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
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.flag_rounded,
                    size: 18,
                    color: Color(0xFF00E5FF),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          state.isCompletionBannerActive
                              ? 'SETUP COMPLETE'
                              : 'FIRST SETUP',
                          style: const TextStyle(
                            color: Color(0xFF00E5FF),
                            fontSize: 10,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          activeMission.title,
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
                  if (state.isCompletionBannerActive)
                    TextButton(
                      onPressed: () {
                        ref
                            .read(missionEventBridgeProvider)
                            .dismissCompletionBanner();
                      },
                      child: const Text('Dismiss'),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
