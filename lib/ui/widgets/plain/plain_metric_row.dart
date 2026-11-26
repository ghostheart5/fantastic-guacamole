import 'package:fantastic_guacamole/ui/widgets/plain/provenance_label.dart';
import 'package:flutter/material.dart';

/// Label on the left, value on the right, with an optional caption and
/// provenance label underneath. When the value is too wide to sit beside the
/// label (large text, narrow screen) it moves under the label. Text wraps at
/// spaces; a number is never split.
class PlainMetricRow extends StatelessWidget {
  const PlainMetricRow({
    required this.label,
    required this.value,
    this.caption,
    this.provenance,
    super.key,
  });

  final String label;
  final String value;
  final String? caption;
  final ProvenanceKind? provenance;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextTheme text = theme.textTheme;
    final ColorScheme colors = theme.colorScheme;
    final TextStyle labelStyle =
        text.bodyLarge?.copyWith(color: colors.onSurfaceVariant) ??
        const TextStyle();
    final TextStyle valueStyle =
        text.titleMedium?.copyWith(color: colors.onSurface) ??
        const TextStyle();
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final TextDirection direction = Directionality.of(context);
    return Semantics(
      container: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints box) {
                final TextPainter painter = TextPainter(
                  text: TextSpan(text: value, style: valueStyle),
                  textDirection: direction,
                  textScaler: scaler,
                )..layout();
                final bool beside = painter.width <= box.maxWidth * 0.45;
                painter.dispose();
                if (beside) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(child: Text(label, style: labelStyle)),
                      const SizedBox(width: 12),
                      Text(value, textAlign: TextAlign.end, style: valueStyle),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(label, style: labelStyle),
                    const SizedBox(height: 2),
                    Text(value, style: valueStyle),
                  ],
                );
              },
            ),
            if (caption != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  caption!,
                  style: text.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            if (provenance != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: ProvenanceLabel(provenance!),
              ),
          ],
        ),
      ),
    );
  }
}
