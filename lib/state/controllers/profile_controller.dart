import 'dart:async';
import 'dart:convert';

import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/policies/progression_policy.dart';
import 'package:fantastic_guacamole/state/models/streak.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
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

  /// Highest level this user had reached under the pre-migration linear curve
  /// (`(xp ~/ 50) + 1`), which granted levels far faster than the canonical
  /// [ProgressionPolicy] curve.
  ///
  /// Existing users are grandfathered: their displayed level never drops.
  /// [level] is `max(ProgressionPolicy.levelFromXp(xp), legacyLevelFloor)`, so
  /// they keep what they earned and simply advance more slowly from here.
  /// New users start with a floor of 1 and are unaffected.
  ///
  /// This is a migration artifact. Once no installs predate the migration it
  /// can be removed and [level] becomes purely policy-derived.
  final int legacyLevelFloor;

  ProfileState({
    this.xp = 0,
    this.level = 1,
    this.streak = 0,
    this.longestStreak = 0,
    this.leveledUp = false,
    this.name = 'Operative',
    this.soundEnabled = true,
    this.lastActiveDate,
    this.legacyLevelFloor = 1,
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
    int? legacyLevelFloor,
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
      legacyLevelFloor: legacyLevelFloor ?? this.legacyLevelFloor,
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
    'legacyLevelFloor': legacyLevelFloor,
  };

  factory ProfileState.fromJson(Map<String, dynamic> json) {
    final int storedXp = (json['xp'] as num?)?.toInt() ?? 0;
    final int storedLevel = (json['level'] as num?)?.toInt() ?? 1;

    // Migration: a record written before the curve was unified has no
    // 'legacyLevelFloor'. Adopt its stored level as the floor so the user
    // never sees their level go backwards. Records written after the
    // migration carry the floor explicitly and are left alone.
    final int floor =
        (json['legacyLevelFloor'] as num?)?.toInt() ??
        (storedLevel > 1 ? storedLevel : 1);

    return ProfileState(
      xp: storedXp,
      level: levelFor(xp: storedXp, floor: floor),
      streak: (json['streak'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longestStreak'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? 'Operative',
      soundEnabled: json['soundEnabled'] as bool? ?? true,
      lastActiveDate: json['lastActiveDate'] != null
          ? DateTime.tryParse(json['lastActiveDate'] as String)
          : null,
      legacyLevelFloor: floor,
    );
  }

  /// The displayed level: the canonical curve, floored by what the user had
  /// already earned before the migration.
  static int levelFor({required int xp, required int floor}) {
    final int policyLevel = ProgressionPolicy.levelFromXp(xp);
    return policyLevel > floor ? policyLevel : floor;
  }

  /// True while this user is still carried by the pre-migration floor rather
  /// than by earned XP. Lets the UI explain the slower climb, and shows when
  /// the migration artifact can be retired.
  bool get isGrandfathered =>
      legacyLevelFloor > ProgressionPolicy.levelFromXp(xp);
}

final profileProvider = NotifierProvider<ProfileController, ProfileState>(
  ProfileController.new,
);

class ProfileController extends Notifier<ProfileState> {
  bool _initScheduled = false;

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
  static const String _streakBreakNotificationIdPrefix =
      'streak_break_recovery_';

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
    if (amount < 0) {
      throw ArgumentError.value(
        amount,
        'amount',
        'XP award cannot be negative',
      );
    }
    final DateTime now = DateTime.now();
    final bool streakBroke = _streakLogic.didBreak(
      Streak(
        current: state.streak,
        longest: state.longestStreak,
        lastActiveDate: state.lastActiveDate,
      ),
      now,
    );
    final int newXP = state.xp + amount;
    // ProgressionPolicy is the single source of truth for the level curve,
    // floored by any level the user earned before the curve was unified so a
    // grandfathered user never regresses.
    final int newLevel = ProfileState.levelFor(
      xp: newXP,
      floor: state.legacyLevelFloor,
    );
    final bool didLevelUp = newLevel > state.level;
    final updated = _streakLogic.update(
      Streak(
        current: state.streak,
        longest: state.longestStreak,
        lastActiveDate: state.lastActiveDate,
      ),
      now,
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
    if (streakBroke) {
      unawaited(_scheduleStreakBreakNotification(now: now));
    }
    unawaited(_refreshPlannerDecision());
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
    unawaited(_refreshPlannerDecision());
  }

  void resetStreak() {
    state = state.copyWith(streak: 0, clearLastActiveDate: true);
    _save();
    unawaited(_refreshPlannerDecision());
  }

  Future<void> _refreshPlannerDecision() async {
    try {
      await ref.read(generateSiDecisionUseCaseProvider).call();
      ref.invalidate(domainSiDecisionProvider);
    } catch (_) {
      // Avoid blocking progression updates if planner refresh fails.
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
