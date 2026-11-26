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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 24),
        Semantics(
          header: true,
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.white),
          ),
        ),
        if (description != null) ...<Widget>[
          const SizedBox(height: 4),
          Text(description!, style: const TextStyle(color: Colors.white70)),
        ],
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }
}
