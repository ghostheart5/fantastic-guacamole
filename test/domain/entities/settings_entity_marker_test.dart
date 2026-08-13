import 'package:fantastic_guacamole/domain/entities/settings_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy defaults leave canonical preference markers unestablished', () {
    const SettingsEntity settings = SettingsEntity();
    expect(settings.soundEstablished, isFalse);
    expect(settings.themeEstablished, isFalse);
  });

  test('copyWith independently establishes sound and theme preferences', () {
    const SettingsEntity legacy = SettingsEntity();
    final SettingsEntity sound = legacy.copyWith(soundEstablished: true);
    final SettingsEntity theme = sound.copyWith(themeEstablished: true);

    expect(sound.soundEstablished, isTrue);
    expect(sound.themeEstablished, isFalse);
    expect(theme.soundEstablished, isTrue);
    expect(theme.themeEstablished, isTrue);
  });

  test('unrelated copies preserve explicit marker values', () {
    const SettingsEntity established = SettingsEntity(
      soundEstablished: true,
      themeEstablished: true,
    );
    final SettingsEntity changed = established.copyWith(soundEnabled: false);
    expect(changed.soundEstablished, isTrue);
    expect(changed.themeEstablished, isTrue);
  });
}
