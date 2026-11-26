import 'dart:async';

import 'package:fantastic_guacamole/features/help/help_topics.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:fantastic_guacamole/tutorial/guidance_catalogue.dart';
import 'package:fantastic_guacamole/ui/navigation/app_view_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens Help on top of the current screen; Back returns to it.
void openHelpScreen(BuildContext context) {
  unawaited(
    Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => const HelpScreen())),
  );
}

/// Short help topics with search. Read-only: it changes no guide progress.
class HelpScreen extends ConsumerStatefulWidget {
  const HelpScreen({super.key});

  @override
  ConsumerState<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends ConsumerState<HelpScreen> {
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool es = ChronoSparkLocalizations.of(context).isSpanish;
    String t(String english, String spanish) => es ? spanish : english;
    final String query = _query.text.trim();
    final List<HelpTopic> topics = HelpTopics.all
        .where((HelpTopic topic) => topic.matches(query, spanish: es))
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: Text(t('Help', 'Ayuda'))),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: 1 + (topics.isEmpty ? 1 : topics.length),
          itemBuilder: (BuildContext context, int index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: _query,
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: t('Search help', 'Buscar en la ayuda'),
                    hintText: t(
                      'For example: reminders',
                      'Por ejemplo: recordatorios',
                    ),
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: t('Clear search', 'Borrar la búsqueda'),
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () => setState(_query.clear),
                          ),
                    border: const OutlineInputBorder(),
                  ),
                ),
              );
            }
            if (topics.isEmpty) {
              return Semantics(
                liveRegion: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        t(
                          'No topics match "$query".',
                          'Ningún tema coincide con «$query».',
                        ),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        t(
                          'Try another word, or clear the search to see every topic.',
                          'Prueba con otra palabra o borra la búsqueda para ver todos los temas.',
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return _HelpTopicCard(topic: topics[index - 1], spanish: es);
          },
        ),
      ),
    );
  }
}

class _HelpTopicCard extends ConsumerWidget {
  const _HelpTopicCard({required this.topic, required this.spanish});

  final HelpTopic topic;
  final bool spanish;

  String _of(GuidanceText text) => text.of(spanish: spanish);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TextTheme text = Theme.of(context).textTheme;
    final GuidanceText? place = topic.place;
    final GuidanceText? whereToTap = topic.whereToTap;
    final AppView? showMe = topic.showMe;
    // Each line is its own node, so only the title is read as a heading.
    return Card(
      semanticContainer: false,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(_of(topic.title), style: text.titleMedium),
            ),
            if (place != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                spanish ? 'Dónde: ${place.es}' : 'Where: ${place.en}',
                style: text.labelMedium,
              ),
            ],
            const SizedBox(height: 8),
            Text(_of(topic.body), style: text.bodyMedium),
            if (whereToTap != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(_of(whereToTap), style: text.bodyMedium),
            ],
            if (showMe != null) ...<Widget>[
              const SizedBox(height: 12),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                ),
                onPressed: () => goToAppView(context, ref, showMe),
                child: Text(
                  spanish ? 'Muéstramelo' : 'Show me',
                  semanticsLabel: _showMeLabel(showMe),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// "Show me: Today", naming the screen the button opens.
  String _showMeLabel(AppView view) {
    final String destination = HelpTopics.screenName(view).of(spanish: spanish);
    return spanish ? 'Muéstramelo: $destination' : 'Show me: $destination';
  }
}
