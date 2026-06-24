import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/services/paywall_service.dart';
import '../../data/services/si_ai_service.dart';
import '../si/adaptive_learning.dart';
import '../si/si_engine.dart';
import '../system/behavior_entities.dart';
import '../system/notification_manager.dart';
import '../system/runtime_persistence.dart';
import '../system/subscription_model.dart';
import '../system/mock_billing_service.dart';
import '../utils/logger.dart';

typedef Decision = SiDecision;
typedef UserState = UserSignalState;
typedef Energy = EnergyLevel;

class AppState extends ChangeNotifier {
  AppState({
    SiEngine? engine,
    PaywallService? paywallService,
    SiAiService? aiService,
    RuntimePersistence? persistence,
  }) : _engine = engine ?? const SiEngine(),
       _paywallService = paywallService ?? PaywallService(),
       _aiService = aiService ?? SiAiService(),
       _persistence = persistence ?? SharedPrefsRuntimePersistence() {
    _timeTicker = Timer.periodic(const Duration(minutes: 5), (_) => _maybeRefreshFromTime());

    _bootstrap();
  }

  final SiEngine _engine;
  final PaywallService _paywallService;
  final SiAiService _aiService;
  final RuntimePersistence _persistence;
  final MockBillingService _billingService = MockBillingService();
  final NotificationManager _notificationManager = NotificationManager();
  final AdaptiveLearningSystem _learning = AdaptiveLearningSystem();

  late final Timer _timeTicker;
  SubscriptionSnapshot _subscription = SubscriptionSnapshot.base();
  DateTime _lastDecisionRefresh = DateTime.fromMillisecondsSinceEpoch(0);

  Decision? decision;
  bool isInitializing = true;
  bool isProcessingConsole = false;
  String? runtimeError;
  bool hasPremiumAccess = false;
  List<PaywallProduct> paywallProducts = const <PaywallProduct>[];

  ChronoUserState behaviorState = const ChronoUserState(
    energy: 0.58,
    cognitiveLoad: 0.72,
    focusLevel: 0.6,
    mood: 0.56,
    timeAvailable: Duration(minutes: 120),
  );

  UserState currentState = const UserState(
    tasks: <SiTask>[
      SiTask(title: 'Finish strategic report', priority: 9, hasDeadline: true),
      SiTask(title: 'Review chronologs and summarize', priority: 7),
      SiTask(title: 'Design weekly temporal map', priority: 8),
      SiTask(title: 'Inbox triage', priority: 4),
    ],
    energyLevel: Energy.medium,
    workload: 0.72,
    deadlinePressure: 0.64,
  );

  final List<String> _history = <String>[];
  final List<ChronoMission> _missions = <ChronoMission>[];
  final List<ChronoRoutine> _routines = <ChronoRoutine>[];
  final List<ChronoLog> _logs = <ChronoLog>[];
  final List<ChronoDecision> _decisionCache = <ChronoDecision>[];
  final List<ChronoNotification> _notifications = <ChronoNotification>[];

  final Set<String> _completedTaskTitles = <String>{};
  final Set<String> _skippedTaskTitles = <String>{};
  final Set<String> _delayedTaskTitles = <String>{};
  static const int _temporalFreeUses = 5;
  static const int _siConsoleFreeUses = 8;
  int _temporalTrialUses = 0;
  int _siConsoleTrialUses = 0;

  List<String> get history => List<String>.unmodifiable(_history);
  List<ChronoNotification> get notifications =>
      List<ChronoNotification>.unmodifiable(_notifications);
  List<ChronoMission> get missions => List<ChronoMission>.unmodifiable(_missions);
  List<ChronoRoutine> get routines => List<ChronoRoutine>.unmodifiable(_routines);
  List<ChronoLog> get logs => List<ChronoLog>.unmodifiable(_logs);
  List<ChronoDecision> get decisionCache => List<ChronoDecision>.unmodifiable(_decisionCache);
  List<TaskBehaviorScore> get taskScores => _learning.exportScores();
  int get temporalTrialRemaining =>
      (_temporalFreeUses - _temporalTrialUses).clamp(0, _temporalFreeUses);
  int get siConsoleTrialRemaining =>
      (_siConsoleFreeUses - _siConsoleTrialUses).clamp(0, _siConsoleFreeUses);
  bool get canUseTemporalOps => isPremium || temporalTrialRemaining > 0;
  bool get canUseSiConsole => isPremium || siConsoleTrialRemaining > 0;
  int get highPriorityAlertCount => _notifications
      .where((ChronoNotification n) => n.priority == ChronoNotificationPriority.high)
      .length;

  // Subscription getters
  SubscriptionSnapshot get subscription => _subscription;
  SubscriptionPlan get currentPlan => _subscription.plan;
  BillingCycle get billingCycle => _subscription.billingCycle;
  SubscriptionStatus get subscriptionStatus => _subscription.status;
  DateTime get subscriptionStartDate => _subscription.subscriptionStartDate;
  DateTime get mockNextBillingDate => _subscription.mockNextBillingDate;
  bool get isPremium => _subscription.plan.isPremium;
  bool get isUltimate => _subscription.plan.isUltimate;
  bool get canUpgrade => !isPremium;
  bool get canDowngrade => isPremium;

  Future<bool> consumeTemporalOpsTrialIfNeeded() async {
    // Premium+ users have unlimited access
    if (isPremium) {
      return true;
    }

    // Base tier uses trial system
    if (temporalTrialRemaining <= 0) {
      return false;
    }
    _temporalTrialUses += 1;
    await _autoSave();
    notifyListeners();
    return true;
  }

  Future<bool> consumeSiConsoleTrialIfNeeded() async {
    // Premium+ users have unlimited access
    if (isPremium) {
      return true;
    }

    // Base tier uses trial system
    if (siConsoleTrialRemaining <= 0) {
      return false;
    }
    _siConsoleTrialUses += 1;
    await _autoSave();
    notifyListeners();
    return true;
  }

  void updateState(UserState newState) {
    Logger.debug('user_action:update_state', data: <String, Object?>{
      'energy': newState.energyLevel.name,
      'workload': newState.workload,
      'deadlinePressure': newState.deadlinePressure,
      'taskCount': newState.tasks.length,
    });
    currentState = newState;
    _recomputeDecision();
    _autoSave();
    notifyListeners();
  }

  Future<void> updateFromConsole(String input) async {
    final String value = input.trim();
    if (value.isEmpty) {
      return;
    }

    Logger.debug('user_action:console_input', data: <String, Object?>{
      'length': value.length,
    });
    isProcessingConsole = true;
    runtimeError = null;
    _notificationManager.markActivity();
    _learning.registerConsoleInput(value);
    notifyListeners();

    final String lower = value.toLowerCase();
    Energy energy = currentState.energyLevel;
    double workload = currentState.workload;
    double deadlinePressure = currentState.deadlinePressure;
    final List<SiTask> tasks = List<SiTask>.from(currentState.tasks);

    if (lower.contains('overwhelmed') || lower.contains('drained')) {
      energy = Energy.low;
      workload = (workload + 0.08).clamp(0.0, 1.0);
    }
    if (lower.contains('focus') || lower.contains('energized')) {
      energy = Energy.high;
      workload = (workload - 0.05).clamp(0.0, 1.0);
    }
    if (lower.contains('deadline') || lower.contains('urgent')) {
      deadlinePressure = 0.85;
    }
    if (lower.contains('light workload')) {
      workload = 0.3;
    }
    if (lower.contains('heavy workload')) {
      workload = 0.9;
    }

    if (lower.startsWith('add:')) {
      final String title = value.substring(4).trim();
      if (title.isNotEmpty) {
        tasks.insert(
          0,
          SiTask(
            title: title,
            priority: lower.contains('critical') ? 10 : 8,
            hasDeadline: lower.contains('deadline') || lower.contains('urgent'),
          ),
        );
        _appendLog('task', 'Task created from console input: $title', ChronoLogStatus.success);
      }
    }

    currentState = UserState(
      tasks: tasks,
      energyLevel: energy,
      workload: workload.clamp(0.0, 1.0),
      deadlinePressure: deadlinePressure.clamp(0.0, 1.0),
    );

    _recomputeDecision(now: DateTime.now());

    _history.add('You: $value');
    String response = decision?.systemNote ?? 'System updated.';

    Logger.debug('api_call:ai_generate_response');
    try {
      final String? aiResponse = await _aiService.generateResponse(
        prompt: value,
        decision: decision ?? _fallbackDecision(),
      );
      if (aiResponse != null && aiResponse.trim().isNotEmpty) {
        response = aiResponse;
        Logger.debug('api_call:ai_generate_response:done');
      }
    } catch (e) {
      Logger.error('api_call:ai_generate_response:error', error: e);
      // Keep rule-based response if AI provider fails.
    }

    await Future<void>.delayed(const Duration(milliseconds: 300));
    _history.add('SI: $response');

    _appendLog('console', value, ChronoLogStatus.info);
    isProcessingConsole = false;
    await _autoSave();
    notifyListeners();
  }

  void updateFromTime(DateTime now) {
    final Energy timedEnergy;
    if (now.hour < 7 || now.hour > 21) {
      timedEnergy = Energy.low;
    } else if (now.hour < 11) {
      timedEnergy = Energy.high;
    } else {
      timedEnergy = Energy.medium;
    }

    currentState = UserState(
      tasks: currentState.tasks,
      energyLevel: timedEnergy,
      workload: currentState.workload,
      deadlinePressure: currentState.deadlinePressure,
    );

    _recomputeDecision(now: now);
    _autoSave();
    notifyListeners();
  }

  void addTask({required String title, int priority = 6, bool hasDeadline = false}) {
    final String trimmed = title.trim();
    if (trimmed.isEmpty) {
      return;
    }

    Logger.debug('user_action:add_task', data: <String, Object?>{
      'title': trimmed,
      'priority': priority,
      'hasDeadline': hasDeadline,
    });
    currentState = UserState(
      tasks: <SiTask>[
        SiTask(title: trimmed, priority: priority.clamp(1, 10), hasDeadline: hasDeadline),
        ...currentState.tasks,
      ],
      energyLevel: currentState.energyLevel,
      workload: (currentState.workload + 0.03).clamp(0.0, 1.0),
      deadlinePressure: currentState.deadlinePressure,
    );

    _appendLog('task', 'Task created: $trimmed', ChronoLogStatus.success);
    _recomputeDecision();
    _autoSave();
    notifyListeners();
  }

  void editTask({
    required String fromTitle,
    required String toTitle,
    int? priority,
    bool? hasDeadline,
  }) {
    final String source = fromTitle.trim();
    final String target = toTitle.trim();
    if (source.isEmpty || target.isEmpty) {
      return;
    }

    Logger.debug('user_action:edit_task', data: <String, Object?>{
      'from': source,
      'to': target,
      'priority': priority,
      'hasDeadline': hasDeadline,
    });
    final List<SiTask> updated = currentState.tasks.map((SiTask task) {
      if (task.title != source) {
        return task;
      }
      return SiTask(
        title: target,
        priority: priority?.clamp(1, 10) ?? task.priority,
        hasDeadline: hasDeadline ?? task.hasDeadline,
      );
    }).toList();

    currentState = UserState(
      tasks: updated,
      energyLevel: currentState.energyLevel,
      workload: currentState.workload,
      deadlinePressure: currentState.deadlinePressure,
    );

    _appendLog('task', 'Task edited: $source -> $target', ChronoLogStatus.info);
    _recomputeDecision();
    _autoSave();
    notifyListeners();
  }

  void completeTask(String title) {
    final String trimmed = title.trim();
    if (trimmed.isEmpty) {
      return;
    }

    Logger.debug('user_action:complete_task', data: <String, Object?>{'title': trimmed});
    _completedTaskTitles.add(trimmed);
    _learning.registerCompletion(trimmed, now: DateTime.now());
    _notificationManager.recordResponse(acknowledged: true);

    _appendLog('task', 'Completed: $trimmed', ChronoLogStatus.success);

    final ChronoNotification completion = _notificationManager.completionFeedback(
      title: trimmed,
      now: DateTime.now(),
    );
    _pushNotification(completion);

    _recomputeDecision();
    _autoSave();
    notifyListeners();
  }

  void skipTask(String title) {
    final String trimmed = title.trim();
    if (trimmed.isEmpty) {
      return;
    }

    Logger.debug('user_action:skip_task', data: <String, Object?>{'title': trimmed});
    _skippedTaskTitles.add(trimmed);
    _learning.registerSkip(trimmed);
    _notificationManager.recordResponse(acknowledged: false);
    _appendLog('task', 'Skipped: $trimmed', ChronoLogStatus.warning);

    _recomputeDecision();
    _autoSave();
    notifyListeners();
  }

  void delayTask(String title) {
    final String trimmed = title.trim();
    if (trimmed.isEmpty) {
      return;
    }

    Logger.debug('user_action:delay_task', data: <String, Object?>{'title': trimmed});
    _delayedTaskTitles.add(trimmed);
    _learning.registerDelay(trimmed);
    _appendLog('task', 'Delayed: $trimmed', ChronoLogStatus.warning);

    _recomputeDecision();
    _autoSave();
    notifyListeners();
  }

  void addMission({required String title, DateTime? deadline, int importance = 6}) {
    final String trimmed = title.trim();
    if (trimmed.isEmpty) {
      return;
    }

    Logger.debug('user_action:add_mission', data: <String, Object?>{
      'title': trimmed,
      'importance': importance,
      'hasDeadline': deadline != null,
    });
    _missions.insert(
      0,
      ChronoMission(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: trimmed,
        tasks: currentState.tasks.take(3).map(_toChronoTask).toList(),
        deadline: deadline,
        importance: importance.clamp(1, 10),
      ),
    );
    _appendLog('mission', 'Mission added: $trimmed', ChronoLogStatus.info);
    _autoSave();
    notifyListeners();
  }

  void addRoutine({required String id, required DateTime scheduledTime}) {
    Logger.debug('user_action:add_routine', data: <String, Object?>{
      'id': id,
      'scheduledTime': scheduledTime.toIso8601String(),
    });
    _routines.insert(
      0,
      ChronoRoutine(
        id: id,
        sequence: currentState.tasks.take(3).map(_toChronoTask).toList(),
        scheduledTime: scheduledTime,
      ),
    );
    _appendLog('routine', 'Routine added: $id', ChronoLogStatus.info);
    _autoSave();
    notifyListeners();
  }

  Future<void> refreshPaywallProducts() async {
    Logger.debug('api_call:refresh_paywall_products');
    paywallProducts = await _paywallService.queryProducts();
    Logger.debug('api_call:refresh_paywall_products:done', data: <String, Object?>{
      'productCount': paywallProducts.length,
    });
    notifyListeners();
  }

  Future<void> purchase(String productId) async {
    Logger.debug('api_call:purchase', data: <String, Object?>{'productId': productId});
    runtimeError = null;
    try {
      await _paywallService.buyProduct(productId);
      Logger.debug('api_call:purchase:done', data: <String, Object?>{'productId': productId});
    } catch (e) {
      Logger.error('api_call:purchase:error', error: e);
      runtimeError = e.toString();
      notifyListeners();
    }
  }

  Future<void> restorePurchases() async {
    Logger.debug('api_call:restore_purchases');
    runtimeError = null;
    try {
      await _paywallService.restorePurchases();
      Logger.debug('api_call:restore_purchases:done');
    } catch (e) {
      Logger.error('api_call:restore_purchases:error', error: e);
      runtimeError = e.toString();
      notifyListeners();
    }
  }

  /// Upgrade to a subscription plan
  Future<bool> upgradeToPlan(SubscriptionPlan plan, BillingCycle billingCycle) async {
    Logger.debug('api_call:upgrade_to_plan', data: <String, Object?>{
      'plan': plan.name,
      'billingCycle': billingCycle.name,
    });
    if (plan == SubscriptionPlan.base) {
      Logger.warning('api_call:upgrade_to_plan:rejected', data: <String, Object?>{
        'reason': 'Cannot upgrade to Base tier',
      });
      runtimeError = 'Cannot upgrade to Base tier. Use downgradePlan instead.';
      notifyListeners();
      return false;
    }

    try {
      runtimeError = null;
      final SubscriptionSnapshot newSubscription = await _billingService.upgradeToPlan(
        plan,
        billingCycle,
      );

      _subscription = newSubscription;
      Logger.debug('state_change:subscription', data: <String, Object?>{
        'plan': _subscription.plan.name,
        'status': _subscription.status.name,
      });
      await _autoSave();
      notifyListeners();
      return true;
    } catch (e) {
      Logger.error('api_call:upgrade_to_plan:error', error: e);
      runtimeError = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Downgrade to Base (free) tier
  Future<bool> downgradePlan() async {
    Logger.debug('api_call:downgrade_plan', data: <String, Object?>{
      'currentPlan': currentPlan.name,
    });
    if (!isPremium) {
      Logger.warning('api_call:downgrade_plan:rejected', data: <String, Object?>{
        'reason': 'Already on Base tier',
      });
      runtimeError = 'Already on Base tier.';
      notifyListeners();
      return false;
    }

    try {
      runtimeError = null;
      final SubscriptionSnapshot newSubscription = await _billingService.downgradeToPlan();

      _subscription = newSubscription;
      // Reset trial counters on downgrade
      _temporalTrialUses = 0;
      _siConsoleTrialUses = 0;

      Logger.debug('state_change:subscription', data: <String, Object?>{
        'plan': _subscription.plan.name,
        'status': _subscription.status.name,
      });
      await _autoSave();
      notifyListeners();
      return true;
    } catch (e) {
      Logger.error('api_call:downgrade_plan:error', error: e);
      runtimeError = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Cancel current subscription
  Future<bool> cancelSubscription() async {
    Logger.debug('api_call:cancel_subscription', data: <String, Object?>{
      'currentPlan': currentPlan.name,
    });
    if (!isPremium) {
      return true; // Already on Base
    }

    try {
      runtimeError = null;
      final SubscriptionSnapshot newSubscription = await _billingService.cancelSubscription(
        _subscription,
      );

      _subscription = newSubscription;
      Logger.debug('state_change:subscription', data: <String, Object?>{
        'plan': _subscription.plan.name,
        'status': _subscription.status.name,
      });
      await _autoSave();
      notifyListeners();
      return true;
    } catch (e) {
      Logger.error('api_call:cancel_subscription:error', error: e);
      runtimeError = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Apply a promo code to subscription
  Future<bool> applyPromoCode(String code) async {
    Logger.debug('api_call:apply_promo_code');
    if (!isPremium) {
      Logger.warning('api_call:apply_promo_code:rejected', data: <String, Object?>{
        'reason': 'Not a premium subscriber',
      });
      runtimeError = 'Promo codes only apply to active subscriptions.';
      notifyListeners();
      return false;
    }

    try {
      runtimeError = null;
      final SubscriptionSnapshot newSubscription = await _billingService.applyPromoCode(
        _subscription,
        code,
      );

      _subscription = newSubscription;
      Logger.debug('state_change:subscription', data: <String, Object?>{
        'plan': _subscription.plan.name,
        'status': _subscription.status.name,
      });
      await _autoSave();
      notifyListeners();
      return true;
    } catch (e) {
      Logger.error('api_call:apply_promo_code:error', error: e);
      runtimeError = e.toString();
      notifyListeners();
      return false;
    }
  }  /// Get next billing date formatted
  String getNextBillingDateFormatted() {
    final DateTime billingDate = _subscription.mockNextBillingDate;
    return 'Your next billing date is ${billingDate.month}/${billingDate.day}/${billingDate.year}';
  }

  /// Get days until next billing
  int getDaysUntilNextBilling() {
    return _subscription.daysUntilNextBilling;
  }

  // ====== SI ENGINE SCALING ======

  /// Get max focus tasks to return based on plan
  int getSiEngineFocusTaskCount() {
    switch (currentPlan) {
      case SubscriptionPlan.base:
        return 2; // Limited to 2
      case SubscriptionPlan.premium:
        return 5; // Full depth
      case SubscriptionPlan.ultimate:
        return 7; // Enhanced
    }
  }

  /// Determine if optional action should be shown
  bool shouldShowOptionalAction() {
    return currentPlan != SubscriptionPlan.base;
  }

  /// Get decision refresh interval (minutes)
  int getDecisionRefreshInterval() {
    switch (currentPlan) {
      case SubscriptionPlan.base:
        return 60; // Hourly
      case SubscriptionPlan.premium:
        return 30; // Half-hourly
      case SubscriptionPlan.ultimate:
        return 15; // Frequent
    }
  }

  // ====== ADAPTIVE LEARNING SCALING ======

  /// Get history retention days based on plan
  int getHistoryRetentionDays() {
    switch (currentPlan) {
      case SubscriptionPlan.base:
        return 7; // Last 7 days
      case SubscriptionPlan.premium:
        return 30; // Last 30 days
      case SubscriptionPlan.ultimate:
        return 365; // Full year
    }
  }

  /// Get learning depth factor (affects task scoring)
  double getLearningDepthFactor() {
    switch (currentPlan) {
      case SubscriptionPlan.base:
        return 0.6; // Limited
      case SubscriptionPlan.premium:
        return 1.0; // Normal
      case SubscriptionPlan.ultimate:
        return 1.4; // Enhanced
    }
  }

  /// Determine if advanced analytics should be computed
  bool shouldComputeAdvancedAnalytics() {
    return isUltimate;
  }

  void _maybeRefreshFromTime() {
    final DateTime now = DateTime.now();
    final int interval = getDecisionRefreshInterval();
    if (now.difference(_lastDecisionRefresh).inMinutes < interval) {
      return;
    }
    _lastDecisionRefresh = now;
    updateFromTime(now);
  }

  Future<void> _bootstrap() async {
    Logger.debug('api_call:bootstrap:start');
    try {
      await _loadRuntimeSnapshot();
      await _loadSubscriptionSnapshot();

      hasPremiumAccess = await _paywallService.readCachedPremium();

      // If no subscription in storage but has premium from paywall, sync
      if (hasPremiumAccess && !isPremium) {
        _subscription = SubscriptionSnapshot(
          plan: SubscriptionPlan.premium,
          billingCycle: BillingCycle.monthly,
          status: SubscriptionStatus.active,
          subscriptionStartDate: DateTime.now(),
          mockNextBillingDate: DateTime.now().add(const Duration(days: 30)),
        );
      }

      await _paywallService
          .initialize(
            onPremiumChanged: (bool premiumFromPaywall) {
              hasPremiumAccess = premiumFromPaywall;
              if (premiumFromPaywall && !isPremium) {
                _subscription = SubscriptionSnapshot(
                  plan: SubscriptionPlan.premium,
                  billingCycle: BillingCycle.monthly,
                  status: SubscriptionStatus.active,
                  subscriptionStartDate: DateTime.now(),
                  mockNextBillingDate: DateTime.now().add(const Duration(days: 30)),
                );
              }
              Logger.debug('state_change:premium_access', data: <String, Object?>{
                'hasPremiumAccess': hasPremiumAccess,
              });
              notifyListeners();
            },
            onError: (String message) {
              Logger.error('api_call:paywall_initialize:error', error: message);
              runtimeError = message;
              notifyListeners();
            },
          )
          .timeout(const Duration(seconds: 8));
      await refreshPaywallProducts();

      _recomputeDecision();
      Logger.debug('api_call:bootstrap:done', data: <String, Object?>{
        'plan': currentPlan.name,
        'hasPremiumAccess': hasPremiumAccess,
      });
    } catch (e) {
      Logger.error('api_call:bootstrap:error', error: e);
      runtimeError = 'Startup partially failed: $e';
      if (decision == null) {
        _recomputeDecision();
      }
    } finally {
      isInitializing = false;
      notifyListeners();
    }
  }

  void _recomputeDecision({DateTime? now}) {
    final DateTime stamp = now ?? DateTime.now();

    Logger.debug('state_change:recompute_decision', data: <String, Object?>{
      'energy': currentState.energyLevel.name,
      'workload': currentState.workload,
      'taskCount': currentState.tasks.length,
    });

    final List<SiTask> rankedTasks = _learning.rankTasks(
      currentState.tasks,
      now: stamp,
      learningDepthFactor: getLearningDepthFactor(),
      historyWindowDays: getHistoryRetentionDays(),
    );
    final UserState engineState = UserState(
      tasks: rankedTasks,
      energyLevel: currentState.energyLevel,
      workload: currentState.workload,
      deadlinePressure: currentState.deadlinePressure,
    );

    final Decision generated = _engine.generateDecision(
      engineState,
      now: stamp,
      outputLoadModifier: _learning.outputLoadModifier,
      recentBehavior: history.take(25).toList(),
      adaptiveScoreOf: _learning.scoreForTask,
    );

    final List<SiTask> scaledFocus = generated.focusTasks
        .take(getSiEngineFocusTaskCount())
        .toList();
    final String optionalAction = shouldShowOptionalAction() ? generated.optionalAction : '';
    final String systemNote = isUltimate
        ? '${generated.systemNote} Advanced SI layer: trend weighting and predictive ordering applied.'
        : generated.systemNote;

    decision = Decision(
      primaryDecision: generated.primaryDecision,
      secondaryAction: generated.secondaryAction,
      optionalAction: optionalAction,
      systemNote: systemNote,
      focusTasks: scaledFocus,
      energy: generated.energy,
      workload: generated.workload,
    );

    _syncBehaviorAndNotifications(now: stamp);
    _appendDecisionCache();
  }

  void _syncBehaviorAndNotifications({required DateTime now}) {
    final double energy = switch (currentState.energyLevel) {
      Energy.low => 0.28,
      Energy.medium => 0.58,
      Energy.high => 0.86,
    };

    final double cognitiveLoad = currentState.workload.clamp(0.0, 1.0);
    final double focusLevel = (1.0 - (currentState.deadlinePressure * 0.35)).clamp(0.0, 1.0);
    final double mood = (energy - (cognitiveLoad * 0.2) + 0.15).clamp(0.0, 1.0);
    final int minutes = (30 + ((1 - cognitiveLoad) * 210)).round();

    behaviorState = ChronoUserState(
      energy: energy,
      cognitiveLoad: cognitiveLoad,
      focusLevel: focusLevel,
      mood: mood,
      timeAvailable: Duration(minutes: minutes),
    );

    final Decision? d = decision;
    if (d == null) {
      return;
    }

    final ChronoDecision chronoDecision = ChronoDecision(
      primaryAction: d.primaryDecision,
      secondaryAction: d.secondaryAction,
      optionalAction: d.optionalAction,
      systemNote: d.systemNote,
    );

    final List<ChronoNotification> generated = _notificationManager.evaluate(
      state: behaviorState,
      decision: chronoDecision,
      tasks: _toChronoTasks(currentState.tasks),
      now: now,
    );

    for (final ChronoNotification notification in generated) {
      _pushNotification(notification);
    }
  }

  List<ChronoTask> _toChronoTasks(List<SiTask> tasks) {
    return tasks.map(_toChronoTask).toList();
  }

  ChronoTask _toChronoTask(SiTask task) {
    final ChronoTaskStatus status;
    if (_completedTaskTitles.contains(task.title)) {
      status = ChronoTaskStatus.done;
    } else if (_skippedTaskTitles.contains(task.title)) {
      status = ChronoTaskStatus.skipped;
    } else if (_delayedTaskTitles.contains(task.title)) {
      status = ChronoTaskStatus.active;
    } else {
      status = ChronoTaskStatus.pending;
    }

    return ChronoTask(
      id: task.title,
      title: task.title,
      priority: task.priority,
      difficulty: task.priority >= 8 ? 8 : 5,
      duration: Duration(minutes: task.hasDeadline ? 90 : 45),
      status: status,
    );
  }

  void _pushNotification(ChronoNotification notification) {
    final bool duplicateMessage = _notifications.any(
      (ChronoNotification existing) =>
          existing.type == notification.type &&
          existing.message == notification.message &&
          existing.timestamp.difference(notification.timestamp).inMinutes.abs() < 15,
    );
    if (duplicateMessage) {
      return;
    }

    _notifications.insert(0, notification);
    if (_notifications.length > 40) {
      _notifications.removeRange(40, _notifications.length);
    }
    _notificationManager.triggerNotification(notification.message);
  }

  void _appendLog(String type, String content, ChronoLogStatus status) {
    _logs.insert(
      0,
      ChronoLog(timestamp: DateTime.now(), type: type, content: content, status: status),
    );
    if (_logs.length > 250) {
      _logs.removeRange(250, _logs.length);
    }
  }

  void _appendDecisionCache() {
    final Decision? d = decision;
    if (d == null) {
      return;
    }

    _decisionCache.insert(
      0,
      ChronoDecision(
        primaryAction: d.primaryDecision,
        secondaryAction: d.secondaryAction,
        optionalAction: d.optionalAction,
        systemNote: d.systemNote,
      ),
    );

    if (_decisionCache.length > 60) {
      _decisionCache.removeRange(60, _decisionCache.length);
    }
  }

  Future<void> _loadRuntimeSnapshot() async {
    Logger.debug('api_call:load_runtime_snapshot');
    final Map<String, dynamic>? decoded = await _persistence.loadSnapshot();
    if (decoded == null) {
      Logger.debug('api_call:load_runtime_snapshot:no_snapshot');
      return;
    }

    Logger.debug('api_call:load_runtime_snapshot:done', data: <String, Object?>{
      'schemaVersion': decoded['schemaVersion'],
    });
    final List<dynamic> tasksRaw = decoded['tasks'] as List<dynamic>? ?? const <dynamic>[];
    final List<SiTask> tasks = tasksRaw.map((dynamic e) {
      final Map<String, dynamic> map = e as Map<String, dynamic>;
      return SiTask(
        title: (map['title'] as String?) ?? 'Untitled Task',
        priority: (map['priority'] as num?)?.toInt() ?? 5,
        hasDeadline: (map['hasDeadline'] as bool?) ?? false,
      );
    }).toList();

    currentState = UserState(
      tasks: tasks.isEmpty ? currentState.tasks : tasks,
      energyLevel: Energy.values[(decoded['energy'] as num?)?.toInt() ?? Energy.medium.index],
      workload: ((decoded['workload'] as num?)?.toDouble() ?? currentState.workload).clamp(
        0.0,
        1.0,
      ),
      deadlinePressure:
          ((decoded['deadlinePressure'] as num?)?.toDouble() ?? currentState.deadlinePressure)
              .clamp(0.0, 1.0),
    );

    _history
      ..clear()
      ..addAll(
        (decoded['history'] as List<dynamic>? ?? const <dynamic>[]).map(
          (dynamic e) => e.toString(),
        ),
      );

    _missions
      ..clear()
      ..addAll(_decodeMissions(decoded['missions'] as List<dynamic>? ?? const <dynamic>[]));

    _routines
      ..clear()
      ..addAll(_decodeRoutines(decoded['routines'] as List<dynamic>? ?? const <dynamic>[]));

    _logs
      ..clear()
      ..addAll(_decodeLogs(decoded['logs'] as List<dynamic>? ?? const <dynamic>[]));

    _decisionCache
      ..clear()
      ..addAll(_decodeDecisions(decoded['decisionCache'] as List<dynamic>? ?? const <dynamic>[]));

    _completedTaskTitles
      ..clear()
      ..addAll(
        (decoded['completedTaskTitles'] as List<dynamic>? ?? const <dynamic>[]).map(
          (dynamic e) => e.toString(),
        ),
      );

    _skippedTaskTitles
      ..clear()
      ..addAll(
        (decoded['skippedTaskTitles'] as List<dynamic>? ?? const <dynamic>[]).map(
          (dynamic e) => e.toString(),
        ),
      );

    _delayedTaskTitles
      ..clear()
      ..addAll(
        (decoded['delayedTaskTitles'] as List<dynamic>? ?? const <dynamic>[]).map(
          (dynamic e) => e.toString(),
        ),
      );

    _temporalTrialUses = (decoded['temporalTrialUses'] as num?)?.toInt() ?? 0;
    _siConsoleTrialUses = (decoded['siConsoleTrialUses'] as num?)?.toInt() ?? 0;

    final Map<String, dynamic> learningJson =
        decoded['learning'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    _learning.fromJson(learningJson);

    // Load subscription data
    final Map<String, dynamic> subJson =
        decoded['subscription'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    if (subJson.isNotEmpty) {
      _subscription = SubscriptionSnapshot.fromJson(subJson);
      return;
    }

    final String? plan = decoded['plan'] as String?;
    if (plan != null && plan.isNotEmpty) {
      _subscription = SubscriptionSnapshot.fromJson(<String, dynamic>{
        'plan': plan,
        'billingCycle': decoded['billingCycle'] ?? 'monthly',
        'status': decoded['subscriptionStatus'] ?? 'active',
        'subscriptionStartDate':
            decoded['subscriptionStartDate'] ?? DateTime.now().toIso8601String(),
        'mockNextBillingDate':
            decoded['mockNextBillingDate'] ??
            DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      });
    }
  }

  /// Load subscription from persistence
  Future<void> _loadSubscriptionSnapshot() async {
    final Map<String, dynamic>? decoded = await _persistence.loadSnapshot();
    if (decoded == null) {
      _subscription = SubscriptionSnapshot.base();
      return;
    }

    final Map<String, dynamic> subJson =
        decoded['subscription'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    if (subJson.isNotEmpty) {
      _subscription = SubscriptionSnapshot.fromJson(subJson);
    } else {
      final String? plan = decoded['plan'] as String?;
      if (plan != null && plan.isNotEmpty) {
        _subscription = SubscriptionSnapshot.fromJson(<String, dynamic>{
          'plan': plan,
          'billingCycle': decoded['billingCycle'] ?? 'monthly',
          'status': decoded['subscriptionStatus'] ?? 'active',
          'subscriptionStartDate':
              decoded['subscriptionStartDate'] ?? DateTime.now().toIso8601String(),
          'mockNextBillingDate':
              decoded['mockNextBillingDate'] ??
              DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        });
      } else {
        _subscription = SubscriptionSnapshot.base();
      }
    }
  }

  Future<void> _autoSave() async {
    Logger.debug('api_call:auto_save', data: <String, Object?>{
      'taskCount': currentState.tasks.length,
      'plan': currentPlan.name,
    });
    final Map<String, dynamic> payload = <String, dynamic>{
      'schemaVersion': 2,
      'tasks': currentState.tasks
          .map(
            (SiTask task) => <String, dynamic>{
              'title': task.title,
              'priority': task.priority,
              'hasDeadline': task.hasDeadline,
            },
          )
          .toList(),
      'energy': currentState.energyLevel.index,
      'workload': currentState.workload,
      'deadlinePressure': currentState.deadlinePressure,
      'history': _history,
      'missions': _missions.map(_encodeMission).toList(),
      'routines': _routines.map(_encodeRoutine).toList(),
      'logs': _logs.map(_encodeLog).toList(),
      'decisionCache': _decisionCache.map(_encodeDecision).toList(),
      'completedTaskTitles': _completedTaskTitles.toList(),
      'skippedTaskTitles': _skippedTaskTitles.toList(),
      'delayedTaskTitles': _delayedTaskTitles.toList(),
      'temporalTrialUses': _temporalTrialUses,
      'siConsoleTrialUses': _siConsoleTrialUses,
      'learning': _learning.toJson(),
      'plan': _subscription.plan.name,
      'billingCycle': _subscription.billingCycle.name,
      'subscriptionStatus': _subscription.status.name,
      'subscriptionStartDate': _subscription.subscriptionStartDate.toIso8601String(),
      'mockNextBillingDate': _subscription.mockNextBillingDate.toIso8601String(),
      'subscription': _subscription.toJson(),
    };
    await _persistence.saveSnapshot(payload);
  }

  List<ChronoMission> _decodeMissions(List<dynamic> raw) {
    return raw.map((dynamic e) {
      final Map<String, dynamic> json = e as Map<String, dynamic>;
      return ChronoMission(
        id: (json['id'] as String?) ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: (json['title'] as String?) ?? 'Mission',
        tasks: (json['tasks'] as List<dynamic>? ?? const <dynamic>[])
            .map((dynamic task) => _decodeChronoTask(task as Map<String, dynamic>))
            .toList(),
        deadline: _parseDate(json['deadline'] as String?),
        importance: (json['importance'] as num?)?.toInt() ?? 5,
      );
    }).toList();
  }

  List<ChronoRoutine> _decodeRoutines(List<dynamic> raw) {
    return raw.map((dynamic e) {
      final Map<String, dynamic> json = e as Map<String, dynamic>;
      return ChronoRoutine(
        id: (json['id'] as String?) ?? DateTime.now().millisecondsSinceEpoch.toString(),
        sequence: (json['sequence'] as List<dynamic>? ?? const <dynamic>[])
            .map((dynamic task) => _decodeChronoTask(task as Map<String, dynamic>))
            .toList(),
        scheduledTime: _parseDate(json['scheduledTime'] as String?) ?? DateTime.now(),
      );
    }).toList();
  }

  List<ChronoLog> _decodeLogs(List<dynamic> raw) {
    return raw.map((dynamic e) {
      final Map<String, dynamic> json = e as Map<String, dynamic>;
      return ChronoLog(
        timestamp: _parseDate(json['timestamp'] as String?) ?? DateTime.now(),
        type: (json['type'] as String?) ?? 'system',
        content: (json['content'] as String?) ?? '',
        status: ChronoLogStatus.values[(json['status'] as num?)?.toInt() ?? 0],
      );
    }).toList();
  }

  List<ChronoDecision> _decodeDecisions(List<dynamic> raw) {
    return raw.map((dynamic e) {
      final Map<String, dynamic> json = e as Map<String, dynamic>;
      return ChronoDecision(
        primaryAction: (json['primaryAction'] as String?) ?? 'No primary action',
        secondaryAction: (json['secondaryAction'] as String?) ?? 'No secondary action',
        optionalAction: json['optionalAction'] as String?,
        systemNote: (json['systemNote'] as String?) ?? '',
      );
    }).toList();
  }

  ChronoTask _decodeChronoTask(Map<String, dynamic> json) {
    return ChronoTask(
      id: (json['id'] as String?) ?? 'task',
      title: (json['title'] as String?) ?? 'Task',
      priority: (json['priority'] as num?)?.toInt() ?? 5,
      difficulty: (json['difficulty'] as num?)?.toInt() ?? 5,
      duration: Duration(minutes: (json['durationMinutes'] as num?)?.toInt() ?? 45),
      status: ChronoTaskStatus.values[(json['status'] as num?)?.toInt() ?? 0],
    );
  }

  Map<String, dynamic> _encodeMission(ChronoMission mission) {
    return <String, dynamic>{
      'id': mission.id,
      'title': mission.title,
      'tasks': mission.tasks.map(_encodeChronoTask).toList(),
      'deadline': mission.deadline?.toIso8601String(),
      'importance': mission.importance,
    };
  }

  Map<String, dynamic> _encodeRoutine(ChronoRoutine routine) {
    return <String, dynamic>{
      'id': routine.id,
      'sequence': routine.sequence.map(_encodeChronoTask).toList(),
      'scheduledTime': routine.scheduledTime.toIso8601String(),
    };
  }

  Map<String, dynamic> _encodeChronoTask(ChronoTask task) {
    return <String, dynamic>{
      'id': task.id,
      'title': task.title,
      'priority': task.priority,
      'difficulty': task.difficulty,
      'durationMinutes': task.duration.inMinutes,
      'status': task.status.index,
    };
  }

  Map<String, dynamic> _encodeLog(ChronoLog log) {
    return <String, dynamic>{
      'timestamp': log.timestamp.toIso8601String(),
      'type': log.type,
      'content': log.content,
      'status': log.status.index,
    };
  }

  Map<String, dynamic> _encodeDecision(ChronoDecision decision) {
    return <String, dynamic>{
      'primaryAction': decision.primaryAction,
      'secondaryAction': decision.secondaryAction,
      'optionalAction': decision.optionalAction,
      'systemNote': decision.systemNote,
    };
  }

  DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  Decision _fallbackDecision() {
    return const SiDecision(
      primaryDecision: 'Stabilize current workload',
      secondaryAction: 'Capture next actionable task',
      optionalAction: 'Run brief SI reflection',
      systemNote: 'Fallback decision path active.',
      focusTasks: <SiTask>[],
      energy: 0.58,
      workload: 0.5,
    );
  }

  @override
  void dispose() {
    _timeTicker.cancel();
    _paywallService.dispose();
    super.dispose();
  }
}
