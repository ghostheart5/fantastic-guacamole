part of 'settings_screen.dart';

class _ReflectionReminderSection extends ConsumerStatefulWidget {
  const _ReflectionReminderSection();

  @override
  ConsumerState<_ReflectionReminderSection> createState() => _ReflectionReminderSectionState();
}

class _DailyReflectionTutorialPanel extends ConsumerWidget {
  const _DailyReflectionTutorialPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(tutorialProgressProvider);
    final TutorialStepContent step = TutorialContent.steps.firstWhere(
      (TutorialStepContent content) => content.id == 'daily_reflection',
      orElse: () => TutorialContent.steps.first,
    );

    return progressAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (progress) {
        if (progress.isStepCompleted(step.id)) {
          return const SizedBox.shrink();
        }

        if (progress.isStepDismissed(step.id)) {
          return Align(
            alignment: Alignment.centerLeft,
            child: ShowMeAgainButton(stepId: step.id, label: 'Show Reflection Tutorial Again'),
          );
        }

        return MicroTutorialCard(
          step: step,
          onComplete: () {
            ref.read(tutorialProgressProvider.notifier).markIntroSeen();
          },
          onDismiss: () {
            ref.read(tutorialProgressProvider.notifier).markIntroSeen();
          },
        );
      },
    );
  }
}

class _ReflectionReminderSectionState extends ConsumerState<_ReflectionReminderSection> {
  bool _enabled = false;
  TimeOfDay _time = const TimeOfDay(hour: 20, minute: 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final ReflectionReminderPrefs prefs = ref
        .read(settingsUiActionsProvider)
        .loadReflectionReminderPrefs();
    setState(() {
      _enabled = prefs.enabled;
      _time = prefs.time;
    });
  }

  Future<void> _toggle(bool value) async {
    final bool enabled = await ref
        .read(settingsUiActionsProvider)
        .setReflectionReminderEnabled(enabled: value, time: _time);
    if (!mounted) {
      return;
    }
    setState(() => _enabled = enabled);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.neonViolet,
            onPrimary: Colors.white,
            surface: Color(0xFF0B111C),
            onSurface: Colors.white70,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _time = picked);
    await ref.read(settingsUiActionsProvider).setReflectionReminderTime(time: picked);
    if (_enabled) {
      await ref
          .read(settingsUiActionsProvider)
          .setReflectionReminderEnabled(enabled: true, time: picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Section(
      label: 'DAILY REFLECTION',
      accentColor: AppColors.neonViolet,
      child: Column(
        children: [
          _NeonToggleTile(title: 'Reflection Reminder', value: _enabled, onChanged: _toggle),
          if (_enabled)
            GestureDetector(
              onTap: _pickTime,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Reminder Time',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.neonViolet.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.neonViolet.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        _time.format(context),
                        style: const TextStyle(
                          color: AppColors.neonViolet,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GlobalMetricsDebugSection extends ConsumerWidget {
  const _GlobalMetricsDebugSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(optimizationConfigProvider);
    return _Section(
      label: 'GLOBAL OPTIMIZER',
      accentColor: AppColors.neonCyan,
      child: Column(
        children: [
          configAsync.when(
            data: (config) => Column(
              children: [
                _NeonStatusTile(
                  title: 'Focus Duration Multiplier',
                  subtitle: config.focusDurationMultiplier.toStringAsFixed(2),
                ),
                _NeonStatusTile(
                  title: 'Task Difficulty Scale',
                  subtitle: config.taskDifficultyScale.toStringAsFixed(2),
                ),
              ],
            ),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (e, _) => _NeonStatusTile(title: 'Optimizer Error', subtitle: e.toString()),
          ),
          _NeonNavTile(
            title: 'Refresh Global Metrics',
            subtitle: 'Fetches latest aggregate data from Supabase',
            onTap: () {
              ref.invalidate(optimizationConfigProvider);
            },
          ),
        ],
      ),
    );
  }
}

class _TutorialLifecycleDebugSection extends ConsumerWidget {
  const _TutorialLifecycleDebugSection();

  static const List<String> _tutorialAssets = <String>[
    'assets/tutorials/home.json',
    'assets/tutorials/tasks.json',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(tutorialProgressProvider);

    return _Section(
      label: 'TUTORIAL LIFECYCLE',
      accentColor: AppColors.neonViolet,
      child: Column(
        children: [
          progressAsync.when(
            data: (progress) => _NeonStatusTile(
              title: 'Status',
              subtitle:
                  'started=${progress.started} · introSeen=${progress.hasSeenIntro} · '
                  'version=${progress.contentVersion} · completed=${progress.completedStepIds.length} · '
                  'skipped=${progress.dismissedStepIds.length} · forever=${progress.skippedForeverStepIds.length}',
            ),
            loading: () =>
                const _NeonStatusTile(title: 'Status', subtitle: 'Loading tutorial state...'),
            error: (e, _) => _NeonStatusTile(title: 'Status Error', subtitle: e.toString()),
          ),
          _NeonNavTile(
            title: 'Start Tutorial',
            subtitle: 'Launches the in-app overlay tutorial flow from Home',
            onTap: () => unawaited(_startTutorial(context, ref)),
          ),
          _NeonNavTile(
            title: 'Update Content Version',
            subtitle: 'Applies version migration/reset semantics for tutorial state',
            onTap: () => unawaited(
              ref.read(tutorialProgressProvider.notifier).updateTutorialContentVersion(),
            ),
          ),
          _NeonNavTile(
            title: 'Show First Step Again',
            subtitle: 'Reveals ${TutorialContent.steps.first.id} if hidden or skipped forever',
            onTap: () => unawaited(
              ref.read(tutorialResetServiceProvider).showAgain(TutorialContent.steps.first.id),
            ),
          ),
          _NeonNavTile(
            title: 'Reset Tutorial Progress',
            subtitle: 'Clears completion, skip, and start state for tutorial lifecycle',
            onTap: () => unawaited(ref.read(tutorialResetServiceProvider).resetAll()),
          ),
          _NeonNavTile(
            title: 'Replay Onboarding',
            subtitle: 'Marks onboarding incomplete so onboarding flow can be replayed',
            onTap: () => unawaited(ref.read(tutorialResetServiceProvider).replayOnboarding()),
          ),
        ],
      ),
    );
  }

  Future<void> _startTutorial(BuildContext context, WidgetRef ref) async {
    final progress = ref.read(tutorialProgressProvider).asData?.value;
    final tutorialController = ref.read(tutorialControllerProvider);

    // Ensure definitions are loaded in case this action runs before AppRoot did.
    await tutorialController.loadAssets(_tutorialAssets);
    await tutorialController.start('home_onboarding', restart: true);

    await ref.read(tutorialProgressProvider.notifier).startTutorial();
    ref.read(appFlowProvider.notifier).toCoach();

    if (!context.mounted) {
      return;
    }
    final int completedCount = progress?.completedStepIds.length ?? 0;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          completedCount > 0
              ? 'Tutorial restarted from the beginning on Home.'
              : 'Tutorial started on Home.',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.child, required this.accentColor});
  final String label;
  final Widget child;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF050D1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(color: accentColor.withValues(alpha: 0.06), blurRadius: 16, spreadRadius: -2),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 2,
                  height: 12,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 2.5,
                    color: accentColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          child,
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _NeonToggleTile extends StatelessWidget {
  const _NeonToggleTile({required this.title, required this.value, required this.onChanged});
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.neonCyan,
            activeTrackColor: AppColors.neonCyan.withValues(alpha: 0.3),
            inactiveTrackColor: Colors.white12,
            inactiveThumbColor: Colors.white38,
          ),
        ],
      ),
    );
  }
}

class _NeonNavTile extends StatelessWidget {
  const _NeonNavTile({required this.title, required this.onTap, this.subtitle});
  final String title;
  final VoidCallback onTap;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  if (subtitle != null)
                    Text(
                      subtitle ?? '',
                      maxLines: 3,
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white38, fontSize: 11, height: 1.35),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white38, size: 18),
          ],
        ),
      ),
    );
  }
}

class _NeonStatusTile extends StatelessWidget {
  const _NeonStatusTile({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                Text(
                  subtitle,
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white38, fontSize: 11, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Generic info screen (Privacy Policy / Terms of Service)
// ---------------------------------------------------------------------------

class _InfoScreen extends StatelessWidget {
  const _InfoScreen({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return AnimatedSystemBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.neonCyan.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new,
                          color: AppColors.neonCyan,
                          size: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [AppColors.neonCyan, AppColors.neonViolet],
                      ).createShader(bounds),
                      child: Text(
                        title.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  child: Text(
                    body,
                    style: const TextStyle(fontSize: 13, color: Colors.white60, height: 1.75),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Legal text
// ---------------------------------------------------------------------------

const _kTermsOfService = '''
By using ChronoSpark, you agree to use the app for personal productivity purposes only.

The app is provided "as-is" without warranty of any kind. Task recommendations are generated algorithmically and are not a substitute for professional advice.

Subscription features, where available, are subject to the pricing and terms displayed at point of purchase. Refunds are handled according to the platform's (Apple App Store / Google Play) refund policy.

We reserve the right to modify these terms at any time. Continued use of the app constitutes acceptance of any revised terms.

Last updated: 2025.
''';

const _kSupportInfo = '''
ChronoSpark support:

Website: https://chronospark.app/support

Closed testing notes:
- Tester builds may include bypassed authentication and premium access.
- Live billing is not enabled in QA builds.
- If you encounter an issue, include device model, OS version, and the screen where the issue occurred.

For account or privacy questions, use the support channel listed on the store listing.
''';
