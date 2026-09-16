import 'dart:async';

import 'package:fantastic_guacamole/system/voice/voice_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// App-level stop control: remains reachable when the spoken card scrolls away.
class VoicePlaybackControls extends StatefulWidget {
  const VoicePlaybackControls({
    required this.service,
    required this.navigation,
    super.key,
  });

  final VoiceService service;
  final Listenable navigation;

  @override
  State<VoicePlaybackControls> createState() => _VoicePlaybackControlsState();
}

class _VoicePlaybackControlsState extends State<VoicePlaybackControls>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.service.playback.addListener(_changed);
    widget.navigation.addListener(_stop);
  }

  @override
  void didUpdateWidget(VoicePlaybackControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) {
      oldWidget.service.playback.removeListener(_changed);
      unawaited(oldWidget.service.stop());
      widget.service.playback.addListener(_changed);
    }
    if (oldWidget.navigation != widget.navigation) {
      oldWidget.navigation.removeListener(_stop);
      _stop();
      widget.navigation.addListener(_stop);
    }
  }

  void _changed() {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  void _stop() => unawaited(widget.service.stop());

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _stop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.navigation.removeListener(_stop);
    widget.service.playback.removeListener(_changed);
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.service.isSpeaking) return const SizedBox.shrink();
    final bool spanish = Localizations.localeOf(context).languageCode == 'es';
    return SafeArea(
      bottom: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: FilledButton.icon(
            onPressed: _stop,
            style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
            icon: const Icon(Icons.stop_circle_outlined),
            label: Text(spanish ? 'Detener voz' : 'Stop speaking'),
          ),
        ),
      ),
    );
  }
}
