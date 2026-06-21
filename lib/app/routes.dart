import 'package:flutter/material.dart';

import '../features/home/screens/home_screen.dart';
import '../features/home/screens/gadget_screen.dart';
import '../features/chronocreator/screens/creator_home.dart';
import '../features/chronologs/screens/chronologs_home.dart';
import '../features/temporal_ops/screens/temporal_ops_home.dart';
import '../features/si_console/screens/si_console_home.dart';
import '../features/settings/screens/settings_home.dart';

class AppRoutes {
  static Route generate(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return _r(const HomeScreen());
      case '/creator':
        return _r(const CreatorHome());
      case '/logs':
        return _r(const ChronoLogsHome());
      case '/temporal':
        return _r(const TemporalOpsHome());
      case '/si':
        return _r(const SIConsoleHome());
      case '/settings':
        return _r(const SettingsHome());
      case '/gadget/focus':
        return _r(
          const GadgetScreen(
            title: 'Focus',
            description:
                'Operational focus layer for current mission execution and flow stability.',
            bullets: <String>[
              'Current mission tracking',
              'Focus timer and active session pacing',
              'Distraction count and recovery prompts',
              'Flow state continuity signal',
            ],
          ),
        );
      case '/gadget/si-insight':
        return _r(
          const GadgetScreen(
            title: 'SI Insight',
            description:
                'Surface patterns and discovery extracted by SI analysis.',
            bullets: <String>[
              'Pattern detection from behavior and schedule',
              'Discovery stream with tactical recommendations',
              'Trend confidence by time window',
              'Priority insight highlights',
            ],
          ),
        );
      case '/gadget/constellation':
        return _r(
          const GadgetScreen(
            title: 'Constellation View',
            description:
                'Strategic big-picture map for goals, milestones, progression, and forecasting.',
            bullets: <String>[
              'Goal constellation map',
              'Milestone links and timeline pressure points',
              'Progression vectors across initiatives',
              'Strategic forecasting outlook',
            ],
          ),
        );
      case '/gadget/chronogrid':
        return _r(
          const GadgetScreen(
            title: 'ChronoGrid',
            description:
                'Calendar intelligence surface for missions, events, and focus windows.',
            bullets: <String>[
              'Daily and weekly calendar grid',
              'Mission-event alignment',
              'Time block density view',
              'Upcoming conflict indicators',
            ],
          ),
        );
      case '/gadget/fracture-monitor':
        return _r(
          const GadgetScreen(
            title: 'Fracture Monitor',
            description:
                'Schedule problem detection and load fracture warnings.',
            bullets: <String>[
              'Overload and overlap detection',
              'Context-switch pressure alerts',
              'Recovery window deficit warnings',
              'Remediation suggestions for schedule stability',
            ],
          ),
        );
      default:
        return _r(const Scaffold(body: Center(child: Text('404'))));
    }
  }

  static MaterialPageRoute _r(Widget page) =>
      MaterialPageRoute(builder: (_) => page);
}
