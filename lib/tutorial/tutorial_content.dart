import 'package:flutter/foundation.dart';

@immutable
class TutorialStepContent {
  const TutorialStepContent({
    required this.id,
    required this.title,
    required this.description,
    required this.ctaLabel,
  });

  final String id;
  final String title;
  final String description;
  final String ctaLabel;
}

class TutorialContent {
  const TutorialContent._();

  static const int contentVersion = 6;

  static const List<TutorialStepContent> steps = [
    TutorialStepContent(
      id: 'nexus_overview',
      title: 'NEXUS OVERVIEW',
      description:
          'Scan energy, clarity, and momentum in one view, then choose one concrete next step.',
      ctaLabel: 'Open Nexus',
    ),
    TutorialStepContent(
      id: 'coach_quick_prompt',
      title: 'SMART COACH',
      description:
          'Send one focused prompt to get immediate guidance when momentum drops.',
      ctaLabel: 'Try Prompt',
    ),
    TutorialStepContent(
      id: 'daily_reflection',
      title: 'DAILY REFLECTION',
      description:
          'Set a daily reflection reminder to improve consistency and trend quality over time.',
      ctaLabel: 'Set Reminder',
    ),
    TutorialStepContent(
      id: 'planner_priority',
      title: 'PLAN PRIORITIES',
      description:
          'Pick one top priority first, then stack supporting actions behind it.',
      ctaLabel: 'Set Priority',
    ),
    TutorialStepContent(
      id: 'trajectory_overview',
      title: 'TRAJECTORY',
      description:
          'Read the prediction, choose one action, then branch in Flowmap when needed.',
      ctaLabel: 'Open Trajectory',
    ),
    TutorialStepContent(
      id: 'creator_workbench',
      title: 'CREATOR',
      description:
          'Create manual tasks directly when guided surfaces are too broad for your goal.',
      ctaLabel: 'Create Task',
    ),
    TutorialStepContent(
      id: 'logs_overview',
      title: 'ACTIVITY LOGS',
      description:
          'Review completed actions and timeline events to spot useful patterns quickly.',
      ctaLabel: 'Open Logs',
    ),
    TutorialStepContent(
      id: 'insight_overview',
      title: 'INSIGHTS',
      description:
          'Turn trend signals into one practical next action you can execute now.',
      ctaLabel: 'View Insight',
    ),
    TutorialStepContent(
      id: 'console_overview',
      title: 'SI CONSOLE',
      description:
          'Use SI Console for deep intelligence queries and advanced signal interpretation.',
      ctaLabel: 'ENTER CONSOLE',
    ),
    TutorialStepContent(
      id: 'progression_overview',
      title: 'PROGRESSION TRACKER',
      description:
          'Track momentum shifts over time and confirm your weekly trajectory is climbing.',
      ctaLabel: 'CHECK CLIMB',
    ),
    TutorialStepContent(
      id: 'flowmap_overview',
      title: 'FLOWMAP',
      description:
          'Map branching paths before committing so your next move stays resilient.',
      ctaLabel: 'Open Flowmap',
    ),
    TutorialStepContent(
      id: 'goals_overview',
      title: 'GOALS WORKSPACE',
      description:
          'Keep goals precise, measurable, and aligned with your current energy state.',
      ctaLabel: 'ALIGN GOALS',
    ),
    TutorialStepContent(
      id: 'memories_overview',
      title: 'MEMORIES',
      description:
          'Capture high-signal memory notes so Smart Coach can reason with real context.',
      ctaLabel: 'Save Memory',
    ),
    TutorialStepContent(
      id: 'soul_map_overview',
      title: 'SOUL MAP',
      description:
          'Read emotional and identity vectors that influence clarity, resilience, and decision quality.',
      ctaLabel: 'SCAN MAP',
    ),
    TutorialStepContent(
      id: 'timeline_overview',
      title: 'TIMELINE REVIEW',
      description:
          'Connect past decisions to current trajectory and execute cleaner course corrections.',
      ctaLabel: 'OPEN TIMELINE',
    ),
  ];

  static const Map<String, String> contextualHints = {
    'nexus':
        'Scan ENERGY and CLARITY first, then choose one concrete next action.',
    'nexus_overview':
        'Scan ENERGY and CLARITY first, then choose one concrete next action.',

    'smart_coach':
        'Send one focused prompt, then one follow-up question for better precision.',
    'coach_quick_prompt':
        'Send one focused prompt, then one follow-up question for better precision.',

    'settings_reflection':
        'Set a reflection reminder at a time you can realistically keep daily.',
    'daily_reflection':
        'Set a reflection reminder at a time you can realistically keep daily.',

    'plan': 'Set one top priority first, then stack the rest around it.',
    'planner_priority':
        'Set one top priority first, then stack the rest around it.',

    'trajectory':
        'Read prediction first, then choose one action and open Flowmap if you need branching.',
    'trajectory_overview':
        'Read prediction first, then choose one action and open Flowmap if you need branching.',

    'creator':
        'Use Creator when you need direct manual control over task creation.',
    'creator_workbench':
        'Use Creator when you need direct manual control over task creation.',

    'logs':
        'Review completed actions first, then inspect recurring patterns before changing strategy.',
    'logs_overview':
        'Review completed actions first, then inspect recurring patterns before changing strategy.',

    'profile':
        'Use Profile for identity and streak context; use Settings for permissions, toggles, and runtime controls.',

    'insight':
        'Decode trend signals and convert them into one high-impact action for today.',
    'insight_overview':
        'Decode trend signals and convert them into one high-impact action for today.',

    'console':
        'Use SI Console when you need a deeper read than quick guidance surfaces can provide.',
    'console_overview':
        'Use SI Console when you need a deeper read than quick guidance surfaces can provide.',

    'progression':
        'Track whether momentum compounds week over week and adjust immediately when it stalls.',
    'progression_overview':
        'Track whether momentum compounds week over week and adjust immediately when it stalls.',

    'flowmap':
        'Map branches before committing so your next move stays clear and resilient.',
    'flowmap_overview':
        'Explore branches before committing so your next move is both clear and resilient.',

    'goals':
        'Keep goals concise, measurable, and aligned with current trajectory constraints.',
    'goals_overview':
        'Keep goals concise, measurable, and aligned with current trajectory constraints.',

    'memories':
        'Store high-signal memories with enough detail for stronger future coaching context.',
    'memories_overview':
        'Store high-signal memories with enough detail for stronger future coaching context.',

    'soul_map':
        'Use Soul Map regularly to detect drift between values and daily execution patterns.',
    'soul_map_overview':
        'Use Soul Map regularly to detect drift between values and daily execution patterns.',

    'timeline':
        'Scan timeline causality before changing direction so course correction is intentional.',
    'timeline_overview':
        'Scan timeline causality before changing direction so course correction is intentional.',
  };

  static TutorialStepContent? byId(String id) {
    try {
      return steps.firstWhere((step) => step.id == id);
    } catch (_) {
      return null;
    }
  }

  static bool hasStep(String id) {
    return steps.any((step) => step.id == id);
  }

  static String? hintFor(String contextId) {
    return contextualHints[contextId];
  }

  static int get totalSteps => steps.length;

  static List<String> get stepIds =>
      steps.map((step) => step.id).toList(growable: false);
}
