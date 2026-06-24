import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../data/services/workspace_store_service.dart';
import '../../../ui/layout/holo_background.dart';
import '../../../ui/widgets/chronospark_bottom_nav.dart';
import '../../../ui/widgets/panel_container.dart';

class SIConsoleHome extends StatefulWidget {
  const SIConsoleHome({super.key});

  @override
  State<SIConsoleHome> createState() => _SIConsoleHomeState();
}

class _SIConsoleHomeState extends State<SIConsoleHome> {
  final WorkspaceStoreService _store = WorkspaceStoreService();
  final TextEditingController _reflectionController = TextEditingController();
  final List<String> _reflections = <String>[];
  final double _cognitiveLoad = 0.68;
  double _stressLevel = 0.34;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void dispose() {
    _reflectionController.dispose();
    super.dispose();
  }

  void _addReflection() {
    final String text = _reflectionController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a value before submitting.')),
      );
      return;
    }
    setState(() {
      _reflections.insert(0, text);
      _reflectionController.clear();
    });
    _persistState();
  }

  Future<void> _loadState() async {
    final SIWorkspaceState state = await _store.loadSiState();
    if (!mounted) {
      return;
    }

    setState(() {
      _reflections
        ..clear()
        ..addAll(state.reflections);
      _stressLevel = state.stressLevel;
    });
  }

  Future<void> _persistState() async {
    await _store.saveSiState(
      SIWorkspaceState(reflections: List<String>.from(_reflections), stressLevel: _stressLevel),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HoloBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSizes.md),
            children: <Widget>[
              const PanelContainer(
                title: 'SI CONSOLE',
                child: Text(
                  'Reflection console, cognitive diagnostics, and neural pattern analysis.',
                ),
              ),
              const SizedBox(height: AppSizes.md),
              PanelContainer(
                title: 'Reflections Console',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    TextField(
                      controller: _reflectionController,
                      decoration: const InputDecoration(hintText: 'Log reflection...'),
                      onSubmitted: (_) => _addReflection(),
                    ),
                    const SizedBox(height: AppSizes.sm),
                    FilledButton(onPressed: _addReflection, child: const Text('Save Reflection')),
                    const SizedBox(height: AppSizes.sm),
                    ..._reflections
                        .take(4)
                        .map(
                          (String item) => Padding(
                            padding: const EdgeInsets.only(bottom: AppSizes.xs),
                            child: Text('- $item'),
                          ),
                        ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.md),
              PanelContainer(
                title: 'Cognitive Load Monitor',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Current load: ${(_cognitiveLoad * 100).toStringAsFixed(0)}%'),
                    const SizedBox(height: AppSizes.xs),
                    LinearProgressIndicator(value: _cognitiveLoad),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.md),
              PanelContainer(
                title: 'Stress Monitor',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Stress level: ${(_stressLevel * 100).toStringAsFixed(0)}%'),
                    Slider(
                      value: _stressLevel,
                      min: 0,
                      max: 1,
                      onChanged: (double value) {
                        setState(() => _stressLevel = value);
                        _persistState();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.md),
              const PanelContainer(
                title: 'Behavior Analysis',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('- Recurring habit: late-day context switching around 3 PM.'),
                    Text('- Recurring habit: high consistency in morning mission starts.'),
                    Text('- Trigger pattern: stress spikes after stacked meetings.'),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.md),
              const PanelContainer(
                title: 'Cognitive Diagnostics',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Working memory pressure: Moderate'),
                    SizedBox(height: AppSizes.xs),
                    Text('Attention stability: High'),
                    SizedBox(height: AppSizes.xs),
                    Text('Decision fatigue risk: Low to Moderate'),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.md),
              const PanelContainer(
                title: 'Neural Pattern Analysis',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('- Pattern link: focus improves after reflection logging.'),
                    Text('- Pattern link: load decreases with pre-commitment windows.'),
                    Text('- Pattern link: stress reduced by single-thread tasking.'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const ChronoSparkBottomNav(selectedIndex: 4),
    );
  }
}
