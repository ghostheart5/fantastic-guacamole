import 'package:fantastic_guacamole/domain/interfaces/i_flowmap_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_insight_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_log_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_memory_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_plan_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_profile_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_progression_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';

class SiEngineDependencies {
  const SiEngineDependencies({
    required this.tasks,
    required this.goals,
    required this.insights,
    required this.flowmap,
    required this.logs,
    required this.timeline,
    required this.progression,
    required this.memories,
    required this.plan,
    required this.notifications,
    required this.profile,
  });

  final ITaskRepository tasks;
  final IGoalRepository goals;
  final IInsightRepository insights;
  final IFlowmapRepository flowmap;
  final ILogRepository logs;
  final ITimelineRepository timeline;
  final IProgressionRepository progression;
  final IMemoryRepository memories;
  final IPlanRepository plan;
  final INotificationRepository notifications;
  final IProfileRepository profile;
}
