import 'package:fantastic_guacamole/ui/widgets/plain/provenance_label.dart';
import 'package:flutter/material.dart';

/// Label on the left, value on the right, with an optional caption and
/// provenance label underneath. Text wraps; nothing is truncated.
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
    final TextTheme text = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  flex: 3,
                  child: Text(
                    label,
                    style: text.bodyLarge?.copyWith(color: Colors.white70),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    style: text.titleMedium?.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
            if (caption != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  caption!,
                  style: text.bodySmall?.copyWith(color: Colors.white70),
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
