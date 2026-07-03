import 'package:fantastic_guacamole/core/constants/app_colors.dart';
import 'package:fantastic_guacamole/features/profile/services/profile_provider.dart';
import 'package:fantastic_guacamole/features/profile/state/profile_state.dart';
import 'package:fantastic_guacamole/features/profile/ui/widgets/profile_header.dart';
import 'package:fantastic_guacamole/features/profile/ui/widgets/stats_card.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      ],
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
