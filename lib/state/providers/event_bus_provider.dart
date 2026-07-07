import 'dart:async';

import 'package:fantastic_guacamole/core/eventing/domain_event.dart';
import 'package:fantastic_guacamole/core/eventing/event_bus.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/feature_derived_providers.dart';
import 'package:fantastic_guacamole/state/providers/flowmap_provider.dart';
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:fantastic_guacamole/state/providers/insights_provider.dart';
import 'package:fantastic_guacamole/state/providers/logs_provider.dart';
import 'package:fantastic_guacamole/state/providers/memories_provider.dart';
import 'package:fantastic_guacamole/state/providers/notification_provider.dart';
import 'package:fantastic_guacamole/state/providers/progression_provider.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final eventBusProvider = Provider<EventBus>((Ref ref) {
  final EventBus bus = EventBus();
  ref.onDispose(() {
    unawaited(bus.dispose());
  });
  return bus;
});

final eventBusBootstrapProvider = Provider<void>((Ref ref) {
  final EventBus bus = ref.read(eventBusProvider);
  final List<StreamSubscription<dynamic>>
  subscriptions = <StreamSubscription<dynamic>>[
    bus.on<TaskLifecycleEvent>().listen((TaskLifecycleEvent _) {
      ref.invalidate(tasksProvider);
      ref.invalidate(goalProgressProvider);
      ref.invalidate(domainSiDecisionProvider);
    }),
    bus.on<GoalLifecycleEvent>().listen((GoalLifecycleEvent _) {
      ref.invalidate(goalsProvider);
      ref.invalidate(goalProgressProvider);
      ref.invalidate(insightsBundleProvider);
      ref.invalidate(domainSiDecisionProvider);
    }),
    bus.on<InsightLifecycleEvent>().listen((InsightLifecycleEvent _) {
      ref.invalidate(insightsBundleProvider);
      ref.invalidate(memoriesProvider);
      ref.invalidate(soulStateProvider);
      ref.invalidate(domainSiDecisionProvider);
    }),
    bus.on<FlowmapLifecycleEvent>().listen((FlowmapLifecycleEvent _) {
      ref.invalidate(flowmapProvider);
      ref.invalidate(soulStateProvider);
      ref.invalidate(domainSiDecisionProvider);
    }),
    bus.on<LogLifecycleEvent>().listen((LogLifecycleEvent _) {
      ref.invalidate(logsProvider);
      ref.invalidate(domainSiDecisionProvider);
      ref.invalidate(soulStateProvider);
    }),
    bus.on<TimelineLifecycleEvent>().listen((TimelineLifecycleEvent _) {
      ref.invalidate(timelineProvider);
      ref.invalidate(domainSiDecisionProvider);
      ref.invalidate(soulStateProvider);
    }),
    bus.on<ProgressionLifecycleEvent>().listen((ProgressionLifecycleEvent _) {
      ref.invalidate(profileProvider);
      ref.invalidate(progressionProvider);
      ref.invalidate(domainSiDecisionProvider);
      ref.invalidate(soulStateProvider);
    }),
    bus.on<MemoryLifecycleEvent>().listen((MemoryLifecycleEvent _) {
      ref.invalidate(memoriesProvider);
      ref.invalidate(domainSiDecisionProvider);
      ref.invalidate(soulStateProvider);
    }),
    bus.on<NotificationLifecycleEvent>().listen((NotificationLifecycleEvent _) {
      ref.invalidate(notificationProvider);
      ref.invalidate(unreadNotificationsProvider);
      ref.invalidate(domainSiDecisionProvider);
    }),
  ];

  ref.onDispose(() {
    for (final StreamSubscription<dynamic> subscription in subscriptions) {
      unawaited(subscription.cancel());
    }
  });
});
