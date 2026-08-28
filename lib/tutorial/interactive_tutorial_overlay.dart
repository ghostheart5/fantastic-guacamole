import 'dart:math' as math;

import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:flutter/material.dart';

const Color _tutorialScrimColor = Color(0x94050D1A);

/// A modal guide layer that leaves only its highlighted control interactive.
/// It is intentionally rendered above the real screen instead of embedding
/// instructional cards in the product layout.
class InteractiveTutorialOverlay extends StatefulWidget {
  const InteractiveTutorialOverlay({
    required this.targetKey,
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryEnabled = true,
    this.stepLabel,
    this.onSecondary,
    this.secondaryLabel,
    this.allowTargetInteraction = true,
    super.key,
  });

  final GlobalKey targetKey;
  final String title;
  final String body;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final bool primaryEnabled;
  final String? stepLabel;
  final VoidCallback? onSecondary;
  final String? secondaryLabel;
  final bool allowTargetInteraction;

  @override
  State<InteractiveTutorialOverlay> createState() =>
      _InteractiveTutorialOverlayState();
}

class _InteractiveTutorialOverlayState extends State<InteractiveTutorialOverlay>
    with SingleTickerProviderStateMixin {
  final GlobalKey _overlayKey = GlobalKey();
  Rect? _targetRect;
  late final AnimationController _pointerController;

  @override
  void initState() {
    super.initState();
    _pointerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);
    _revealTarget();
  }

  @override
  void didUpdateWidget(covariant InteractiveTutorialOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetKey != widget.targetKey) {
      _targetRect = null;
      _revealTarget();
    } else {
      _scheduleMeasurement();
    }
  }

  @override
  void dispose() {
    _pointerController.dispose();
    super.dispose();
  }

  void _revealTarget() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final BuildContext? targetContext = widget.targetKey.currentContext;
      if (!mounted || targetContext == null) {
        _scheduleMeasurement();
        return;
      }
      await Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        alignment: .5,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
      _scheduleMeasurement();
    });
  }

  void _scheduleMeasurement() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final RenderObject? targetObject = widget.targetKey.currentContext
          ?.findRenderObject();
      final RenderObject? overlayObject = _overlayKey.currentContext
          ?.findRenderObject();
      if (targetObject is! RenderBox ||
          overlayObject is! RenderBox ||
          !targetObject.hasSize ||
          !overlayObject.hasSize) {
        return;
      }
      final Offset overlayOrigin = overlayObject.localToGlobal(Offset.zero);
      final Offset targetOrigin =
          targetObject.localToGlobal(Offset.zero) - overlayOrigin;
      final Rect nextRect = targetOrigin & targetObject.size;
      if (_targetRect == nextRect) return;
      setState(() => _targetRect = nextRect);
    });
  }

  @override
  Widget build(BuildContext context) {
    _scheduleMeasurement();
    return Positioned.fill(
      child: LayoutBuilder(
        key: _overlayKey,
        builder: (BuildContext context, BoxConstraints constraints) {
          final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
          final Size size = Size(constraints.maxWidth, constraints.maxHeight);
          final double visibleHeight = math.max(
            160,
            size.height - keyboardInset,
          );
          // A Stack can receive transient zero or very narrow constraints while
          // its route is being installed. Defer spotlight geometry until every
          // inset range used below is valid; LayoutBuilder will rebuild as soon
          // as the real viewport constraints arrive.
          if (size.width < 64 || size.height < 64) {
            return const SizedBox.expand();
          }
          final Rect? measured = _targetRect;
          final Rect? target = measured == null
              ? null
              : Rect.fromLTRB(
                  (measured.left - 8).clamp(8, size.width - 8),
                  (measured.top - 8).clamp(8, visibleHeight - 8),
                  (measured.right + 8).clamp(8, size.width - 8),
                  (measured.bottom + 8).clamp(8, visibleHeight - 8),
                );

          return Stack(
            children: <Widget>[
              if (target == null)
                Positioned.fill(child: _blocker())
              else ...<Widget>[
                Positioned(
                  left: 0,
                  top: 0,
                  right: 0,
                  height: target.top,
                  child: _blocker(),
                ),
                Positioned(
                  left: 0,
                  top: target.top,
                  width: target.left,
                  height: target.height,
                  child: _blocker(),
                ),
                Positioned(
                  left: target.right,
                  top: target.top,
                  right: 0,
                  height: target.height,
                  child: _blocker(),
                ),
                Positioned(
                  left: 0,
                  top: target.bottom,
                  right: 0,
                  bottom: 0,
                  child: _blocker(),
                ),
                Positioned.fromRect(
                  rect: target,
                  child: IgnorePointer(
                    ignoring: widget.allowTargetInteraction,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.neonCyan, width: 2),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: AppColors.neonCyan.withValues(alpha: .45),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                _pointer(target, size.width, visibleHeight),
              ],
              _callout(target, size.width, visibleHeight),
            ],
          );
        },
      ),
    );
  }

  Widget _blocker() {
    return const AbsorbPointer(
      absorbing: true,
      child: ColoredBox(color: _tutorialScrimColor),
    );
  }

  Widget _pointer(Rect target, double width, double visibleHeight) {
    final bool placeBelow = target.bottom + 52 < visibleHeight;
    final double left = (target.center.dx - 18).clamp(8, width - 44);
    final double top = placeBelow
        ? target.bottom + 4
        : math.max(8, target.top - 44);
    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _pointerController,
          builder: (BuildContext context, Widget? child) {
            final double travel = placeBelow ? -6 : 6;
            return Transform.translate(
              offset: Offset(0, travel * _pointerController.value),
              child: child,
            );
          },
          child: Transform.rotate(
            angle: placeBelow ? 3.14 : 0,
            child: const Icon(
              Icons.touch_app_rounded,
              color: AppColors.memoryAmber,
              size: 36,
              shadows: <Shadow>[Shadow(color: Colors.black, blurRadius: 8)],
            ),
          ),
        ),
      ),
    );
  }

  Widget _callout(Rect? target, double width, double visibleHeight) {
    const double estimatedHeight = 190;
    final double calloutWidth = math.min(390, math.max(0, width - 24));
    final double left = (width - calloutWidth) / 2;
    final double top;
    if (target == null) {
      top = math.max(12, (visibleHeight - estimatedHeight) / 2);
    } else if (target.bottom + estimatedHeight + 20 <= visibleHeight) {
      top = target.bottom + 16;
    } else {
      top = math.max(12, target.top - estimatedHeight - 16);
    }

    return Positioned(
      left: left,
      top: top,
      width: calloutWidth,
      child: SafeArea(
        minimum: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: const Color(0xFF08131F),
          elevation: 18,
          shadowColor: AppColors.neonCyan.withValues(alpha: .35),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.neonCyan.withValues(alpha: .72),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (widget.stepLabel case final String label)
                  Text(
                    label.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.neonCyan,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                if (widget.stepLabel != null) const SizedBox(height: 6),
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.body,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: widget.primaryEnabled
                              ? widget.onPrimary
                              : null,
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: Text(widget.primaryLabel),
                        ),
                      ),
                    ),
                    if (widget.onSecondary != null) ...<Widget>[
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 48,
                        child: TextButton(
                          onPressed: widget.onSecondary,
                          child: Text(widget.secondaryLabel ?? 'Not now'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
