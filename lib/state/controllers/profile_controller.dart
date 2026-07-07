import 'dart:async';
import 'dart:convert';

import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/models/streak.dart';
import 'package:fantastic_guacamole/state/services/streak_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfileState {
  final int xp;
  final int level;
  final int streak;
  final int longestStreak;
  final bool leveledUp;
  final String name;
  final bool soundEnabled;
  final DateTime? lastActiveDate;

  ProfileState({
    this.xp = 0,
    this.level = 1,
    this.streak = 0,
    this.longestStreak = 0,
    this.leveledUp = false,
    this.name = 'Operative',
    this.soundEnabled = true,
    this.lastActiveDate,
  });

  ProfileState copyWith({
    int? xp,
    int? level,
    int? streak,
    int? longestStreak,
    bool? leveledUp,
    String? name,
    bool? soundEnabled,
    DateTime? lastActiveDate,
    bool clearLastActiveDate = false,
  }) {
    return ProfileState(
      xp: xp ?? this.xp,
      level: level ?? this.level,
      streak: streak ?? this.streak,
      longestStreak: longestStreak ?? this.longestStreak,
      leveledUp: leveledUp ?? this.leveledUp,
      name: name ?? this.name,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      lastActiveDate: clearLastActiveDate
          ? null
          : (lastActiveDate ?? this.lastActiveDate),
    );
  }

  Map<String, dynamic> toJson() => {
    'xp': xp,
    'level': level,
    'streak': streak,
    'longestStreak': longestStreak,
    'name': name,
    'soundEnabled': soundEnabled,
    'lastActiveDate': lastActiveDate?.toIso8601String(),
  };

  factory ProfileState.fromJson(Map<String, dynamic> json) => ProfileState(
    xp: (json['xp'] as num?)?.toInt() ?? 0,
    level: (json['level'] as num?)?.toInt() ?? 1,
    streak: (json['streak'] as num?)?.toInt() ?? 0,
    longestStreak: (json['longestStreak'] as num?)?.toInt() ?? 0,
    name: json['name'] as String? ?? 'Operative',
    soundEnabled: json['soundEnabled'] as bool? ?? true,
    lastActiveDate: json['lastActiveDate'] != null
        ? DateTime.tryParse(json['lastActiveDate'] as String)
        : null,
  );
}

final profileProvider = NotifierProvider<ProfileController, ProfileState>(
  ProfileController.new,
);

class ProfileController extends Notifier<ProfileState> {
  @override
  ProfileState build() {
    _init();
    return ProfileState();
  }

  static const _boxKey = 'profile_box';
  static const _stateKey = 'profile_state';
  static const _secureStateKey = 'profile_state_v2';
  final HiveStorage<String> _storage = HiveStorage<String>(
    _boxKey,
    hive: const HiveStoreAdapter(),
  );
  static const _streakLogic = StreakService();

  SecureStore get _secureStore => ref.read(secureStoreProvider);

  Future<void> _init() async {
    String? raw = await _secureStore.readString(_secureStateKey);
    if (raw == null) {
      await _storage.open();
      raw = _storage.get(_stateKey);
      if (raw != null) {
        await _secureStore.writeString(_secureStateKey, raw);
        await _storage.delete(_stateKey);
      }
    }
    if (raw == null) return;
    try {
      state = ProfileState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {}
  }

  Future<void> _save() async {
    await _secureStore.writeString(_secureStateKey, jsonEncode(state.toJson()));
  }

  void addXP(int amount) {
    final int newXP = state.xp + amount;
    final int newLevel = (newXP ~/ 50) + 1;
    final bool didLevelUp = newLevel > state.level;
    final updated = _streakLogic.update(
      Streak(
        current: state.streak,
        longest: state.longestStreak,
        lastActiveDate: state.lastActiveDate,
      ),
      DateTime.now(),
    );

    state = state.copyWith(
      xp: newXP,
      level: newLevel,
      leveledUp: didLevelUp,
      streak: updated.current,
      longestStreak: updated.longest,
      lastActiveDate: updated.lastActiveDate,
    );
    _save();
    unawaited(_refreshCoachDecision());
  }

  void clearLeveledUp() {
    state = state.copyWith(leveledUp: false);
  }

  void updateName(String name) {
    state = state.copyWith(
      name: name.trim().isEmpty ? state.name : name.trim(),
    );
    _save();
  }

  void toggleSound(bool value) {
    state = state.copyWith(soundEnabled: value);
    _save();
  }

  void incrementStreak() {
    final updated = _streakLogic.update(
      Streak(
        current: state.streak,
        longest: state.longestStreak,
        lastActiveDate: state.lastActiveDate,
      ),
      DateTime.now(),
    );
    state = state.copyWith(
      streak: updated.current,
      longestStreak: updated.longest,
      lastActiveDate: updated.lastActiveDate,
    );
    _save();
    unawaited(_refreshCoachDecision());
  }

  void resetStreak() {
    state = state.copyWith(streak: 0, clearLastActiveDate: true);
    _save();
    unawaited(_refreshCoachDecision());
  }

  Future<void> _refreshCoachDecision() async {
    try {
      await ref.read(generateSiDecisionUseCaseProvider).call();
      ref.invalidate(domainSiDecisionProvider);
    } catch (_) {
      // Avoid blocking progression updates if coach refresh fails.
    }
  }
}
