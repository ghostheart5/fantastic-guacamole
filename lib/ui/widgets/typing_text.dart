import 'dart:async';

import 'package:fantastic_guacamole/system/audio/audio_service.dart';
import 'package:flutter/material.dart';

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

    _cursorTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      setState(() => _showCursor = !_showCursor);
    });

    if (!widget.animate) {
      setState(() => _visible = widget.text);
      return;
    }

    setState(() => _visible = '');
    _timer = Timer.periodic(widget.step, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_index >= widget.text.length) {
        timer.cancel();
        return;
      }

      setState(() {
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
    return Text(_showCursor ? '$_visible|' : _visible, style: widget.style);
  }
}
