class AppStateService {
  bool _isForeground = true;
  bool _terminated = false;

  bool get isForeground => _isForeground;
  bool get isTerminated => _terminated;

  void setForeground(bool value) {
    _isForeground = value;
  }

  void onTerminate() {
    _terminated = true;
    _isForeground = false;
  }
}
