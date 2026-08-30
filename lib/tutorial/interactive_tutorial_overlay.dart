import 'dart:math' as math;

import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

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
  final FocusNode _primaryFocusNode = FocusNode(
    debugLabel: 'Tutorial primary action',
  );
  final FocusNode _secondaryFocusNode = FocusNode(
    debugLabel: 'Tutorial secondary action',
  );
  late final FocusScopeNode _calloutFocusScope;
  Rect? _targetRect;
  FocusNode? _focusBeforeOverlay;
  late final AnimationController _pointerController;
  bool _reduceMotion = false;
  bool _focusScheduled = false;
  bool _movedFocus = false;

  @override
  void initState() {
    super.initState();
    _calloutFocusScope = FocusScopeNode(
      debugLabel: 'Tutorial callout scope',
      traversalEdgeBehavior: widget.allowTargetInteraction
          ? TraversalEdgeBehavior.parentScope
          : TraversalEdgeBehavior.closedLoop,
    );
    _pointerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _revealTarget();
    _scheduleModalFocus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final MediaQueryData? media = MediaQuery.maybeOf(context);
    final bool reduceMotion =
        (media?.disableAnimations ?? false) ||
        (media?.accessibleNavigation ?? false);
    if (_reduceMotion == reduceMotion) {
      if (!reduceMotion && !_pointerController.isAnimating) {
        _pointerController.repeat(reverse: true);
      }
      return;
    }
    _reduceMotion = reduceMotion;
    if (reduceMotion) {
      _pointerController
        ..stop()
        ..value = 0;
    } else {
      _pointerController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant InteractiveTutorialOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _calloutFocusScope.traversalEdgeBehavior = widget.allowTargetInteraction
        ? TraversalEdgeBehavior.parentScope
        : TraversalEdgeBehavior.closedLoop;
    if (oldWidget.targetKey != widget.targetKey) {
      _targetRect = null;
      _revealTarget();
    } else {
      _scheduleMeasurement();
    }
    if (oldWidget.allowTargetInteraction != widget.allowTargetInteraction ||
        oldWidget.primaryEnabled != widget.primaryEnabled ||
        oldWidget.onSecondary != widget.onSecondary) {
      _scheduleModalFocus();
    }
  }

  @override
  void dispose() {
    final FocusNode? priorFocus = _focusBeforeOverlay;
    if (_movedFocus &&
        priorFocus != null &&
        priorFocus.context != null &&
        priorFocus.canRequestFocus) {
      priorFocus.requestFocus();
    }
    _primaryFocusNode.dispose();
    _secondaryFocusNode.dispose();
    _calloutFocusScope.dispose();
    _pointerController.dispose();
    super.dispose();
  }

  void _scheduleModalFocus() {
    if (_focusScheduled || widget.allowTargetInteraction) return;
    _focusScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusScheduled = false;
      if (!mounted || widget.allowTargetInteraction) return;
      _focusBeforeOverlay ??= FocusManager.instance.primaryFocus;
      final FocusNode focusTarget = widget.primaryEnabled
          ? _primaryFocusNode
          : widget.onSecondary != null
          ? _secondaryFocusNode
          : _calloutFocusScope;
      if (focusTarget.canRequestFocus && !focusTarget.hasFocus) {
        focusTarget.requestFocus();
        _movedFocus = true;
      }
    });
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
        duration: _reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 320),
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
          final EdgeInsets safePadding = MediaQuery.paddingOf(context);
          final Size size = Size(constraints.maxWidth, constraints.maxHeight);
          final double visibleHeight = (size.height - keyboardInset).clamp(
            0,
            size.height,
          );
          // A Stack can receive transient zero or very narrow constraints while
          // its route is being installed. Defer spotlight geometry until every
          // inset range used below is valid; LayoutBuilder will rebuild as soon
          // as the real viewport constraints arrive.
          if (size.width < 64 || visibleHeight < 64) {
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
              _callout(target, size.width, visibleHeight, safePadding),
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
    final Widget pointer = Transform.rotate(
      angle: placeBelow ? 3.14 : 0,
      child: const Icon(
        Icons.touch_app_rounded,
        color: AppColors.memoryAmber,
        size: 36,
        shadows: <Shadow>[Shadow(color: Colors.black, blurRadius: 8)],
      ),
    );
    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: _reduceMotion
            ? pointer
            : AnimatedBuilder(
                animation: _pointerController,
                builder: (BuildContext context, Widget? child) {
                  final double travel = placeBelow ? -6 : 6;
                  return Transform.translate(
                    offset: Offset(0, travel * _pointerController.value),
                    child: child,
                  );
                },
                child: pointer,
              ),
      ),
    );
  }

  Widget _callout(
    Rect? target,
    double width,
    double visibleHeight,
    EdgeInsets safePadding,
  ) {
    const double margin = 12;
    const double targetGap = 16;
    final double usableLeft = math.max(margin, safePadding.left + margin);
    final double usableRight = math.max(
      usableLeft,
      width - math.max(margin, safePadding.right + margin),
    );
    final double usableTop = math.min(
      visibleHeight,
      math.max(margin, safePadding.top + margin),
    );
    final double usableBottom = math.max(
      usableTop,
      visibleHeight - math.max(margin, safePadding.bottom + margin),
    );
    final double calloutWidth = math.min(390, usableRight - usableLeft);
    final double left =
        usableLeft + (usableRight - usableLeft - calloutWidth) / 2;

    double regionTop = usableTop;
    double regionBottom = usableBottom;
    Alignment alignment = Alignment.center;
    if (target != null) {
      final double belowTop = (target.bottom + targetGap).clamp(
        usableTop,
        usableBottom,
      );
      final double aboveBottom = (target.top - targetGap).clamp(
        usableTop,
        usableBottom,
      );
      final double belowHeight = usableBottom - belowTop;
      final double aboveHeight = aboveBottom - usableTop;
      if (belowHeight >= aboveHeight) {
        regionTop = belowTop;
        alignment = Alignment.topCenter;
      } else {
        regionBottom = aboveBottom;
        alignment = Alignment.bottomCenter;
      }
    }
    final double regionHeight = regionBottom - regionTop;
    if (calloutWidth <= 0 || regionHeight <= 0) {
      return const SizedBox.shrink();
    }

    final String semanticsLabel = <String>[
      if (widget.stepLabel case final String label) label,
      widget.title,
    ].join('. ');
    final Map<ShortcutActivator, VoidCallback> shortcuts =
        widget.onSecondary == null
        ? const <ShortcutActivator, VoidCallback>{}
        : <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.escape):
                widget.onSecondary!,
          };

    return Positioned(
      left: left,
      top: regionTop,
      width: calloutWidth,
      height: regionHeight,
      child: Align(
        alignment: alignment,
        child: Semantics(
          key: const Key('tutorial_callout_semantics'),
          container: true,
          explicitChildNodes: true,
          scopesRoute: true,
          namesRoute: true,
          liveRegion: true,
          role: SemanticsRole.dialog,
          label: semanticsLabel,
          child: CallbackShortcuts(
            bindings: shortcuts,
            child: FocusScope.withExternalFocusNode(
              focusScopeNode: _calloutFocusScope,
              child: Material(
                key: const Key('tutorial_callout'),
                color: const Color(0xFF08131F),
                elevation: 18,
                shadowColor: AppColors.neonCyan.withValues(alpha: .35),
                borderRadius: BorderRadius.circular(8),
                clipBehavior: Clip.antiAlias,
                child: Container(
                  constraints: BoxConstraints(maxHeight: regionHeight),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.neonCyan.withValues(alpha: .72),
                    ),
                  ),
                  child: SingleChildScrollView(
                    key: const Key('tutorial_callout_scroll_view'),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      key: const Key('tutorial_callout_content'),
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
                        _actions(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _actions() {
    final Widget primary = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: FilledButton.icon(
        focusNode: _primaryFocusNode,
        onPressed: widget.primaryEnabled ? widget.onPrimary : null,
        icon: const Icon(Icons.arrow_forward_rounded),
        label: Text(widget.primaryLabel, textAlign: TextAlign.center),
      ),
    );
    final Widget? secondary = widget.onSecondary == null
        ? null
        : ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: TextButton(
              focusNode: _secondaryFocusNode,
              onPressed: widget.onSecondary,
              child: Text(
                widget.secondaryLabel ?? 'Not now',
                textAlign: TextAlign.center,
              ),
            ),
          );

    if (secondary == null) {
      return SizedBox(width: double.infinity, child: primary);
    }
    final double textScale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth >= 300 && textScale <= 1.5) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(child: primary),
              const SizedBox(width: 8),
              Flexible(child: secondary),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[primary, const SizedBox(height: 8), secondary],
        );
      },
    );
  }
}
