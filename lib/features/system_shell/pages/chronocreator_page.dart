import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/state/app_state.dart';
import '../../../ui/system/glass_panel.dart';

class ChronoCreatorPage extends StatelessWidget {
  const ChronoCreatorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 980) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: const <Widget>[
              _CreatorModules(),
              SizedBox(height: 12),
              _CreatorForm(),
              SizedBox(height: 12),
              _CreatorSuggestions(),
            ],
          );
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const <Widget>[
              Expanded(flex: 2, child: _CreatorModules()),
              SizedBox(width: 12),
              Expanded(flex: 4, child: _CreatorForm()),
              SizedBox(width: 12),
              Expanded(flex: 3, child: _CreatorSuggestions()),
            ],
          ),
        );
      },
    );
  }
}

class _CreatorModules extends StatelessWidget {
  const _CreatorModules();

  @override
  Widget build(BuildContext context) {
    return const GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Modules',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8),
          Text('Task/Event', style: TextStyle(color: Color(0xFFD8D0E6))),
          Text('Goals', style: TextStyle(color: Color(0xFFD8D0E6))),
          Text('Routines', style: TextStyle(color: Color(0xFFD8D0E6))),
        ],
      ),
    );
  }
}

class _CreatorForm extends StatefulWidget {
  const _CreatorForm();

  @override
  State<_CreatorForm> createState() => _CreatorFormState();
}

class _CreatorFormState extends State<_CreatorForm> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _intentController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _intentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Creation Form',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _intentController,
            decoration: const InputDecoration(labelText: 'Intent'),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () {
                final String title = _nameController.text.trim();
                if (title.isEmpty) {
                  return;
                }
                context.read<AppState>().addTask(
                  title: title,
                  priority: 7,
                  hasDeadline: _intentController.text.toLowerCase().contains('deadline'),
                );
                _nameController.clear();
                _intentController.clear();
              },
              icon: const Icon(Icons.add_task_outlined),
              label: const Text('Create Task'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreatorSuggestions extends StatelessWidget {
  const _CreatorSuggestions();

  @override
  Widget build(BuildContext context) {
    return const GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'SI Suggestions',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8),
          Text(
            'Split large objective into 3 executable units',
            style: TextStyle(color: Color(0xFFD8D0E6)),
          ),
          Text(
            'Assign one deadline-critical block in Temporal Ops',
            style: TextStyle(color: Color(0xFFD8D0E6)),
          ),
        ],
      ),
    );
  }
}
