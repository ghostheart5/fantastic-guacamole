import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

/// Model text is display-only: it cannot load images or open destinations.
class AssistantResponseBody extends StatelessWidget {
  const AssistantResponseBody({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => SelectionArea(
    child: MarkdownBody(
      data: text,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        tableColumnWidth: const FixedColumnWidth(160),
        tableCellsPadding: const EdgeInsets.all(8),
        tableScrollbarThumbVisibility: true,
      ),
      imageBuilder: (uri, title, alt) => Text(alt ?? title ?? ''),
    ),
  );
}
