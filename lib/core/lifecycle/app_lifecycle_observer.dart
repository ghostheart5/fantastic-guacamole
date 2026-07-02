import 'dart:async';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/lifecycle/background_sync_handler.dart';
import 'package:fantastic_guacamole/core/lifecycle/foreground_service.dart';
import 'package:fantastic_guacamole/core/services/app_state_service.dart';
import 'package:fantastic_guacamole/system/system_hydration.dart';
import 'package:fantastic_guacamole/system/system_scheduler.dart';
import 'package:flutter/widgets.dart';

/// High‑level app lifecycle phase used by ChronoSpark’s system layer.
enum AppLifecyclePhase { initialized, foreground, background, terminated }

/// Signature for lifecycle phase callbacks.
typedef AppLifecyclePhaseCallback =
    void Function(AppLifecyclePhase phase, AppLifecycleState rawState);

/// Central lifecycle observer that:
/// - Hooks into WidgetsBinding
/// - Notifies system services (hydration, scheduler, foreground/background)
/// - Triggers background sync on pause/inactive
/// - Exposes a stream of lifecycle phases for other layers to consume.
class AppLifecycleObserver with WidgetsBindingObserver {
  AppLifecycleObserver({
    required this._appStateService,
    required this._backgroundSyncHandler,
    required this._foregroundService,
    required this._systemHydration,
    required this._systemScheduler,
    this._onPhaseChanged,
    bool attachOnCreate = false,
  }) {
    if (attachOnCreate) {
      attach();
    }
  }

  final AppStateService _appStateService;
  final BackgroundSyncHandler _backgroundSyncHandler;
  final ForegroundService _foregroundService;
  final SystemHydration _systemHydration;
  final SystemScheduler _systemScheduler;
  final AppLifecyclePhaseCallback? _onPhaseChanged;

  final _phaseController = StreamController<AppLifecyclePhase>.broadcast();

  Stream<AppLifecyclePhase> get phaseStream => _phaseController.stream;

  bool _attached = false;
  AppLifecyclePhase _currentPhase = AppLifecyclePhase.initialized;

  void attach() {
    if (_attached) return;
    WidgetsBinding.instance.addObserver(this);
    _attached = true;
    _log('AppLifecycleObserver attached');
  }

  void detach() {
    if (!_attached) return;
    WidgetsBinding.instance.removeObserver(this);
    _attached = false;
    _phaseController.close();
    _log('AppLifecycleObserver detached');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _log('Lifecycle changed: $state');

    switch (state) {
      case AppLifecycleState.resumed:
        _handleForeground(state);
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        _handleBackground(state);
        break;
      case AppLifecycleState.detached:
        _handleTerminated(state);
        break;
      case AppLifecycleState.hidden:
        _handleBackground(state);
        break;
    }
  }

  void _handleForeground(AppLifecycleState rawState) {
    _currentPhase = AppLifecyclePhase.foreground;

    // Mark app as foreground in app state.
    _appStateService.setForeground(true);

    // Ensure system hydration (workspace, profile, settings, SI state, etc.).
    _systemHydration.hydrateIfNeeded();

    // Resume system scheduler (notifications, focus sessions, etc.).
    _systemScheduler.resume();

    // Start any foreground services (e.g., focus overlay, audio feedback).
    _foregroundService.start();

    _emitPhase(_currentPhase, rawState);
  }

  void _handleBackground(AppLifecycleState rawState) {
    _currentPhase = AppLifecyclePhase.background;

    // Mark app as background in app state.
    _appStateService.setForeground(false);

    // Pause system scheduler (avoid unnecessary timers while backgrounded).
    _systemScheduler.pause();

    // Stop foreground services.
    _foregroundService.stop();

    // Schedule background sync (logs, tasks, learning state, SI memory).
    _backgroundSyncHandler.scheduleSync();

    _emitPhase(_currentPhase, rawState);
  }

  void _handleTerminated(AppLifecycleState rawState) {
    _currentPhase = AppLifecyclePhase.terminated;

    // Final sync before termination if possible.
    _backgroundSyncHandler.flush();

    // Mark app as terminated in app state.
    _appStateService.onTerminate();

    // Stop any remaining foreground services.
    _foregroundService.stop();

    // Shutdown scheduler.
    _systemScheduler.shutdown();

    _emitPhase(_currentPhase, rawState);
  }

  void _emitPhase(AppLifecyclePhase phase, AppLifecycleState rawState) {
    if (!_phaseController.isClosed) {
      _phaseController.add(phase);
    }
    _onPhaseChanged?.call(phase, rawState);
  }

  void _log(String message) {
    Logger.log('AppLifecycleObserver', message);
  }
}
