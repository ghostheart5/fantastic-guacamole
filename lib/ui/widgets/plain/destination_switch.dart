import 'package:fantastic_guacamole/theme/radii.dart';
import 'package:fantastic_guacamole/ui/widgets/plain/plain_palette.dart';
import 'package:flutter/material.dart';

/// Two-segment control for moving between two destinations in one tab. The
/// segments sit side by side, and stack when a label would not fit in half
/// the width (large text, narrow screen) so no word is broken. Colours come
/// from the surrounding [PlainPalette].
class DestinationSwitch extends StatelessWidget {
  const DestinationSwitch({
    required this.firstLabel,
    required this.secondLabel,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  }) : assert(selectedIndex == 0 || selectedIndex == 1);

  final String firstLabel;
  final String secondLabel;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const double _gap = 8;
  static const double _segmentPadding = 8;

  @override
  Widget build(BuildContext context) {
    final TextStyle style =
        Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700) ??
        const TextStyle(fontWeight: FontWeight.w700);
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final TextDirection direction = Directionality.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        double widest = 0;
        for (final String label in <String>[firstLabel, secondLabel]) {
          final TextPainter painter = TextPainter(
            text: TextSpan(text: label, style: style),
            textDirection: direction,
            textScaler: scaler,
          )..layout();
          if (painter.width > widest) widest = painter.width;
          painter.dispose();
        }
        final bool sideBySide =
            widest + 2 * _segmentPadding <= (box.maxWidth - _gap) / 2;
        final Widget first = _segment(context, 0, firstLabel);
        final Widget second = _segment(context, 1, secondLabel);
        if (sideBySide) {
          return Row(
            children: <Widget>[
              Expanded(child: first),
              const SizedBox(width: _gap),
              Expanded(child: second),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            first,
            const SizedBox(height: _gap),
            second,
          ],
        );
      },
    );
  }

  Widget _segment(BuildContext context, int index, String label) {
    final ThemeData theme = Theme.of(context);
    final PlainPalette colors = PlainPalette.of(context);
    final bool selected = index == selectedIndex;
    final ShapeBorder? cardShape = theme.cardTheme.shape;
    final BorderRadiusGeometry radius = cardShape is RoundedRectangleBorder
        ? cardShape.borderRadius
        : cardRadius;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      excludeSemantics: true,
      onTap: () => onSelected(index),
      child: Material(
        color: selected ? colors.selectedFill : colors.fill,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected ? colors.accent : colors.line,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onSelected(index),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(_segmentPadding),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colors.primary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
