import 'package:fantastic_guacamole/state/app_state.dart';

class ProfilePersistence {
  const ProfilePersistence();

  void toggleSound(ProfileController controller, bool value) {
    controller.toggleSound(value);
  }

  void updateName(ProfileController controller, String name) {
    controller.updateName(name);
  }
}
