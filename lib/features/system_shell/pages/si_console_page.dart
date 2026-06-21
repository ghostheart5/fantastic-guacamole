import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/state/app_state.dart';
import '../../../ui/system/glass_panel.dart';

class SiConsolePage extends StatefulWidget {
  const SiConsolePage({super.key});

  @override
  State<SiConsolePage> createState() => _SiConsolePageState();
}

class _SiConsolePageState extends State<SiConsolePage> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleInput(BuildContext context) async {
    final String input = _controller.text.trim();
    if (input.isEmpty) {
      return;
    }

    final AppState appState = Provider.of<AppState>(context, listen: false);
    await appState.updateFromConsole(input);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final AppState appState = Provider.of<AppState>(context);
    final List<String> messages = appState.history;

    return Column(
      children: <Widget>[
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: messages.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (BuildContext context, int index) {
              return GlassPanel(
                child: Text(messages[index], style: const TextStyle(color: Color(0xFFE4DDF3))),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0x14000000),
            border: Border(top: BorderSide(color: const Color(0x33FFFFFF))),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _controller,
                  onSubmitted: (_) {
                    _handleInput(context);
                  },
                  decoration: const InputDecoration(
                    hintText: 'Input thought or command...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: appState.isProcessingConsole
                    ? null
                    : () {
                        _handleInput(context);
                      },
                child: Text(appState.isProcessingConsole ? 'Thinking...' : 'Send'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
