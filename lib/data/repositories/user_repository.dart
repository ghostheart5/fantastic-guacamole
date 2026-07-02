import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/local/shared_prefs_storage.dart';
import 'package:fantastic_guacamole/data/models/user_state.dart';
import 'package:fantastic_guacamole/domain/entities/user_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_user_repository.dart';
import 'package:fantastic_guacamole/features/user/adapters/user_adapter.dart';
import 'package:fantastic_guacamole/features/user/models/user_model.dart';

/// ChronoSpark UserRepository
class UserRepository implements IUserRepository {
  final SharedPrefsStorage prefs;
  final HiveStorage<UserModel> storage;

  UserRepository({required this.prefs, required this.storage});

  @override
  Future<UserEntity?> getUser() async {
    final model = storage.get('user');
    if (model == null) return null;
    return UserAdapter.toEntity(model);
  }

  @override
  Future<void> updateUser(UserEntity entity) async {
    final model = UserAdapter.toModel(entity);
    await storage.put('user', model);
  }

  Future<UserEntity> saveUser(UserEntity entity) async {
    final model = UserAdapter.toModel(entity);
    await storage.put('user', model);
    return entity;
  }

  Future<UserEntity?> updateName(String name) async {
    final user = await getUser();
    if (user == null) return null;
    final updated = user.copyWith(name: name);
    return saveUser(updated);
  }

  Future<UserEntity?> updateAvatar(String avatarUrl) async {
    final user = await getUser();
    if (user == null) return null;
    final updated = user.copyWith(avatarUrl: avatarUrl);
    return saveUser(updated);
  }

  Future<UserEntity?> updatePreferences(Map<String, dynamic> prefsMap) async {
    final user = await getUser();
    if (user == null) return null;
    final updated = user.copyWith(preferences: prefsMap);
    return saveUser(updated);
  }

  Future<UserState> getUserState() async {
    final json = prefs.getJson('user_state');
    if (json.isEmpty) return UserState.initial();
    return UserAdapter.stateFromJson(json);
  }

  Future<UserState> saveUserState(UserState state) async {
    final json = UserAdapter.stateToJson(state);
    await prefs.setJson('user_state', json);
    return state;
  }

  Future<UserState> updateEnergy(double delta) async {
    final state = await getUserState();
    return saveUserState(state.adjustEnergy(delta));
  }

  Future<UserState> updateFocus(double delta) async {
    final state = await getUserState();
    return saveUserState(state.adjustFocus(delta));
  }

  Future<UserState> updateCognitiveLoad(double delta) async {
    final state = await getUserState();
    return saveUserState(state.adjustCognitiveLoad(delta));
  }

  Future<UserState> addAction(String action) async {
    final state = await getUserState();
    return saveUserState(state.addAction(action));
  }

  Future<UserState> setFlag(String key, dynamic value) async {
    final state = await getUserState();
    return saveUserState(state.setFlag(key, value));
  }

  Future<UserState> clearFlag(String key) async {
    final state = await getUserState();
    return saveUserState(state.clearFlag(key));
  }

  Future<UserState> updatePlanningHorizon(Duration horizon) async {
    final state = await getUserState();
    return saveUserState(state.updatePlanningHorizon(horizon));
  }

  Future<void> resetUser() async {
    await storage.clear();
    await prefs.remove('user_state');
  }
}
