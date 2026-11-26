import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:flutter/material.dart';

/// Where a number or statement comes from.
enum ProvenanceKind { recorded, plan, estimate, ai }

/// Small label that says whether something comes from the person's records,
/// their plan, is an estimate, or is an AI interpretation.
class ProvenanceLabel extends StatelessWidget {
  const ProvenanceLabel(this.kind, {super.key});

  final ProvenanceKind kind;

  static String textFor(ProvenanceKind kind, {required bool isSpanish}) {
    switch (kind) {
      case ProvenanceKind.recorded:
        return isSpanish ? 'De tus registros' : 'From your records';
      case ProvenanceKind.plan:
        return isSpanish ? 'De tu plan' : 'From your plan';
      case ProvenanceKind.estimate:
        return isSpanish ? 'Estimación' : 'Estimate';
      case ProvenanceKind.ai:
        return isSpanish ? 'Interpretación de IA' : 'AI interpretation';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Text(
      textFor(kind, isSpanish: ChronoSparkLocalizations.of(context).isSpanish),
      softWrap: true,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
