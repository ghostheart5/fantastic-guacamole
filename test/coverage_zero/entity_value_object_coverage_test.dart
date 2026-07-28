import 'package:fantastic_guacamole/domain/entities/paywall_entity.dart';
import 'package:fantastic_guacamole/domain/entities/paywall_plan.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';
import 'package:fantastic_guacamole/domain/value_objects/timestamp.dart';
import 'package:fantastic_guacamole/engine/learning/learning_history.dart';
import 'package:fantastic_guacamole/engine/scoring/session_score.dart';
import 'package:fantastic_guacamole/engine/si/si_decision.dart';
import 'package:fantastic_guacamole/features/home/ui/models/smart_coach_exchange.dart';
import 'package:fantastic_guacamole/features/monetization/domain/monetization_catalog.dart';
import 'package:fantastic_guacamole/features/monetization/domain/paywall_content.dart';
import 'package:fantastic_guacamole/features/monetization/models/ai_credit_wallet.dart';
import 'package:fantastic_guacamole/features/monetization/models/subscription_status.dart';
import 'package:fantastic_guacamole/state/models/creator_form_data.dart';
import 'package:fantastic_guacamole/state/models/profile_model.dart';
import 'package:fantastic_guacamole/state/models/profile_view_state.dart';
import 'package:fantastic_guacamole/state/models/streak.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('entity and value object coverage', () {
    test('paywall entity stores required values', () {
      const PaywallPlan plan = PaywallPlan(
        id: 'monthly',
        title: 'Monthly',
        priceLabel: '\$9.99',
        description: 'Monthly premium access',
      );

      const PaywallEntity entity = PaywallEntity(
        featureId: 'smart_coach',
        title: 'Unlock Smart Planner',
        body: 'Premium is required for this feature.',
        plans: <PaywallPlan>[plan],
        isUnlocked: false,
      );

      expect(entity.featureId, 'smart_coach');
      expect(entity.title, 'Unlock Smart Planner');
      expect(entity.body, contains('Premium'));
      expect(entity.plans.single.id, 'monthly');
      expect(entity.isUnlocked, isFalse);
    });

    test('timestamp wraps a DateTime value', () {
      final DateTime now = DateTime.utc(2024, 1, 2, 3, 4, 5);
      final Timestamp timestamp = Timestamp(now);

      expect(timestamp.value, now);
      expect(timestamp.value.toIso8601String(), '2024-01-02T03:04:05.000Z');
    });

    test('learning history entry captures learning event details', () {
      final DateTime now = DateTime.utc(2024, 6, 15);
      final LearningHistoryEntry entry = LearningHistoryEntry(
        timestamp: now,
        type: LearningEventType.completed,
        difficulty: 4,
        effortWeight: 0.7,
        priorityWeight: 0.8,
        completed: 3,
        skipped: 1,
      );

      expect(entry.timestamp, now);
      expect(entry.type, LearningEventType.completed);
      expect(entry.difficulty, 4);
      expect(entry.effortWeight, closeTo(0.7, 0.0001));
      expect(entry.priorityWeight, closeTo(0.8, 0.0001));
      expect(entry.completed, 3);
      expect(entry.skipped, 1);
    });

    test('session score supports explicit and default confidence values', () {
      const SessionScore defaultConfidence = SessionScore(
        xp: 120,
        quality: 0.92,
        feedback: 'Excellent focus.',
      );
      const SessionScore explicitConfidence = SessionScore(
        xp: 80,
        quality: 0.75,
        feedback: 'Good effort.',
        confidenceDelta: 0.15,
      );

      expect(defaultConfidence.confidenceDelta, 0.0);
      expect(explicitConfidence.confidenceDelta, closeTo(0.15, 0.0001));
      expect(defaultConfidence.feedback, contains('Excellent'));
      expect(explicitConfidence.xp, 80);
    });

    test('SI decision keeps selected task and rationale', () {
      const Task task = Task(
        id: 'task-1',
        title: 'Write release checklist',
        priority: 5,
        difficulty: 3,
        energyRequired: 2,
        recurrenceRule: RecurrenceRule.none,
      );

      const Decision decision = Decision(
        task: task,
        score: 0.87,
        reasoning: 'High urgency and medium effort.',
      );

      expect(decision.task.id, 'task-1');
      expect(decision.score, closeTo(0.87, 0.0001));
      expect(decision.reasoning, contains('urgency'));
    });

    test('smart planner exchange stores question and answer text', () {
      const SmartCoachExchange exchange = SmartCoachExchange(
        question: 'What should I focus on first?',
        answer: 'Start with the highest impact deadline task.',
      );

      expect(exchange.question, startsWith('What should'));
      expect(exchange.answer, contains('highest impact'));
    });

    test('paywall content composes status, wallet, and catalog data', () {
      final PaywallContent content = PaywallContent(
        title: 'Upgrade',
        body: 'Get more AI credits and premium tools.',
        status: SubscriptionStatus.free(),
        wallet: AiCreditWallet.free(),
        plans: MonetizationCatalog.plans,
        creditPackages: MonetizationCatalog.creditPackages,
        comparisonRows: MonetizationCatalog.comparisonRows,
      );

      expect(content.title, 'Upgrade');
      expect(content.status.planId, 'free');
      expect(content.wallet.balance, greaterThan(0));
      expect(content.plans, isNotEmpty);
      expect(content.creditPackages, isNotEmpty);
      expect(content.comparisonRows, isNotEmpty);
    });

    test('creator form data respects defaults and optional values', () {
      const CreatorFormData defaults = CreatorFormData(
        title: 'Draft task',
        type: 'task',
        priority: 3,
      );

      final DateTime scheduledFor = DateTime.utc(2025, 1, 1);
      final CreatorFormData custom = CreatorFormData(
        title: 'Weekly planning',
        description: 'Prepare goals for the week.',
        type: 'routine',
        priority: 4,
        scheduledFor: scheduledFor,
        recurrenceRule: RecurrenceRule.weekly,
        creatorMode: 'routines',
      );

      expect(defaults.recurrenceRule, RecurrenceRule.none);
      expect(defaults.creatorMode, 'tasks');
      expect(custom.description, contains('week'));
      expect(custom.scheduledFor, scheduledFor);
      expect(custom.recurrenceRule, RecurrenceRule.weekly);
      expect(custom.creatorMode, 'routines');
    });

    test('profile view state keeps profile/loading/error fields', () {
      const ProfileModel profile = ProfileModel(
        name: 'Keegan',
        level: 4,
        xp: 122,
        streak: 9,
        longestStreak: 14,
        soundEnabled: true,
      );

      const ProfileViewState loadingState = ProfileViewState(
        profile: profile,
        loading: true,
      );
      const ProfileViewState errorState = ProfileViewState(
        profile: profile,
        loading: false,
        error: 'Failed to refresh profile.',
      );

      expect(loadingState.loading, isTrue);
      expect(loadingState.profile.name, 'Keegan');
      expect(errorState.loading, isFalse);
      expect(errorState.error, contains('Failed'));
    });

    test('streak stores current, longest, and last activity date', () {
      final DateTime lastActive = DateTime.utc(2025, 2, 20);
      final Streak streak = Streak(
        current: 7,
        longest: 21,
        lastActiveDate: lastActive,
      );

      const Streak emptyActivity = Streak(
        current: 0,
        longest: 0,
        lastActiveDate: null,
      );

      expect(streak.current, 7);
      expect(streak.longest, 21);
      expect(streak.lastActiveDate, lastActive);
      expect(emptyActivity.lastActiveDate, isNull);
    });
  });
}
