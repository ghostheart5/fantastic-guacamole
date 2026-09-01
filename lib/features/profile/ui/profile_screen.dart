import 'package:fantastic_guacamole/config/launch_containment.dart';
import 'package:fantastic_guacamole/ui/navigation/app_view_navigation.dart';
import 'package:fantastic_guacamole/core/debug/app_analytics.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/models/profile_view_state.dart';
import 'package:fantastic_guacamole/state/providers/feature_derived_providers.dart';
import 'package:fantastic_guacamole/state/providers/identity_provider.dart';
import 'package:fantastic_guacamole/state/providers/profile_provider.dart';
import 'package:fantastic_guacamole/ui/constants/app_assets.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/constants/app_sizes.dart';
import 'package:fantastic_guacamole/ui/constants/app_urls.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:fantastic_guacamole/ui/system/temporal_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileViewStateProvider);

    return AnimatedSystemBackground(
      backgroundAssetPath: AppAssets.bgProfile,
      overlayOpacity: .52,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(child: _ProfileBody(state: state)),
      ),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({required this.state});
  final ProfileViewState state;

  Future<void> _inviteFriends(
    BuildContext context,
    ProfileViewState state,
  ) async {
    final String text =
        'I am using ChronoSpark to run my goals, progression, and execution system.\n'
        'Join me: ${AppUrls.website}\n'
        'Current streak: ${state.profile.streak}d | Level ${state.profile.level}';
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          title: 'Join me on ChronoSpark',
          subject: 'Invite to ChronoSpark',
        ),
      );
      AppAnalytics.track(
        'invite_friends_shared',
        params: <String, Object?>{'method': 'share_sheet'},
      );
      return;
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      AppAnalytics.track(
        'invite_friends_shared',
        params: <String, Object?>{'method': 'clipboard_fallback'},
      );
    }
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share sheet unavailable. Invite copied to clipboard.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.watch(profileActionsProvider);
    final data = state.profile;
    final identity = ref.watch(identityStateProvider);
    final bool hasIdentityEvidence =
        LaunchContainment.inferredIdentityEnabled &&
        ref.watch(
          trajectorySummaryProvider.select(
            (summary) => summary.completedTasks >= 3,
          ),
        ) &&
        identity.hasMeaningfulEvidence;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _ProfileTitle(
          onOpenSettings: () => goToAppView(context, ref, AppView.settings),
        ),
        const SizedBox(height: 18),
        _IdentityConstellation(
          name: data.name,
          level: data.level,
          hasEvidence: hasIdentityEvidence,
        ),
        const SizedBox(height: 18),
        _ProfileMetrics(level: data.level, xp: data.xp, streak: data.streak),
        const SizedBox(height: 16),
        _NameEditor(initialName: data.name, onSave: actions.updateName),
        const SizedBox(height: 16),
        _IdentityCard(hasEvidence: hasIdentityEvidence),
        const SizedBox(height: 16),
        _NavButtons(
          onTimeline: () => goToAppView(context, ref, AppView.timeline),
          onProgression: () => goToAppView(context, ref, AppView.progression),
          onInviteFriends: () => _inviteFriends(context, state),
        ),
      ],
    );
  }
}

class _ProfileTitle extends StatelessWidget {
  const _ProfileTitle({required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return TemporalScreenHeader(
      title: 'PROFILE',
      subtitle: 'Your patterns, held with context.',
      eyebrow: 'Identity constellation',
      trailing: IconButton(
        tooltip: 'Open settings',
        constraints: const BoxConstraints.tightFor(
          width: AppSizes.touchTarget,
          height: AppSizes.touchTarget,
        ),
        onPressed: onOpenSettings,
        icon: const Icon(Icons.settings),
      ),
    );
  }
}

class _IdentityConstellation extends ConsumerWidget {
  const _IdentityConstellation({
    required this.name,
    required this.level,
    required this.hasEvidence,
  });

  final String name;
  final int level;
  final bool hasEvidence;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(identityStateProvider);
    final String archetype = ref
        .watch(identityStateProvider.notifier)
        .archetype;
    final String evidenceLabel = hasEvidence
        ? 'Discipline ${(identity.disciplineIdentity * 100).round()} percent, '
              'execution ${(identity.executionIdentity * 100).round()} percent, '
              'growth ${(identity.growthIdentity * 100).round()} percent.'
        : 'Identity pattern is still forming.';
    return Semantics(
      container: true,
      label:
          '${name.isEmpty ? 'ChronoSpark user' : name}, level $level. '
          '$evidenceLabel',
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 250,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                const CustomPaint(painter: _ConstellationPainter()),
                Align(
                  alignment: const Alignment(0, .04),
                  child: Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.bgSecondary.withValues(alpha: .86),
                      border: Border.all(
                        color: AppColors.neonCyan.withValues(alpha: .68),
                        width: 2,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: AppColors.neonCyan.withValues(alpha: .32),
                          blurRadius: 28,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      color: AppColors.neonCyan,
                      size: 46,
                    ),
                  ),
                ),
                Positioned(
                  top: 14,
                  right: 4,
                  child: _ConstellationLabel(
                    label: 'GROWTH',
                    value: identity.growthIdentity,
                    showValue: hasEvidence,
                    accent: AppColors.neonViolet,
                    textAlign: TextAlign.right,
                  ),
                ),
                Positioned(
                  top: 106,
                  left: 4,
                  child: _ConstellationLabel(
                    label: 'DISCIPLINE',
                    value: identity.disciplineIdentity,
                    showValue: hasEvidence,
                    accent: AppColors.memoryAmber,
                  ),
                ),
                Positioned(
                  right: 4,
                  bottom: 14,
                  child: _ConstellationLabel(
                    label: 'EXECUTION',
                    value: identity.executionIdentity,
                    showValue: hasEvidence,
                    accent: AppColors.neonCyan,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          Text(
            name.trim().isEmpty ? 'CHRONOSPARK USER' : name.toUpperCase(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${hasEvidence ? archetype : 'PATTERN FORMING'}  ·  CHRONOSPARK LEVEL $level',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.neonViolet,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConstellationLabel extends StatelessWidget {
  const _ConstellationLabel({
    required this.label,
    required this.value,
    required this.accent,
    required this.showValue,
    this.textAlign = TextAlign.left,
  });

  final String label;
  final double value;
  final Color accent;
  final bool showValue;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      child: Text(
        showValue ? '$label ${(value * 100).round()}%' : '$label LEARNING',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: textAlign,
        style: TextStyle(
          color: accent,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _ConstellationPainter extends CustomPainter {
  const _ConstellationPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width * .5, size.height * .52);
    final Paint orbit = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final ({double radius, Color color}) item
        in <({double radius, Color color})>[
          (radius: size.shortestSide * .30, color: AppColors.neonCyan),
          (radius: size.shortestSide * .42, color: AppColors.neonViolet),
          (radius: size.shortestSide * .50, color: AppColors.memoryAmber),
        ]) {
      orbit.color = item.color.withValues(alpha: .28);
      canvas.drawCircle(center, item.radius, orbit);
    }
    final Paint thread = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final List<({Offset end, Color color})> endpoints =
        <({Offset end, Color color})>[
          (
            end: Offset(size.width * .82, size.height * .16),
            color: AppColors.neonViolet,
          ),
          (
            end: Offset(size.width * .16, size.height * .48),
            color: AppColors.memoryAmber,
          ),
          (
            end: Offset(size.width * .82, size.height * .86),
            color: AppColors.neonCyan,
          ),
        ];
    for (final ({Offset end, Color color}) endpoint in endpoints) {
      thread.color = endpoint.color.withValues(alpha: .55);
      final Path path = Path()
        ..moveTo(center.dx, center.dy)
        ..quadraticBezierTo(
          (center.dx + endpoint.end.dx) / 2,
          center.dy,
          endpoint.end.dx,
          endpoint.end.dy,
        );
      canvas.drawPath(path, thread);
      canvas.drawCircle(endpoint.end, 3, Paint()..color = endpoint.color);
    }
  }

  @override
  bool shouldRepaint(covariant _ConstellationPainter oldDelegate) => false;
}

class _ProfileMetrics extends StatelessWidget {
  const _ProfileMetrics({
    required this.level,
    required this.xp,
    required this.streak,
  });

  final int level;
  final int xp;
  final int streak;

  @override
  Widget build(BuildContext context) {
    return TemporalGlassSurface(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      accent: AppColors.memoryAmber,
      child: Row(
        children: <Widget>[
          Expanded(
            child: _ProfileMetric(
              label: 'LEVEL',
              value: '$level',
              accent: AppColors.memoryAmber,
            ),
          ),
          const _MetricDivider(),
          Expanded(
            child: _ProfileMetric(
              label: 'XP',
              value: '$xp',
              accent: AppColors.neonViolet,
            ),
          ),
          const _MetricDivider(),
          Expanded(
            child: _ProfileMetric(
              label: 'STREAK',
              value: '${streak}d',
              accent: AppColors.neonCyan,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileMetric extends StatelessWidget {
  const _ProfileMetric({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.fade,
          softWrap: false,
          style: TextStyle(
            color: accent,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 48,
      color: Colors.white.withValues(alpha: .12),
    );
  }
}

class _IdentityCard extends ConsumerWidget {
  const _IdentityCard({required this.hasEvidence});

  final bool hasEvidence;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(identityStateProvider);
    final notifier = ref.watch(identityStateProvider.notifier);
    final growthTitle = ref.watch(userGrowthTitleProvider);
    final archetype = notifier.archetype;

    return TemporalGlassSurface(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      accent: AppColors.neonViolet,
      opacity: .9,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'IDENTITY SIGNAL',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 0,
              color: AppColors.neonViolet,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: <Widget>[
              _ArchetypeLabel(
                label: hasEvidence ? archetype : 'Pattern forming',
                color: AppColors.neonViolet,
              ),
              if (hasEvidence)
                _ArchetypeLabel(label: growthTitle, color: AppColors.neonCyan),
            ],
          ),
          if (!hasEvidence) ...<Widget>[
            const SizedBox(height: 8),
            const Text(
              'Complete a few tasks to reveal patterns grounded in your activity.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ] else ...<Widget>[
            const SizedBox(height: 14),
            _IdentityBar(
              label: 'Discipline',
              value: identity.disciplineIdentity,
              color: AppColors.memoryAmber,
            ),
            const SizedBox(height: 8),
            _IdentityBar(
              label: 'Execution',
              value: identity.executionIdentity,
              color: AppColors.neonCyan,
            ),
            const SizedBox(height: 8),
            _IdentityBar(
              label: 'Growth',
              value: identity.growthIdentity,
              color: AppColors.neonViolet,
            ),
          ],
        ],
      ),
    );
  }
}

class _ArchetypeLabel extends StatelessWidget {
  const _ArchetypeLabel({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    );
  }
}

class _IdentityBar extends StatelessWidget {
  const _IdentityBar({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: value,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 4,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${(value * 100).round()}%',
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _NavButtons extends StatelessWidget {
  const _NavButtons({
    required this.onTimeline,
    required this.onProgression,
    required this.onInviteFriends,
  });
  final VoidCallback onTimeline;
  final VoidCallback onProgression;
  final VoidCallback onInviteFriends;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _NavBtn(
          label: 'VIEW TIMELINE',
          icon: Icons.timeline_rounded,
          color: AppColors.neonViolet,
          onTap: onTimeline,
        ),
        const SizedBox(height: 10),
        _NavBtn(
          label: 'PROGRESSION',
          icon: Icons.bolt,
          color: AppColors.memoryAmber,
          onTap: onProgression,
        ),
        const SizedBox(height: 10),
        _NavBtn(
          label: 'INVITE FRIENDS',
          icon: Icons.group_add_rounded,
          color: AppColors.neonCyan,
          onTap: onInviteFriends,
        ),
      ],
    );
  }
}

class _NavBtn extends StatelessWidget {
  const _NavBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TemporalActionButton(
      label: label,
      icon: icon,
      accent: color,
      filled: false,
      onPressed: onTap,
    );
  }
}

class _NameEditor extends StatefulWidget {
  const _NameEditor({required this.initialName, required this.onSave});

  final String initialName;
  final Future<void> Function(String value) onSave;

  @override
  State<_NameEditor> createState() => _NameEditorState();
}

class _NameEditorState extends State<_NameEditor> {
  late final TextEditingController _controller;
  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void didUpdateWidget(covariant _NameEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialName != widget.initialName &&
        _controller.text != widget.initialName) {
      _controller.text = widget.initialName;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String nextName = _controller.text.trim();
    if (nextName.isEmpty || _saving) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await widget.onSave(nextName);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saveError = 'Unable to update your profile. Try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return TemporalGlassSurface(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      accent: AppColors.neonCyan,
      opacity: .9,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'EDIT IDENTITY',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 0,
              color: AppColors.neonCyan,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Enter identity callsign',
              hintStyle: const TextStyle(color: Colors.white30),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.03),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: AppColors.neonViolet.withValues(alpha: 0.2),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: AppColors.neonViolet.withValues(alpha: 0.2),
                ),
              ),
            ),
          ),
          if (_saveError case final String message) ...[
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSizes.touchTarget),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Update Identity'),
            ),
          ),
        ],
      ),
    );
  }
}
