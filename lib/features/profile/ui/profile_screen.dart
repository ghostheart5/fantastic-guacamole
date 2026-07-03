import 'package:fantastic_guacamole/core/constants/app_colors.dart';
import 'package:fantastic_guacamole/core/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/engine/si/offline/user_growth_engine.dart';
import 'package:fantastic_guacamole/features/profile/services/profile_provider.dart';
import 'package:fantastic_guacamole/features/profile/state/profile_state.dart';
import 'package:fantastic_guacamole/features/profile/ui/widgets/profile_header.dart';
import 'package:fantastic_guacamole/features/profile/ui/widgets/stats_card.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/providers/identity_provider.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _userGrowthProvider = Provider<UserGrowthState>((ref) {
  final profile = ref.watch(profileProvider);
  final traj = ref.watch(trajectorySummaryProvider);
  final consistency = traj.momentum > 0.6 ? 0.9 : traj.momentum > 0.3 ? 0.6 : 0.3;
  return const UserGrowthEngine().update(
    const UserGrowthState(),
    completedTasks: profile.xp ~/ 10,
    streak: profile.streak,
    consistency: consistency,
  );
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileViewStateProvider);

    return AnimatedSystemBackground(
      backgroundAssetPath: 'assets/backgrounds/profile_bg.jpg',
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
          onOpenProgression: actions.openProgression,
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
          onSettings: actions.openSettings,
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
    final growth = ref.watch(_userGrowthProvider);
    final archetype = notifier.archetype;
    final growthTitle = const UserGrowthEngine().growthTitle(growth);

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
                width: 2, height: 14,
                decoration: BoxDecoration(
                  color: AppColors.neonViolet,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(width: 8),
              const Text('ARCHETYPE', style: TextStyle(
                fontSize: 10, letterSpacing: 2.5,
                color: AppColors.neonViolet, fontWeight: FontWeight.w700,
              )),
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
          _IdentityBar(label: 'Discipline', value: identity.disciplineIdentity, color: AppColors.memoryAmber),
          const SizedBox(height: 8),
          _IdentityBar(label: 'Focus', value: identity.focusIdentity, color: AppColors.neonCyan),
          const SizedBox(height: 8),
          _IdentityBar(label: 'Growth', value: identity.growthIdentity, color: AppColors.neonViolet),
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
      child: Text(label, style: TextStyle(
        color: color, fontSize: 12, fontWeight: FontWeight.w700,
      )),
    );
  }
}

class _IdentityBar extends StatelessWidget {
  const _IdentityBar({required this.label, required this.value, required this.color});
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 70, child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11))),
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
        Text('${(value * 100).round()}%', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _ValuesCard extends ConsumerStatefulWidget {
  const _ValuesCard();

  @override
  ConsumerState<_ValuesCard> createState() => _ValuesCardState();
}

class _ValuesCardState extends ConsumerState<_ValuesCard> {
  static const _key = 'profile_values';
  static const _allValues = [
    'Discipline', 'Growth', 'Clarity',
    'Resilience', 'Creativity', 'Connection',
  ];
  Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    final raw = SharedPrefsService.load(_key);
    if (raw != null) {
      _selected = raw.split(',').where((s) => s.isNotEmpty).toSet();
    }
  }

  Future<void> _toggle(String value) async {
    setState(() {
      if (_selected.contains(value)) {
        _selected = Set.from(_selected)..remove(value);
      } else {
        _selected = Set.from(_selected)..add(value);
      }
    });
    await SharedPrefsService.save(_key, _selected.join(','));
  }

  @override
  Widget build(BuildContext context) {
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
              Container(width: 2, height: 14,
                decoration: BoxDecoration(color: AppColors.neonCyan, borderRadius: BorderRadius.circular(1))),
              const SizedBox(width: 8),
              const Text('CORE VALUES', style: TextStyle(
                fontSize: 10, letterSpacing: 2.5,
                color: AppColors.neonCyan, fontWeight: FontWeight.w700,
              )),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allValues.map((v) {
              final sel = _selected.contains(v);
              return GestureDetector(
                onTap: () => _toggle(v),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.neonCyan.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sel ? AppColors.neonCyan.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Text(v, style: TextStyle(
                    color: sel ? AppColors.neonCyan : Colors.white54,
                    fontSize: 12,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                  )),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _NavButtons extends StatelessWidget {
  const _NavButtons({required this.onTimeline, required this.onSettings});
  final VoidCallback onTimeline;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _NavBtn(
            label: 'TIMELINE',
            icon: Icons.timeline_rounded,
            color: AppColors.neonViolet,
            onTap: onTimeline,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _NavBtn(
            label: 'SETTINGS',
            icon: Icons.settings_outlined,
            color: AppColors.neonCyan,
            onTap: onSettings,
          ),
        ),
      ],
    );
  }
}

class _NavBtn extends StatelessWidget {
  const _NavBtn({required this.label, required this.icon, required this.color, required this.onTap});
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
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
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
              hintText: 'Enter profile name',
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
              child: const Text('Update Name'),
            ),
          ),
        ],
      ),
    );
  }
}
