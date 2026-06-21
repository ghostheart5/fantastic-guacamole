class SettingsService {
  bool _neonRecall = false;
  bool _siModule = true;
  bool _notifications = true;
  bool _dataSync = true;
  bool _compactMode = false;
  double _textScale = 1.0;
  double _siTuning = 0.55;

  bool get neonRecall => _neonRecall;
  bool get siModule => _siModule;
  bool get notifications => _notifications;
  bool get dataSync => _dataSync;
  bool get compactMode => _compactMode;
  double get textScale => _textScale;
  double get siTuning => _siTuning;

  void setNeonRecall(bool value) => _neonRecall = value;
  void setSiModule(bool value) => _siModule = value;
  void setNotifications(bool value) => _notifications = value;
  void setDataSync(bool value) => _dataSync = value;
  void setCompactMode(bool value) => _compactMode = value;
  void setTextScale(double value) => _textScale = value;
  void setSiTuning(double value) => _siTuning = value;

  void resetAll() {
    _neonRecall = false;
    _siModule = true;
    _notifications = true;
    _dataSync = true;
    _compactMode = false;
    _textScale = 1.0;
    _siTuning = 0.55;
  }
}
