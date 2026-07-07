import 'package:fantastic_guacamole/system/external_url_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WebPageView extends StatelessWidget {
  const WebPageView({
    required this.title,
    this.body,
    this.assetPath,
    this.externalUrl,
    this.callToActionLabel,
    super.key,
  }) : assert(
         body != null || assetPath != null || externalUrl != null,
         'Provide body, assetPath, or externalUrl',
       );

  final String title;
  final String? body;
  final String? assetPath;
  final String? externalUrl;
  final String? callToActionLabel;

  @override
  Widget build(BuildContext context) {
    if (externalUrl != null) {
      return _ExternalLinkPage(
        title: title,
        body: body,
        externalUrl: externalUrl!,
        callToActionLabel: callToActionLabel ?? 'Open Website',
      );
    }
    if (assetPath != null) {
      return _AssetTextPage(title: title, assetPath: assetPath!);
    }
    return _StaticPage(title: title, body: body!);
  }
}

class _ExternalLinkPage extends StatelessWidget {
  const _ExternalLinkPage({
    required this.title,
    required this.externalUrl,
    required this.callToActionLabel,
    this.body,
  });

  final String title;
  final String externalUrl;
  final String callToActionLabel;
  final String? body;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (body != null) ...<Widget>[
                Text(body!, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 16),
              ],
              SelectableText(externalUrl, style: theme.textTheme.titleMedium),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  final bool opened = await const ExternalUrlService().open(Uri.parse(externalUrl));
                  if (!context.mounted || opened) {
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Unable to open the website from this device.')),
                  );
                },
                icon: const Icon(Icons.open_in_new),
                label: Text(callToActionLabel),
              ),
            ],
          ),
        ),
      ),
    );
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
            : SingleChildScrollView(padding: const EdgeInsets.all(24), child: Text(_content!)),
      ),
    );
  }
}
