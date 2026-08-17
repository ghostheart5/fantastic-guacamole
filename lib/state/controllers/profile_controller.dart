import 'dart:async';
import 'dart:convert';

import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
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
  final Map<String, int> xpBySource;

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
    this.name = 'ChronoSpark User',
    this.soundEnabled = true,
    this.lastActiveDate,
    this.xpBySource = const <String, int>{},
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
    Map<String, int>? xpBySource,
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
      xpBySource: xpBySource ?? this.xpBySource,
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
    'xpBySource': xpBySource,
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
    final String storedName =
        (json['name'] as String?)?.trim().isNotEmpty == true
        ? (json['name'] as String).trim()
        : 'ChronoSpark User';

    return ProfileState(
      xp: storedXp,
      level: levelFor(xp: storedXp, floor: floor),
      streak: (json['streak'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longestStreak'] as num?)?.toInt() ?? 0,
      // Migrate the retired built-in military-style default without changing
      // any real custom profile name.
      name: storedName == 'Operative' ? 'ChronoSpark User' : storedName,
      soundEnabled: json['soundEnabled'] as bool? ?? true,
      lastActiveDate: json['lastActiveDate'] != null
          ? DateTime.tryParse(json['lastActiveDate'] as String)
          : null,
      xpBySource:
          (json['xpBySource'] as Map?)?.map(
            (key, value) =>
                MapEntry(key.toString(), (value as num?)?.toInt() ?? 0),
          ) ??
          const <String, int>{},
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
  Future<void>? _initialization;
  Future<void> _pendingSave = Future<void>.value();

  @override
  ProfileState build() {
    _initialization ??= Future<void>.microtask(_init);
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
    try {
      String? raw = await _secureStore.readString(_secureStateKey);
      if (raw == null) {
        await _storage.open();
        raw = _storage.get(_stateKey);
        if (raw != null) {
          await _secureStore.writeString(_secureStateKey, raw);
          await _storage.delete(_stateKey);
        }
      }
      if (raw == null || !ref.mounted) return;
      state = ProfileState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (error, stackTrace) {
      Logger.errorCategory(
        'ProfileHydration',
        'Failed to restore the saved profile; keeping safe defaults.',
        error,
        stackTrace,
      );
    }
  }

  Future<void> _ensureInitialized() async {
    await (_initialization ??= Future<void>.microtask(_init));
  }

  Future<void> _save() {
    final SecureStore store = _secureStore;
    final String encoded = jsonEncode(state.toJson());
    final Future<void> operation = _pendingSave.then<void>(
      (_) => store.writeString(_secureStateKey, encoded),
      onError: (_, _) => store.writeString(_secureStateKey, encoded),
    );
    _pendingSave = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        Logger.errorCategory(
          'ProfilePersistence',
          'Failed to persist the latest profile state.',
          error,
          stackTrace,
        );
      },
    );
    return operation;
  }

  Future<void> addXP(int amount) async {
    if (amount < 0) {
      throw ArgumentError.value(
        amount,
        'amount',
        'XP award cannot be negative',
      );
    }
    await _ensureInitialized();
    if (!ref.mounted) return;
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
    await _save();
    if (streakBroke) {
      unawaited(_scheduleStreakBreakNotification(now: now));
    }
    unawaited(_refreshPlannerDecision());
  }

  /// Awards XP for a meaningful domain action and records its provenance.
  /// Existing callers may continue using [addXP] for compatibility; new
  /// product flows should use this method so progression remains explainable.
  Future<void> awardXP(int amount, {required String source}) async {
    await addXP(amount);
    if (!ref.mounted) return;
    final Map<String, int> sources = <String, int>{...state.xpBySource};
    sources[source] = (sources[source] ?? 0) + amount;
    state = state.copyWith(xpBySource: Map<String, int>.unmodifiable(sources));
    await _save();
  }

  void clearLeveledUp() {
    state = state.copyWith(leveledUp: false);
  }

  Future<void> updateName(String name) async {
    await _ensureInitialized();
    if (!ref.mounted) return;
    state = state.copyWith(
      name: name.trim().isEmpty ? state.name : name.trim(),
    );
    await _save();
  }

  Future<void> toggleSound(bool value) async {
    await _ensureInitialized();
    if (!ref.mounted) return;
    state = state.copyWith(soundEnabled: value);
    await _save();
  }

  Future<void> incrementStreak() async {
    await _ensureInitialized();
    if (!ref.mounted) return;
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
    await _save();
    if (streakBroke) {
      unawaited(_scheduleStreakBreakNotification(now: now));
    }
    unawaited(_refreshPlannerDecision());
  }

  Future<void> resetStreak() async {
    await _ensureInitialized();
    if (!ref.mounted) return;
    state = state.copyWith(streak: 0, clearLastActiveDate: true);
    await _save();
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
