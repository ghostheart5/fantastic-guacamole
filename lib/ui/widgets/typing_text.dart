import 'dart:async';

import 'package:fantastic_guacamole/system/audio/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class TypingText extends StatefulWidget {
  const TypingText(
    this.text, {
    super.key,
    this.style,
    this.step = const Duration(milliseconds: 20),
    this.animate = true,
  });

  final String text;
  final TextStyle? style;
  final Duration step;
  final bool animate;

  @override
  State<TypingText> createState() => _TypingTextState();
}

class _TypingTextState extends State<TypingText> {
  Timer? _timer;
  Timer? _cursorTimer;
  String _visible = '';
  int _index = 0;
  bool _showCursor = true;

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    final SchedulerPhase phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      setState(fn);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(fn);
    });
  }

  @override
  void initState() {
    super.initState();
    _resetAndStart();
  }

  @override
  void didUpdateWidget(covariant TypingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.animate != widget.animate) {
      _resetAndStart();
    }
  }

  void _resetAndStart() {
    _timer?.cancel();
    _cursorTimer?.cancel();
    _index = 0;
    _showCursor = true;

    if (!widget.animate) {
      _safeSetState(() => _visible = widget.text);
      return;
    }

    _cursorTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      _safeSetState(() => _showCursor = !_showCursor);
    });

    _safeSetState(() => _visible = '');
    _timer = Timer.periodic(widget.step, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_index >= widget.text.length) {
        timer.cancel();
        return;
      }

      _safeSetState(() {
        _visible += widget.text[_index];
        _index++;
      });
      AudioService.playTyping();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cursorTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String text = widget.animate
        ? (_showCursor ? '$_visible|' : _visible)
        : _visible;
    return Semantics(
      label: widget.text,
      readOnly: true,
      child: ExcludeSemantics(child: Text(text, style: widget.style)),
    );
  }
}
