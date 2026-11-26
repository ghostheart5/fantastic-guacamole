import 'package:flutter/material.dart';

/// A Card with consistent padding, using the theme's card colour and radius.
///
/// With [onTap] it is a button with a 48 dp minimum target. Pass
/// [semanticLabel] to give it one exact screen reader label; without it the
/// card is announced from the text inside it. [selected] (null for cards that
/// are not selectable) outlines the card and is announced as selected.
class PlainCard extends StatelessWidget {
  const PlainCard({
    required this.child,
    this.onTap,
    this.semanticLabel,
    this.selected,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ShapeBorder? baseShape = theme.cardTheme.shape;
    final Widget padded = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
    Widget card = Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      shape: (selected ?? false) && baseShape is RoundedRectangleBorder
          ? RoundedRectangleBorder(
              borderRadius: baseShape.borderRadius,
              side: BorderSide(color: theme.colorScheme.primary, width: 2),
            )
          : null,
      child: onTap == null ? padded : InkWell(onTap: onTap, child: padded),
    );
    if (onTap != null || selected != null) {
      card = Semantics(
        container: true,
        button: onTap != null,
        selected: selected,
        label: semanticLabel,
        excludeSemantics: semanticLabel != null,
        onTap: onTap,
        child: card,
      );
    }
    return card;
  }
}
