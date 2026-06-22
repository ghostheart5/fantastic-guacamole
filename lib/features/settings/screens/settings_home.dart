import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../ui/widgets/chronospark_bottom_nav.dart';
import '../../../ui/widgets/panel_container.dart';
import '../../../ui/widgets/section_header.dart';
import '../../../core/di/app_locator.dart';
import '../controllers/settings_controller.dart';
import '../widgets/module_toggle_tile.dart';
import '../widgets/theme_settings_tile.dart';

class SettingsHome extends StatefulWidget {
  const SettingsHome({super.key});

  @override
  State<SettingsHome> createState() => _SettingsHomeState();
}

class _SettingsHomeState extends State<SettingsHome> {
  final SettingsController _controller = AppLocator.instance
      .settingsController();
  late SettingsState _state;
  bool _encryption = true;
  bool _permissionsLock = true;
  bool _accountShield = true;

  Future<void> _launchLegalUrl(BuildContext context, String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _state = _controller.read();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.md),
        children: <Widget>[
          const SectionHeader(
            title: 'System Settings',
            subtitle: 'Tune themes, modules, notifications, and data behavior.',
          ),
          PanelContainer(
            title: 'Appearance and Layout',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ThemeSettingsTile(
                  value: _state.neonRecall,
                  onChanged: (bool value) {
                    setState(() => _state = _controller.setNeonRecall(value));
                  },
                ),
                const SizedBox(height: AppSizes.xs),
                const Text('Visual Effects: Holographic glow enabled'),
                const Text('Layout: Adaptive command panels active'),
                const SizedBox(height: AppSizes.sm),
                ModuleToggleTile(
                  label: 'Compact Mode',
                  subtitle: 'Reduce spacing for dense planning',
                  value: _state.compactMode,
                  onChanged: (bool value) {
                    setState(() => _state = _controller.setCompactMode(value));
                  },
                ),
                Text('Text Scale: ${_state.textScale.toStringAsFixed(2)}x'),
                Slider(
                  value: _state.textScale,
                  min: 0.85,
                  max: 1.35,
                  divisions: 10,
                  label: _state.textScale.toStringAsFixed(2),
                  onChanged: (double value) {
                    setState(() => _state = _controller.setTextScale(value));
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.md),
          PanelContainer(
            title: 'Modules',
            child: Column(
              children: <Widget>[
                ModuleToggleTile(
                  label: 'SI Module',
                  subtitle: 'Enable or disable SI computation surfaces',
                  value: _state.siEnabled,
                  onChanged: (bool value) {
                    setState(() => _state = _controller.setSiEnabled(value));
                  },
                ),
                ModuleToggleTile(
                  label: 'Notifications',
                  subtitle: 'Receive pulse and mission reminders',
                  value: _state.notifications,
                  onChanged: (bool value) {
                    setState(
                      () => _state = _controller.setNotifications(value),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.md),
          PanelContainer(
            title: 'Notifications',
            child: Wrap(
              spacing: AppSizes.sm,
              children: <Widget>[
                FilterChip(
                  label: const Text('Alerts'),
                  selected: _state.notifications,
                  onSelected: (_) {},
                ),
                FilterChip(
                  label: const Text('Reminders'),
                  selected: _state.notifications,
                  onSelected: (_) {},
                ),
                FilterChip(
                  label: const Text('Mission Prompts'),
                  selected: _state.notifications,
                  onSelected: (_) {},
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.md),
          PanelContainer(
            title: 'Data Management',
            child: Wrap(
              spacing: AppSizes.sm,
              runSpacing: AppSizes.sm,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.ios_share),
                  label: const Text('Export'),
                ),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.file_download),
                  label: const Text('Import'),
                ),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.backup),
                  label: const Text('Backup'),
                ),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.restore),
                  label: const Text('Restore'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.md),
          PanelContainer(
            title: 'Privacy and Security',
            child: Column(
              children: <Widget>[
                SwitchListTile(
                  title: const Text('App Lock'),
                  subtitle: const Text('Require lock on app open'),
                  value: _encryption,
                  onChanged: (bool value) =>
                      setState(() => _encryption = value),
                ),
                SwitchListTile(
                  title: const Text('Biometric Unlock'),
                  subtitle: const Text(
                    'Use device biometrics for quick unlock',
                  ),
                  value: _permissionsLock,
                  onChanged: (bool value) =>
                      setState(() => _permissionsLock = value),
                ),
                SwitchListTile(
                  title: const Text('Analytics Sharing'),
                  subtitle: const Text('Share anonymous usage analytics'),
                  value: _accountShield,
                  onChanged: (bool value) =>
                      setState(() => _accountShield = value),
                ),
                ListTile(
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => _launchLegalUrl(
                    context,
                    'https://ghostheart5.github.io/fantastic-guacamole/privacy/',
                  ),
                ),
                ListTile(
                  title: const Text('Terms of Service'),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => _launchLegalUrl(
                    context,
                    'https://ghostheart5.github.io/fantastic-guacamole/terms/',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.md),
          PanelContainer(
            title: 'Paywall and Access',
            child: Wrap(
              spacing: AppSizes.sm,
              runSpacing: AppSizes.sm,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Opening plans and pricing...'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.workspace_premium),
                  label: const Text('View Plans'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Restoring paid access...')),
                    );
                  },
                  icon: const Icon(Icons.lock_open),
                  label: const Text('Restore Access'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.md),
          PanelContainer(
            title: 'System Reset',
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() => _state = _controller.resetData());
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Settings reset to defaults')),
                  );
                },
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset Settings Data'),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const ChronoSparkBottomNav(selectedIndex: 5),
    );
  }
}
