import 'dart:async';

import 'package:flutter/material.dart';

class SmartPressable extends StatefulWidget {
  const SmartPressable({
    required this.child,
    required this.onTap,
    this.feedback,
    this.pressedScale = 0.95,
    this.duration = const Duration(milliseconds: 100),
    this.semanticLabel,
    this.button = true,
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
    final Widget gesture = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: () {
        unawaited(_handleTap());
      },
      child: AnimatedScale(
        scale: _scale,
        duration: widget.duration,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
    final String? label = widget.semanticLabel;
    if (label == null) {
      return gesture;
    }
    // ExcludeSemantics prevents the child's own text/icon semantics (if any)
    // from being announced alongside this label, avoiding double-reads.
    return Semantics(
      label: label,
      button: widget.button,
      child: ExcludeSemantics(child: gesture),
    );
  }
}
