import 'package:fantastic_guacamole/core/debug/app_analytics.dart';
import 'package:fantastic_guacamole/features/profile/ui/widgets/profile_header.dart';
import 'package:fantastic_guacamole/features/profile/ui/widgets/stats_card.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/models/core_values_models.dart';
import 'package:fantastic_guacamole/state/models/profile_view_state.dart';
import 'package:fantastic_guacamole/state/providers/feature_derived_providers.dart';
import 'package:fantastic_guacamole/state/providers/identity_provider.dart';
import 'package:fantastic_guacamole/state/providers/profile_provider.dart';
import 'package:fantastic_guacamole/state/providers/profile_values_provider.dart';
import 'package:fantastic_guacamole/ui/constants/app_assets.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/constants/app_urls.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
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
        'I am using ChronoSpark to run my goals, progression, and focus system.\n'
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

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        ProfileHeader(
          name: data.name,
          level: data.level,
          onOpenSettings: actions.openSettings,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: 104,
              child: StatsCard(
                label: 'LEVEL',
                value: '${data.level}',
                color: AppColors.neonCyan,
                icon: Icons.bolt,
              ),
            ),
            SizedBox(
              width: 104,
              child: StatsCard(
                label: 'XP',
                value: '${data.xp}',
                color: AppColors.memoryAmber,
                icon: Icons.star_outline,
              ),
            ),
            SizedBox(
              width: 104,
              child: StatsCard(
                label: 'STREAK',
                value: '${data.streak}d',
                color: AppColors.neonViolet,
                icon: Icons.local_fire_department,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _NameEditor(initialName: data.name, onSave: actions.updateName),
        const SizedBox(height: 16),
        const _IdentityCard(),
        const SizedBox(height: 16),
        const _ValuesCard(),
        const SizedBox(height: 16),
        _NavButtons(
          onTimeline: () => ref.read(appFlowProvider.notifier).toTimeline(),
          onProgression: actions.openProgression,
          onInviteFriends: () => _inviteFriends(context, state),
        ),
      ],
    );
  }
}

class _IdentityCard extends ConsumerWidget {
  const _IdentityCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(identityStateProvider);
    final notifier = ref.watch(identityStateProvider.notifier);
    final growthTitle = ref.watch(userGrowthTitleProvider);
    final archetype = notifier.archetype;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF050D1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neonViolet.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 2,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.neonViolet,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'ARCHETYPE',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 2.5,
                  color: AppColors.neonViolet,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _ArchetypeBadge(label: archetype, color: AppColors.neonViolet),
              const SizedBox(width: 10),
              _ArchetypeBadge(label: growthTitle, color: AppColors.neonCyan),
            ],
          ),
          const SizedBox(height: 14),
          _IdentityBar(
            label: 'Discipline',
            value: identity.disciplineIdentity,
            color: AppColors.memoryAmber,
          ),
          const SizedBox(height: 8),
          _IdentityBar(
            label: 'Focus',
            value: identity.focusIdentity,
            color: AppColors.neonCyan,
          ),
          const SizedBox(height: 8),
          _IdentityBar(
            label: 'Growth',
            value: identity.growthIdentity,
            color: AppColors.neonViolet,
          ),
        ],
      ),
    );
  }
}

class _ArchetypeBadge extends StatelessWidget {
  const _ArchetypeBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
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

class _ValuesCard extends ConsumerWidget {
  const _ValuesCard();

  Future<void> _toggle(WidgetRef ref, String value) {
    return ref.read(profileValuesProvider.notifier).toggle(value);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Set<String> selected = ref.watch(profileValuesProvider);
    final CoreValuesAlignment alignment = ref.watch(
      coreValuesAlignmentProvider,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF050D1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 2,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.neonCyan,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'CORE VALUES',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 2.5,
                  color: AppColors.neonCyan,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Alignment ${alignment.overall}% · Strongest ${coreValueTitle(alignment.strongest)} · Needs focus ${coreValueTitle(alignment.mostNeglected)}',
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 11,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: CoreValueType.values.map((CoreValueType value) {
              final String title = coreValueTitle(value);
              final bool sel = selected.contains(title);
              final int score = alignment.scores[value]?.score ?? 0;
              return GestureDetector(
                onTap: () => _toggle(ref, title),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: sel
                        ? AppColors.neonCyan.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sel
                          ? AppColors.neonCyan.withValues(alpha: 0.7)
                          : Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Text(
                    '$title $score%',
                    style: TextStyle(
                      color: sel ? AppColors.neonCyan : Colors.white54,
                      fontSize: 12,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          ...CoreValueType.values
              .where((CoreValueType value) {
                return selected.contains(coreValueTitle(value));
              })
              .map((CoreValueType value) {
                final CoreValueDefinition definition =
                    coreValueDefinitions[value]!;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          definition.title,
                          style: const TextStyle(
                            color: AppColors.neonCyan,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          definition.definition,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Guiding question: ${definition.guidingQuestion}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
        ],
      ),
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
      children: [
        Row(
          children: [
            Expanded(
              child: _NavBtn(
                label: 'TIMELINE OPS',
                icon: Icons.timeline_rounded,
                color: AppColors.neonViolet,
                onTap: onTimeline,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _NavBtn(
                label: 'PROGRESSION INTEL',
                icon: Icons.bolt,
                color: AppColors.memoryAmber,
                onTap: onProgression,
              ),
            ),
          ],
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NameEditor extends StatefulWidget {
  const _NameEditor({required this.initialName, required this.onSave});

  final String initialName;
  final ValueChanged<String> onSave;

  @override
  State<_NameEditor> createState() => _NameEditorState();
}

class _NameEditorState extends State<_NameEditor> {
  late final TextEditingController _controller;

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

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF050D1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neonViolet.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: AppColors.neonViolet.withValues(alpha: 0.06),
            blurRadius: 20,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 2,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.neonViolet,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'IDENTITY',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 2.5,
                  color: AppColors.neonViolet,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
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
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: AppColors.neonViolet.withValues(alpha: 0.2),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: AppColors.neonViolet.withValues(alpha: 0.2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () {
                final String nextName = _controller.text.trim();
                if (nextName.isEmpty) return;
                widget.onSave(nextName);
              },
              child: const Text('Update Identity'),
            ),
          ),
        ],
      ),
    );
  }
}
