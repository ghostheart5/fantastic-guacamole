import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/l10n/journey_copy.dart';
import 'package:flutter/material.dart';

/// One optional, post-value invitation to save a narrow piece of context.
/// This widget never gathers personality, life-history, or inferred emotion.
class FirstUseContextOfferCard extends StatelessWidget {
  const FirstUseContextOfferCard({
    super.key,
    required this.immediateGoal,
    required this.onAdd,
    required this.onDismiss,
  });

  final String immediateGoal;
  final VoidCallback onAdd;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final String goal = immediateGoal.trim();
    return Semantics(
      key: const Key('first-use-context-offer'),
      container: true,
      label: journeyText(
        context,
        'Optional current-priority context. Use only this time remains the default.',
        'Contexto opcional para la prioridad actual. Usar solo esta vez sigue siendo la opción predeterminada.',
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.neonViolet.withValues(alpha: .42),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              journeyText(
                context,
                'OPTIONAL CONTEXT FOR THIS GOAL',
                'CONTEXTO OPCIONAL PARA ESTA META',
              ),
              style: const TextStyle(
                color: AppColors.neonViolet,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              goal.isEmpty
                  ? journeyText(
                      context,
                      'Would saving your exact current priority help later Smart Planner decisions?',
                      '¿Guardar tu prioridad actual exacta ayudaría a las próximas decisiones del Planificador Inteligente?',
                    )
                  : journeyText(
                      context,
                      'After this plan for “$goal”, would saving your exact current priority help later Smart Planner decisions?',
                      'Después de este plan para “$goal”, ¿guardar tu prioridad actual exacta ayudaría a las próximas decisiones del Planificador Inteligente?',
                    ),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              journeyText(
                context,
                'Nothing is inferred. Use only this time remains the default. If you opt in, you choose the exact words.',
                'No se infiere nada. Usar solo esta vez sigue siendo la opción predeterminada. Si aceptas, tú eliges las palabras exactas.',
              ),
              style: const TextStyle(color: Colors.white70, height: 1.4),
            ),
            const SizedBox(height: 8),
            Text(
              journeyText(
                context,
                'Before saving: purpose · decision support  |  scope · Smart Planner only  |  expiry · 30 days  |  effect · may break a close ranking tie while this priority is active',
                'Antes de guardar: propósito · apoyar decisiones  |  alcance · solo Planificador Inteligente  |  vencimiento · 30 días  |  efecto · puede desempatar opciones similares mientras esta prioridad esté activa',
              ),
              style: const TextStyle(
                color: Color(0xFFB9C5DD),
                fontSize: 12,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.icon(
                  key: const Key('first-use-context-add'),
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(
                    journeyText(
                      context,
                      'Add optional context',
                      'Añadir contexto opcional',
                    ),
                  ),
                ),
                TextButton(
                  key: const Key('first-use-context-dismiss'),
                  onPressed: onDismiss,
                  child: Text(journeyText(context, 'Not now', 'Ahora no')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
