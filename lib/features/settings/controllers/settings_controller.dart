import '../../../data/repositories/settings_repository.dart';
import '../../../data/repositories/settings_repository_impl.dart';
import '../../../domain/entities/app_settings.dart';
import '../../../domain/usecases/settings/reset_settings_usecase.dart';
import '../../../domain/usecases/settings/update_settings_usecase.dart';

class SettingsState {
  final bool neonRecall;
  final bool siEnabled;
  final bool notifications;
  final bool dataSync;
  final bool compactMode;
  final double textScale;
  final double siTuning;

  const SettingsState({
    required this.neonRecall,
    required this.siEnabled,
    required this.notifications,
    required this.dataSync,
    required this.compactMode,
    required this.textScale,
    required this.siTuning,
  });
}

class SettingsController {
  SettingsController({SettingsRepository? repository})
    : _repository = repository ?? SettingsRepositoryImpl(),
      _updateSettingsUseCase = UpdateSettingsUseCase(),
      _resetSettingsUseCase = ResetSettingsUseCase();

  final SettingsRepository _repository;
  final UpdateSettingsUseCase _updateSettingsUseCase;
  final ResetSettingsUseCase _resetSettingsUseCase;

  AppSettings _toDomain() {
    return _repository.load();
  }

  void _applyDomain(AppSettings settings) {
    _repository.save(settings);
  }

  SettingsState read() {
    final AppSettings current = _repository.load();
    return SettingsState(
      neonRecall: current.neonRecall,
      siEnabled: current.siEnabled,
      notifications: current.notifications,
      dataSync: current.dataSync,
      compactMode: current.compactMode,
      textScale: current.textScale,
      siTuning: current.siTuning,
    );
  }

  SettingsState setNeonRecall(bool value) {
    final AppSettings next = _updateSettingsUseCase(
      current: _toDomain(),
      neonRecall: value,
    );
    _applyDomain(next);
    return read();
  }

  SettingsState setSiEnabled(bool value) {
    final AppSettings next = _updateSettingsUseCase(
      current: _toDomain(),
      siEnabled: value,
    );
    _applyDomain(next);
    return read();
  }

  SettingsState setNotifications(bool value) {
    final AppSettings next = _updateSettingsUseCase(
      current: _toDomain(),
      notifications: value,
    );
    _applyDomain(next);
    return read();
  }

  SettingsState setDataSync(bool value) {
    final AppSettings next = _updateSettingsUseCase(
      current: _toDomain(),
      dataSync: value,
    );
    _applyDomain(next);
    return read();
  }

  SettingsState setCompactMode(bool value) {
    final AppSettings next = _updateSettingsUseCase(
      current: _toDomain(),
      compactMode: value,
    );
    _applyDomain(next);
    return read();
  }

  SettingsState setTextScale(double value) {
    final AppSettings next = _updateSettingsUseCase(
      current: _toDomain(),
      textScale: value,
    );
    _applyDomain(next);
    return read();
  }

  SettingsState setSiTuning(double value) {
    final AppSettings next = _updateSettingsUseCase(
      current: _toDomain(),
      siTuning: value,
    );
    _applyDomain(next);
    return read();
  }

  SettingsState resetData() {
    _repository.resetDefaults();
    _applyDomain(_resetSettingsUseCase());
    return read();
  }
}
