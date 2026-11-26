import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:flutter/material.dart';

/// Where a number or statement comes from.
enum ProvenanceKind { recorded, estimate, ai }

/// Small label that says whether something comes from the person's records,
/// is an estimate, or is an AI interpretation.
class ProvenanceLabel extends StatelessWidget {
  const ProvenanceLabel(this.kind, {super.key});

  final ProvenanceKind kind;

  static String textFor(ProvenanceKind kind, {required bool isSpanish}) {
    switch (kind) {
      case ProvenanceKind.recorded:
        return isSpanish ? 'De tus registros' : 'From your records';
      case ProvenanceKind.estimate:
        return isSpanish ? 'Estimación' : 'Estimate';
      case ProvenanceKind.ai:
        return isSpanish ? 'Interpretación de IA' : 'AI interpretation';
    }
  }

  @override
  Widget build(BuildContext context) {
    final String text = textFor(
      kind,
      isSpanish: ChronoSparkLocalizations.of(context).isSpanish,
    );
    return Text(
      text,
      softWrap: true,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: AppColors.textSecondary,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}
