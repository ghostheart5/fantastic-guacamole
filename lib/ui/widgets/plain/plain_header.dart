import 'package:flutter/material.dart';

/// One icon button in a [PlainHeader].
class PlainHeaderAction {
  const PlainHeaderAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;

  /// Tooltip and the single screen reader label.
  final String label;

  /// Null shows the button disabled (for example while refreshing).
  final VoidCallback? onPressed;
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
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(color: colors.onSurface),
            ),
          ),
        ),
        for (final PlainHeaderAction action in actions)
          IconButton(
            color: colors.onSurfaceVariant,
            tooltip: action.label,
            onPressed: action.onPressed,
            icon: Icon(action.icon),
          ),
      ],
    );
  }
}
