import 'package:flutter/material.dart';

/// Section heading with an optional one-line description and its children.
class PlainSection extends StatelessWidget {
  const PlainSection({
    required this.title,
    this.description,
    this.children = const <Widget>[],
    super.key,
  });

  final String title;
  final String? description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 24),
        Semantics(
          header: true,
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        if (description != null) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            description!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }
}
