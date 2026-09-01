import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SmartPressable extends StatefulWidget {
  const SmartPressable({
    required this.child,
    required this.onTap,
    this.feedback,
    this.pressedScale = 0.95,
    this.duration = const Duration(milliseconds: 100),
    this.semanticLabel,
    this.button = true,
    this.selected,
    super.key,
  });

  final Widget child;
  final VoidCallback onTap;
  final Future<void> Function()? feedback;
  final double pressedScale;
  final Duration duration;

  /// Accessible name announced by screen readers. When null (the default),
  /// this widget adds no semantics of its own so existing call sites whose
  /// child already carries its own label (e.g. visible text) are unaffected.
  final String? semanticLabel;
  final bool button;
  final bool? selected;

  @override
  State<SmartPressable> createState() => _SmartPressableState();
}

class _SmartPressableState extends State<SmartPressable> {
  double _scale = 1.0;
  bool _isRunning = false;

  void _setPressed(bool pressed) {
    if (!mounted) {
      return;
    }
    setState(() {
      _scale = pressed ? widget.pressedScale : 1.0;
    });
  }

  Future<void> _handleTap() async {
    if (_isRunning) {
      return;
    }
    _isRunning = true;
    try {
      final Future<void> Function()? feedback = widget.feedback;
      if (feedback != null) {
        await feedback();
      }
      widget.onTap();
    } finally {
      _isRunning = false;
      _setPressed(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool disableAnimations = MediaQuery.disableAnimationsOf(context);
    final Widget gesture = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: disableAnimations ? null : (_) => _setPressed(true),
      onTapUp: disableAnimations ? null : (_) => _setPressed(false),
      onTapCancel: disableAnimations ? null : () => _setPressed(false),
      onTap: () {
        unawaited(_handleTap());
      },
      child: AnimatedScale(
        scale: disableAnimations ? 1.0 : _scale,
        duration: disableAnimations ? Duration.zero : widget.duration,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
    final Widget focusable = FocusableActionDetector(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (ActivateIntent _) {
            unawaited(_handleTap());
            return null;
          },
        ),
      },
      child: gesture,
    );
    final String? label = widget.semanticLabel;
    return Semantics(
      label: label,
      button: widget.button,
      selected: widget.selected,
      onTap: () => unawaited(_handleTap()),
      // A custom label replaces descendant text; otherwise it remains the
      // accessible name while this node supplies the button action.
      child: label == null ? focusable : ExcludeSemantics(child: focusable),
    );
  }
}
