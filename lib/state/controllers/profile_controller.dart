import 'dart:async';
import 'dart:convert';

import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/progression/progression_calculator.dart';
import 'package:fantastic_guacamole/state/models/streak.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/services/streak_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfileState {
  final int xp;
  final int level;
  final int legacyLevelFloor;
  final int streak;
  final int longestStreak;
  final bool leveledUp;
  final String name;
  final bool soundEnabled;
  final DateTime? lastActiveDate;
  final bool profileReady;

  ProfileState({
    this.xp = 0,
    this.level = 1,
    this.legacyLevelFloor = 1,
    this.streak = 0,
    this.longestStreak = 0,
    this.leveledUp = false,
    this.name = 'Operative',
    this.soundEnabled = true,
    this.lastActiveDate,
    this.profileReady = false,
  });

  bool get hasValidProfile => profileReady && name.trim().isNotEmpty;

  ProfileState copyWith({
    int? xp,
    int? level,
    int? legacyLevelFloor,
    int? streak,
    int? longestStreak,
    bool? leveledUp,
    String? name,
    bool? soundEnabled,
    DateTime? lastActiveDate,
    bool? profileReady,
    bool clearLastActiveDate = false,
  }) {
    return ProfileState(
      xp: xp ?? this.xp,
      level: level ?? this.level,
      legacyLevelFloor: legacyLevelFloor ?? this.legacyLevelFloor,
      streak: streak ?? this.streak,
      longestStreak: longestStreak ?? this.longestStreak,
      leveledUp: leveledUp ?? this.leveledUp,
      name: name ?? this.name,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      lastActiveDate: clearLastActiveDate
          ? null
          : (lastActiveDate ?? this.lastActiveDate),
      profileReady: profileReady ?? this.profileReady,
    );
  }

  Map<String, dynamic> toJson() => {
    'xp': xp,
    'level': level,
    'legacyLevelFloor': legacyLevelFloor,
    'streak': streak,
    'longestStreak': longestStreak,
    'name': name,
    'soundEnabled': soundEnabled,
    'lastActiveDate': lastActiveDate?.toIso8601String(),
    'profileReady': profileReady,
  };

  factory ProfileState.fromJson(Map<String, dynamic> json) {
    final int storedXp = (json['xp'] as num?)?.toInt() ?? 0;
    final int storedLevel = (json['level'] as num?)?.toInt() ?? 1;
    final int legacyLevelFloor =
        (json['legacyLevelFloor'] as num?)?.toInt() ??
        (storedLevel > 1 ? storedLevel : 1);
    final ProgressionCalculation progression = const ProgressionCalculator()
        .calculate(xp: storedXp, legacyLevelFloor: legacyLevelFloor);
    return ProfileState(
      xp: progression.xp,
      level: progression.effectiveLevel,
      legacyLevelFloor: legacyLevelFloor < 1 ? 1 : legacyLevelFloor,
      streak: (json['streak'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longestStreak'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? 'Operative',
      soundEnabled: json['soundEnabled'] as bool? ?? true,
      lastActiveDate: json['lastActiveDate'] != null
          ? DateTime.tryParse(json['lastActiveDate'] as String)
          : null,
      profileReady: json['profileReady'] as bool? ?? false,
    );
  }
}

final profileProvider = NotifierProvider<ProfileController, ProfileState>(
  ProfileController.new,
);

class ProfileController extends Notifier<ProfileState> {
  bool _initScheduled = false;
  int _writeGeneration = 0;
  Future<void> _writeTail = Future<void>.value();

  @override
  ProfileState build() {
    if (!_initScheduled) {
      _initScheduled = true;
      Future<void>.microtask(_init);
    }
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
  static const _progressionCalculator = ProgressionCalculator();
  static const String _streakBreakNotificationIdPrefix =
      'streak_break_recovery_';

  SecureStore get _secureStore => ref.read(secureStoreProvider);
  static String secureStorageKeyForUser(String? userId) {
    return '$_secureStateKey.${_safeStorageScope(userId)}';
  }

  static Future<void> migrateLegacyStorage({
    required SecureStore secureStore,
    required HiveStore hiveStore,
    required String userId,
  }) async {
    final String targetKey = secureStorageKeyForUser(userId);
    if (await secureStore.readString(targetKey) != null) return;

    final String? secureLegacy = await secureStore.readString(_secureStateKey);
    if (secureLegacy != null) {
      await secureStore.writeString(targetKey, secureLegacy);
      await secureStore.delete(_secureStateKey);
      return;
    }

    final HiveStorage<String> legacyStorage = HiveStorage<String>(
      _boxKey,
      hive: hiveStore,
    );
    await legacyStorage.open();
    final String? hiveLegacy = legacyStorage.get(_stateKey);
    if (hiveLegacy == null) return;

    await secureStore.writeString(targetKey, hiveLegacy);
    await legacyStorage.delete(_stateKey);
  }

  static String _safeStorageScope(String? userId) {
    final String value = userId?.trim() ?? '';
    if (value.isEmpty) {
      return 'signed_out';
    }
    return value.replaceAll(RegExp('[^a-zA-Z0-9._-]'), '_');
  }

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

  Future<void> _save() {
    final int generation = _writeGeneration;
    final String encoded = jsonEncode(state.toJson());
    final Future<void> previous = _writeTail.catchError((Object _) {});
    final Future<void> write = previous.then((_) async {
      if (generation != _writeGeneration) return;
      await _secureStore.writeString(_secureStateKey, encoded);
    });
    _writeTail = write;
    return write;
  }

  Future<void> cancelAndDrainWrites() async {
    _writeGeneration++;
    await _writeTail.catchError((Object _) {});
  }

  void addXP(int amount) {
    final DateTime now = DateTime.now();
    final bool streakBroke = _streakLogic.didBreak(
      Streak(
        current: state.streak,
        longest: state.longestStreak,
        lastActiveDate: state.lastActiveDate,
      ),
      now,
    );
    final ProgressionCalculation progression = _progressionCalculator.calculate(
      xp: state.xp + amount,
      legacyLevelFloor: state.legacyLevelFloor,
    );
    final bool didLevelUp = progression.effectiveLevel > state.level;
    final updated = _streakLogic.update(
      Streak(
        current: state.streak,
        longest: state.longestStreak,
        lastActiveDate: state.lastActiveDate,
      ),
      now,
    );

    state = state.copyWith(
      xp: progression.xp,
      level: progression.effectiveLevel,
      leveledUp: didLevelUp,
      streak: updated.current,
      longestStreak: updated.longest,
      lastActiveDate: updated.lastActiveDate,
    );
    _save();
    if (streakBroke) {
      unawaited(_scheduleStreakBreakNotification(now: now));
    }
    unawaited(_refreshCoachDecision());
  }

  void clearLeveledUp() {
    state = state.copyWith(leveledUp: false);
  }

  void updateName(String name) {
    final String normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      return;
    }
    state = state.copyWith(name: normalizedName, profileReady: true);
    _save();
  }

  void ensureProfile({String? preferredName}) {
    final String normalizedPreferred = preferredName?.trim() ?? '';
    final String fallbackName = state.name.trim().isEmpty
        ? 'Operator'
        : state.name.trim();
    state = state.copyWith(
      name: normalizedPreferred.isNotEmpty ? normalizedPreferred : fallbackName,
      profileReady: true,
    );
    _save();
  }

  @Deprecated('Sound preference ownership moved to SettingsPreferenceController.')
  void toggleSound(bool value) {
    // Legacy in-memory compatibility only; this must not persist sound truth.
    state = state.copyWith(soundEnabled: value);
  }

  void incrementStreak() {
    final DateTime now = DateTime.now();
    final bool streakBroke = _streakLogic.didBreak(
      Streak(
        current: state.streak,
        longest: state.longestStreak,
        lastActiveDate: state.lastActiveDate,
      ),
      now,
    );
    final updated = _streakLogic.update(
      Streak(
        current: state.streak,
        longest: state.longestStreak,
        lastActiveDate: state.lastActiveDate,
      ),
      now,
    );
    state = state.copyWith(
      streak: updated.current,
      longestStreak: updated.longest,
      lastActiveDate: updated.lastActiveDate,
    );
    _save();
    if (streakBroke) {
      unawaited(_scheduleStreakBreakNotification(now: now));
    }
    unawaited(_refreshCoachDecision());
  }

  void resetStreak() {
    state = state.copyWith(streak: 0, clearLastActiveDate: true);
    _save();
    unawaited(_refreshCoachDecision());
  }

  Future<void> setProgressionSnapshot({
    required int xp,
    required int level,
    required int streak,
  }) async {
    final int safeXp = xp < 0 ? 0 : xp;
    final int requestedFloor = level < 1 ? 1 : level;
    final int legacyLevelFloor = requestedFloor > state.legacyLevelFloor
        ? requestedFloor
        : state.legacyLevelFloor;
    final ProgressionCalculation progression = _progressionCalculator.calculate(
      xp: safeXp,
      legacyLevelFloor: legacyLevelFloor,
    );
    final int safeStreak = streak < 0 ? 0 : streak;
    final int nextLongest = safeStreak > state.longestStreak
        ? safeStreak
        : state.longestStreak;

    state = state.copyWith(
      xp: progression.xp,
      level: progression.effectiveLevel,
      legacyLevelFloor: legacyLevelFloor,
      streak: safeStreak,
      longestStreak: nextLongest,
    );
    await _save();
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

  Future<void> _scheduleStreakBreakNotification({required DateTime now}) async {
    final DateTime reminderAt = now.add(const Duration(hours: 2));
    final DateTime day = DateTime(now.year, now.month, now.day);
    final String id =
        '$_streakBreakNotificationIdPrefix${day.toIso8601String().split('T').first}';
    try {
      await ref
          .read(notificationsServiceProvider)
          .schedule(
            id: id,
            title: 'Rebuild your streak today',
            body:
                'Your streak chain broke. Complete one focused action now to restart momentum.',
            at: reminderAt,
          );
    } catch (_) {
      // Do not block progression updates if notifications are unavailable.
    }
  }
}
