import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../ui/widgets/chronospark_bottom_nav.dart';
import '../../../ui/widgets/panel_container.dart';
import '../../../ui/widgets/section_header.dart';
import '../../../core/di/app_locator.dart';
import '../controllers/chronologs_controller.dart';

class ChronoLogsHome extends StatefulWidget {
  const ChronoLogsHome({super.key});

  @override
  State<ChronoLogsHome> createState() => _ChronoLogsHomeState();
}

class _ChronoLogsHomeState extends State<ChronoLogsHome> {
  final ChronoLogsController _controller = AppLocator.instance
      .chronoLogsController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  ChronoLogsState? _state;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final ChronoLogsState state = await _controller.load();
    if (!mounted) {
      return;
    }
    setState(() => _state = state);
  }

  Future<void> _addNote() async {
    final ChronoLogsState? state = _state;
    if (state == null) {
      return;
    }
    final ChronoLogsState next = await _controller.addNote(
      state,
      _noteController.text,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _state = next;
      _noteController.clear();
    });
  }

  Future<void> _archiveNow() async {
    final ChronoLogsState? state = _state;
    if (state == null) {
      return;
    }
    final ChronoLogsState next = await _controller.archiveCompleted(state);
    if (!mounted) {
      return;
    }
    setState(() => _state = next);
  }

  @override
  Widget build(BuildContext context) {
    final ChronoLogsState? state = _state;
    if (state == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    Widget listItems(List<String> items) {
      final List<String> filtered = _search.trim().isEmpty
          ? items
          : items
                .where(
                  (String item) =>
                      item.toLowerCase().contains(_search.toLowerCase()),
                )
                .toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: filtered
            .map(
              (String item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text('- $item'),
              ),
            )
            .toList(),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('ChronoLogs')),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.md),
        children: <Widget>[
          const SectionHeader(
            title: 'Classified Memory Archive',
            subtitle:
                'Cold storage, metallic records, redacted mission memory vault.',
          ),
          PanelContainer(
            title: 'Log Actions',
            child: Column(
              children: <Widget>[
                TextField(
                  controller: _noteController,
                  decoration: const InputDecoration(
                    hintText: 'Add note to ChronoLogs',
                  ),
                  onSubmitted: (_) => _addNote(),
                ),
                const SizedBox(height: AppSizes.sm),
                Row(
                  children: <Widget>[
                    FilledButton(
                      onPressed: _addNote,
                      child: const Text('Save Note'),
                    ),
                    const SizedBox(width: AppSizes.sm),
                    OutlinedButton(
                      onPressed: _archiveNow,
                      child: const Text('Archive Snapshot'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.sm),
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search and Retrieval: find records in vault',
                  ),
                  onChanged: (String value) => setState(() => _search = value),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.md),
          PanelContainer(
            title: 'Mission Archive | Completed Tasks',
            child: listItems(state.completedTasks),
          ),
          const SizedBox(height: AppSizes.md),
          PanelContainer(
            title: 'Mission Archive | Completed Missions',
            child: listItems(state.pastMissions),
          ),
          const SizedBox(height: AppSizes.md),
          PanelContainer(
            title: 'Schedule Archive',
            child: listItems(state.pastSchedules),
          ),
          const SizedBox(height: AppSizes.md),
          PanelContainer(title: 'Notes Vault', child: listItems(state.notes)),
          const SizedBox(height: AppSizes.md),
          PanelContainer(
            title: 'Operational Timeline | Daily Logs',
            child: listItems(state.dailyLogs),
          ),
          const SizedBox(height: AppSizes.md),
          PanelContainer(
            title: 'Archived Events',
            child: listItems(state.archivedEvents),
          ),
          const SizedBox(height: AppSizes.md),
          PanelContainer(
            title: 'Old Routines',
            child: listItems(state.oldRoutines),
          ),
          const SizedBox(height: AppSizes.md),
          PanelContainer(title: 'Archives', child: listItems(state.archives)),
          const SizedBox(height: AppSizes.md),
          const PanelContainer(
            title: 'Boundary Notice',
            child: Text(
              'ChronoLogs does not store thoughts, emotions, reflections, or mood tracking. Those belong to SI Console.',
            ),
          ),
        ],
      ),
      bottomNavigationBar: const ChronoSparkBottomNav(selectedIndex: 2),
    );
  }
}
