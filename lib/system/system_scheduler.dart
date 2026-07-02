class SystemScheduler {
  bool _running = false;

  bool get isRunning => _running;

  void resume() {
    _running = true;
  }

  void pause() {
    _running = false;
  }

  void shutdown() {
    _running = false;
  }
}
