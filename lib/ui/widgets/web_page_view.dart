import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WebPageView extends StatelessWidget {
  const WebPageView({required this.title, this.body, this.assetPath, super.key})
    : assert(
        body != null || assetPath != null,
        'Provide either body or assetPath',
      );

  final String title;
  final String? body;
  final String? assetPath;

  @override
  Widget build(BuildContext context) {
    if (assetPath != null) {
      return _AssetTextPage(title: title, assetPath: assetPath!);
    }
    return _StaticPage(title: title, body: body!);
  }
}

class _StaticPage extends StatelessWidget {
  const _StaticPage({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              Text(body),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssetTextPage extends StatefulWidget {
  const _AssetTextPage({required this.title, required this.assetPath});

  final String title;
  final String assetPath;

  @override
  State<_AssetTextPage> createState() => _AssetTextPageState();
}

class _AssetTextPageState extends State<_AssetTextPage> {
  String? _content;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final text = await rootBundle.loadString(widget.assetPath);
      if (mounted) setState(() => _content = text);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: _error
            ? const Center(child: Text('Could not load content.'))
            : _content == null
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Text(_content!),
              ),
      ),
    );
  }
}
