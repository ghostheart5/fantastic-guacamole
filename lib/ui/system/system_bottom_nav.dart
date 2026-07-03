import 'dart:async';

import 'package:fantastic_guacamole/core/services/feedback_service.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/ui/widgets/app_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SystemNavItem {
  const SystemNavItem({required this.label, this.iconData, this.svgAsset})
    : assert(iconData != null || svgAsset != null);

  final String label;
  final IconData? iconData;
  final String? svgAsset;
}

class SystemBottomNav extends ConsumerWidget {
  const SystemBottomNav({
    required this.items,
    required this.currentIndex,
    required this.onTap,
    super.key,
  });

  final List<SystemNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool soundEnabled = ref.watch(soundEnabledProvider);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
        child: Row(
          children: List<Widget>.generate(items.length, (int index) {
            final bool selected = currentIndex == index;
            final Color color = selected
                ? const Color(0xFFECE8F9)
                : const Color(0xFFB6AEC4);
            final String? svgAsset = items[index].svgAsset;

            return Expanded(
              child: Semantics(
                button: true,
                selected: selected,
                label: '${items[index].label} tab',
                child: InkWell(
                  onTap: () => unawaited(
                    FeedbackService.tapThenAction(
                      () => onTap(index),
                      soundEnabled: soundEnabled,
                    ),
                  ),
                  borderRadius: BorderRadius.circular(22),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: AnimatedSlide(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      offset: selected ? const Offset(0, -0.06) : Offset.zero,
                      child: SizedBox(
                        height: 88,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Stack(
                              alignment: Alignment.center,
                              children: <Widget>[
                                if (selected)
                                  Container(
                                    width: 68,
                                    height: 68,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: <Color>[
                                          Color(0x66C2A7FF),
                                          Color(0x2262E0FF),
                                          Color(0x00000000),
                                        ],
                                        stops: <double>[0.0, 0.7, 1.0],
                                      ),
                                    ),
                                  ),
                                AnimatedScale(
                                  duration: const Duration(milliseconds: 180),
                                  curve: Curves.easeOut,
                                  scale: selected ? 1.09 : 1,
                                  child: svgAsset != null
                                      ? AppIcon(
                                          svgAsset,
                                          size: 28,
                                          color: color,
                                        )
                                      : Icon(
                                          items[index].iconData,
                                          size: 28,
                                          color: color,
                                        ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              items[index].label,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.0,
                                color: color,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
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
          }),
        ),
      ),
    );
  }
}
