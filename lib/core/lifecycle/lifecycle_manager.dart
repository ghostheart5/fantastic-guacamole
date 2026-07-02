import 'dart:async';

import 'package:flutter/widgets.dart';

typedef LifecycleCallback = void Function(AppLifecycleState state);

class AppLifecycleManager with WidgetsBindingObserver {
  AppLifecycleManager({this.onChange});

  final LifecycleCallback? onChange;

  final _controller = StreamController<AppLifecycleState>.broadcast();
  bool _attached = false;

  Stream<AppLifecycleState> get stream => _controller.stream;

  void attach() {
    if (_attached) return;
    WidgetsBinding.instance.addObserver(this);
    _attached = true;
  }

  void detach() {
    if (!_attached) return;
    WidgetsBinding.instance.removeObserver(this);
    _attached = false;
    _controller.close();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    onChange?.call(state);
    if (!_controller.isClosed) _controller.add(state);
  }

  static bool isForeground(AppLifecycleState state) =>
      state == AppLifecycleState.resumed;

  static bool isBackground(AppLifecycleState state) =>
      state == AppLifecycleState.paused ||
      state == AppLifecycleState.inactive ||
      state == AppLifecycleState.detached;
}

mixin WidgetLifecycleMixin<T extends StatefulWidget> on State<T>
    implements WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {}
}
