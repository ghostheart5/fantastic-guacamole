import 'dart:async';

import 'package:fantastic_guacamole/core/eventing/domain_event.dart';

class EventBus {
  EventBus() : _controller = StreamController<DomainEvent>.broadcast();

  final StreamController<DomainEvent> _controller;

  Stream<DomainEvent> get stream => _controller.stream;

  void emit(DomainEvent event) {
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }

  Stream<T> on<T extends DomainEvent>() {
    return _controller.stream.where((DomainEvent event) => event is T).cast<T>();
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}
