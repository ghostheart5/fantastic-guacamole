import 'package:fantastic_guacamole/data/storage/secure_store.dart';

class SettingsService {
  SettingsService({required this._store});

  static const String _keyPrefix = 'settings_v1_';
  static const String _neonRecallKey = '${_keyPrefix}neon_recall';
  static const String _siModuleKey = '${_keyPrefix}si_module';
  static const String _notificationsKey = '${_keyPrefix}notifications';
  static const String _analyticsSharingKey = '${_keyPrefix}analytics_sharing';
  static const String _dataSyncKey = '${_keyPrefix}data_sync';
  static const String _compactModeKey = '${_keyPrefix}compact_mode';
  static const String _textScaleKey = '${_keyPrefix}text_scale';
  static const String _siTuningKey = '${_keyPrefix}si_tuning';

  bool _neonRecall = false;
  bool _siModule = true;
  bool _notifications = true;
  bool _analyticsSharing = true;
  bool _dataSync = true;
  bool _compactMode = false;
  double _textScale = 1.0;
  double _siTuning = 0.55;
  bool _hydrated = false;
  final SecureStore _store;

  bool get neonRecall => _neonRecall;
  bool get siModule => _siModule;
  bool get notifications => _notifications;
  bool get analyticsSharing => _analyticsSharing;
  bool get dataSync => _dataSync;
  bool get compactMode => _compactMode;
  double get textScale => _textScale;
  double get siTuning => _siTuning;

  Future<void> hydrate() async {
    if (_hydrated) {
      return;
    }

    _neonRecall = await _store.readBool(_neonRecallKey) ?? _neonRecall;
    _siModule = await _store.readBool(_siModuleKey) ?? _siModule;
    _notifications = await _store.readBool(_notificationsKey) ?? _notifications;
    _analyticsSharing =
        await _store.readBool(_analyticsSharingKey) ?? _analyticsSharing;
    _dataSync = await _store.readBool(_dataSyncKey) ?? _dataSync;
    _compactMode = await _store.readBool(_compactModeKey) ?? _compactMode;
    _textScale = await _store.readDouble(_textScaleKey) ?? _textScale;
    _siTuning = await _store.readDouble(_siTuningKey) ?? _siTuning;
    _hydrated = true;
  }

  Future<void> persist() async {
    await _store.writeBool(_neonRecallKey, _neonRecall);
    await _store.writeBool(_siModuleKey, _siModule);
    await _store.writeBool(_notificationsKey, _notifications);
    await _store.writeBool(_analyticsSharingKey, _analyticsSharing);
    await _store.writeBool(_dataSyncKey, _dataSync);
    await _store.writeBool(_compactModeKey, _compactMode);
    await _store.writeDouble(_textScaleKey, _textScale);
    await _store.writeDouble(_siTuningKey, _siTuning);
  }

  void setNeonRecall(bool value) => _neonRecall = value;
  void setSiModule(bool value) => _siModule = value;
  void setNotifications(bool value) => _notifications = value;
  void setAnalyticsSharing(bool value) => _analyticsSharing = value;
  void setDataSync(bool value) => _dataSync = value;
  void setCompactMode(bool value) => _compactMode = value;
  void setTextScale(double value) => _textScale = value;
  void setSiTuning(double value) => _siTuning = value;

  void resetAll() {
    _neonRecall = false;
    _siModule = true;
    _notifications = true;
    _analyticsSharing = true;
    _dataSync = true;
    _compactMode = false;
    _textScale = 1.0;
    _siTuning = 0.55;
  }
}
