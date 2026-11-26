import 'package:flutter/material.dart';

/// One icon button in a [PlainHeader].
class PlainHeaderAction {
  const PlainHeaderAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;

  /// Tooltip and screen reader label.
  final String label;
  final VoidCallback onPressed;
}

/// Title row: a sentence-case title and optional icon actions.
class PlainHeader extends StatelessWidget {
  const PlainHeader({
    required this.title,
    this.actions = const <PlainHeaderAction>[],
    super.key,
  });

  final String title;
  final List<PlainHeaderAction> actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(color: Colors.white),
            ),
          ),
        ),
        for (final PlainHeaderAction action in actions)
          IconButton(
            color: Colors.white70,
            tooltip: action.label,
            onPressed: action.onPressed,
            icon: Icon(action.icon, semanticLabel: action.label),
          ),
      ],
    );
  }
}
