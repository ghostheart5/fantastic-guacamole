import 'package:fantastic_guacamole/domain/operating_system/operating_system_contract.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/l10n/journey_copy.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:flutter/material.dart';

class DecisionIntelligenceCard extends StatelessWidget {
  const DecisionIntelligenceCard({
    required this.intelligence,
    required this.onAction,
    this.onAcknowledge,
    this.title = 'Planning summary',
    this.compact = false,
    this.topRisk,
    this.recentProgress,
    super.key,
  });

  final DecisionIntelligence intelligence;
  final VoidCallback onAction;
  final VoidCallback? onAcknowledge;
  final String title;
  final bool compact;
  final String? topRisk;
  final String? recentProgress;

  @override
  Widget build(BuildContext context) {
    final OperatingSnapshot snapshot = intelligence.snapshot;
    final OperatingDecisionReceipt decision = intelligence.decision;
    final List<OperatingChange> changes = intelligence.delta.materialChanges;
    final bool isSpanish = ChronoSparkLocalizations.of(context).isSpanish;
    final String displayTitle = title == 'Decision context'
        ? journeyText(context, title, 'Contexto de la decisión')
        : title == 'Planning summary'
        ? journeyText(context, title, 'Resumen de planificación')
        : title;
    final String deltaSummary = _deltaSummary(intelligence.delta, isSpanish);
    return Semantics(
      container: true,
      liveRegion: intelligence.hasUnacknowledgedChange,
      label: '$displayTitle. $deltaSummary',
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(compact ? 12 : 16),
        decoration: BoxDecoration(
          color: const Color(0xEE06101D),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.neonCyan.withValues(alpha: .28)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.neonCyan.withValues(alpha: .05),
              blurRadius: 16,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    displayTitle.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.neonCyan,
                      fontSize: 11,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _Badge(label: _confidenceBadge(decision.confidence, isSpanish)),
              ],
            ),
            const SizedBox(height: 12),
            _Answer(
              label: journeyText(context, 'WHERE YOU ARE', 'DÓNDE ESTÁS'),
              value: journeyText(
                context,
                '${snapshot.actionableCount} actionable, ${snapshot.overdueCount} overdue, ${snapshot.completedToday} completed today. Momentum ${snapshot.momentum}%, pressure ${snapshot.pressure}%.',
                '${snapshot.actionableCount} acciones posibles, ${snapshot.overdueCount} vencidas, ${snapshot.completedToday} completadas hoy. Impulso ${snapshot.momentum}%, presión ${snapshot.pressure}%.',
              ),
            ),
            _Answer(
              label: journeyText(context, 'WHAT CHANGED', 'QUÉ CAMBIÓ'),
              value:
                  recentProgress ??
                  (changes.isEmpty
                      ? deltaSummary
                      : changes
                            .take(3)
                            .map(
                              (OperatingChange item) =>
                                  '${_changeLabel(item.kind, item.label, isSpanish)}: ${item.previousValue} ${isSpanish ? 'a' : 'to'} ${item.currentValue}',
                            )
                            .join('. ')),
            ),
            _Answer(
              label: journeyText(
                context,
                'WHAT MATTERS NEXT',
                'QUÉ IMPORTA AHORA',
              ),
              value: decision.recommendedAction,
              emphasized: true,
            ),
            _Answer(
              label: journeyText(
                context,
                'WHY THIS MATTERS',
                'POR QUÉ IMPORTA',
              ),
              value: '${decision.rationale} ${decision.whyItMatters}',
            ),
            if (topRisk != null)
              _Answer(
                label: journeyText(context, 'TOP RISK', 'RIESGO PRINCIPAL'),
                value: topRisk!,
              ),
            if (!compact) ...<Widget>[
              _Answer(
                label: journeyText(context, 'IF DELAYED', 'SI SE APLAZA'),
                value: decision.consequenceOfDelay,
              ),
              Text(
                journeyText(
                  context,
                  'Evidence ${(snapshot.evidenceCoverage * 100).round()}% ready • ${decision.isExpired ? 'refresh required' : 'current'} • ${decision.modelVersion}',
                  'Evidencia ${(snapshot.evidenceCoverage * 100).round()}% lista • ${decision.isExpired ? 'se requiere actualizar' : 'actual'} • ${decision.modelVersion}',
                ),
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: decision.isExpired ? null : onAction,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: Text(_actionLabel(decision.actionIntent, isSpanish)),
                ),
                if (intelligence.hasUnacknowledgedChange &&
                    onAcknowledge != null)
                  TextButton(
                    onPressed: onAcknowledge,
                    child: Text(
                      journeyText(
                        context,
                        'Mark update reviewed',
                        'Marcar actualización como revisada',
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _deltaSummary(OperatingDelta delta, bool isSpanish) {
  if (!isSpanish) return delta.summary;
  if (delta.isBaseline) {
    return 'Se estableció la base. Las próximas actualizaciones mostrarán los cambios importantes.';
  }
  if (delta.previousSnapshotId == delta.currentSnapshotId) {
    return 'No hubo cambios importantes en las decisiones desde la última revisión.';
  }
  final int count = delta.materialChanges.length;
  if (count == 0) {
    return 'Los datos cambiaron, pero no se detectó un cambio importante en las decisiones.';
  }
  return 'Se ${count == 1 ? 'detectó' : 'detectaron'} $count ${count == 1 ? 'cambio importante' : 'cambios importantes'} desde la última revisión.';
}

String _changeLabel(OperatingChangeKind kind, String original, bool isSpanish) {
  if (!isSpanish) return original;
  return switch (kind) {
    OperatingChangeKind.priority => 'Acción principal',
    OperatingChangeKind.schedule => 'Compromisos vencidos',
    OperatingChangeKind.momentum => 'Impulso',
    OperatingChangeKind.progression => 'Completadas hoy',
    OperatingChangeKind.risk => 'Presión',
    OperatingChangeKind.evidence => 'Cobertura de evidencia',
  };
}

String _confidenceBadge(OperatingConfidence confidence, bool isSpanish) {
  if (!isSpanish) return confidence.name;
  return switch (confidence) {
    OperatingConfidence.high => 'Alta',
    OperatingConfidence.moderate => 'Moderada',
    OperatingConfidence.low => 'Baja',
    OperatingConfidence.insufficientEvidence => 'Insuficiente',
  };
}

String _actionLabel(OperatingActionIntent intent, bool isSpanish) {
  if (!isSpanish) return intent.label;
  return switch (intent.type) {
    OperatingActionType.openCreator => 'Abrir Creador',
    OperatingActionType.openSmartPlanner =>
      'Revisar en el Planificador Inteligente',
    OperatingActionType.openSiConsole => 'Revisar evidencia en la Consola SI',
    OperatingActionType.openTrajectoryEngine =>
      'Revisar riesgo en el Motor de Trayectoria',
    OperatingActionType.openProgression => 'Revisar recuperación en Progreso',
    OperatingActionType.openTimeline => 'Revisar en Línea de Tiempo',
    _ => intent.label,
  };
}

class _Answer extends StatelessWidget {
  const _Answer({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 10,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: emphasized ? Colors.white : Colors.white70,
              fontSize: emphasized ? 15 : 12,
              height: 1.4,
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.neonCyan.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label
            .replaceAllMapped(
              RegExp(r'([A-Z])'),
              (Match match) => ' ${match.group(1)}',
            )
            .trim(),
        style: const TextStyle(
          color: AppColors.neonCyan,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
