import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Serializes Android back requests while the router finishes building pages.
///
/// A rapid predictive-back gesture can reach go_router after a page was removed
/// from its Navigator but before Flutter has mounted the replacement route.
/// In that brief interval ModalRoute.willPop asserts because its scope is null.
/// Wait for a frame, then retry that specific transient assertion once.
class StableBackButtonDispatcher extends RootBackButtonDispatcher {
  Future<void> _previousRequest = Future<void>.value();

  @override
  Future<bool> didPopRoute() {
    final Completer<bool> result = Completer<bool>();
    _previousRequest = _previousRequest.then<void>(
      (_) => _completeRequest(result),
      onError: (_, _) => _completeRequest(result),
    );
    return result.future;
  }

  Future<void> _completeRequest(Completer<bool> result) async {
    try {
      result.complete(await _dispatchAfterFrame());
    } catch (error, stackTrace) {
      result.completeError(error, stackTrace);
    }
  }

  Future<bool> _dispatchAfterFrame() async {
    await SchedulerBinding.instance.endOfFrame;
    if (!hasCallbacks) {
      return false;
    }
    try {
      return await super.didPopRoute();
    } on AssertionError catch (error) {
      if (!_isUnmountedModalScope(error)) {
        rethrow;
      }
      await SchedulerBinding.instance.endOfFrame;
      if (!hasCallbacks) {
        return true;
      }
      return super.didPopRoute();
    }
  }

  bool _isUnmountedModalScope(AssertionError error) {
    final String message = error.toString();
    return message.contains('widgets/routes.dart') &&
        message.contains('scope != null');
  }
}
