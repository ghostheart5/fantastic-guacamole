import 'package:fantastic_guacamole/features/profile/models/profile_model.dart';

class ProfileViewState {
  const ProfileViewState({
    required this.profile,
    required this.loading,
    this.error,
  });

  final ProfileModel profile;
  final bool loading;
  final String? error;
}
