import 'package:fantastic_guacamole/theme/radii.dart';
import 'package:fantastic_guacamole/ui/widgets/plain/plain_palette.dart';
import 'package:flutter/material.dart';

/// A Card with consistent padding, using the theme's card colour and radius.
/// Everything inside uses the theme's on-surface colours (cards are white under
/// the light theme), even on a dark [PlainScreen].
///
/// With [onTap] it is a button with a 48 dp minimum target. Pass
/// [semanticLabel] to give it one exact screen reader label; without it the
/// card is announced from the text inside it. [selected] (null for cards that
/// are not selectable) outlines the card and is announced as selected.
///
/// Warning: a tappable or selectable card without [semanticLabel] merges
/// everything inside it into one screen reader node (the card's button). Do
/// not put interactive children (buttons, switches, a [PlainDisclosure])
/// inside such a card: they lose their own node, action and state for screen
/// readers. Put them in a plain card, or beside the tappable one.
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
    final PlainPalette palette = PlainPalette.card(theme);
    final ShapeBorder? baseShape = theme.cardTheme.shape;
    final BorderRadiusGeometry radius = baseShape is RoundedRectangleBorder
        ? baseShape.borderRadius
        : cardRadius;
    final Widget padded = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: PlainPaletteScope(palette: palette, child: child),
      ),
    );
    Widget card = Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      shape: (selected ?? false)
          ? RoundedRectangleBorder(
              borderRadius: radius,
              side: BorderSide(color: palette.accent, width: 2),
            )
          : null,
      child: onTap == null ? padded : InkWell(onTap: onTap, child: padded),
    );
    if (onTap != null || selected != null) {
      card = Semantics(
        button: onTap != null,
        selected: selected,
        label: semanticLabel,
        excludeSemantics: semanticLabel != null,
        onTap: onTap,
        child: card,
      );
      if (semanticLabel == null) card = MergeSemantics(child: card);
    }
    return card;
  }
}
