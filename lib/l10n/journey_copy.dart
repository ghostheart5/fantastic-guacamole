import 'package:flutter/widgets.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';

/// Presentation copy only. Never apply to user-authored titles or descriptions.
String journeyText(BuildContext context, String english, String spanish) =>
    ChronoSparkLocalizations.of(context).isSpanish ? spanish : english;

/// Canonical app-authored labels retain their identity for calculations/colors.
String journeyLabel(BuildContext context, String label) =>
    ChronoSparkLocalizations.of(context).isSpanish
    ? const <String, String>{
            'Note Created': 'Nota creada',
            'Task deadline missed. Re-plan this task immediately.':
                'La fecha límite de la tarea venció. Vuelve a planificarla ahora.',
            'Task deadline is upcoming.':
                'Se acerca la fecha límite de la tarea.',
            'Scheduled work time has passed. The task remains open; no deadline was missed.':
                'La hora programada ya pasó. La tarea sigue abierta; no venció ninguna fecha límite.',
            'Task is scheduled for a planned work time.':
                'La tarea tiene una hora de trabajo programada.',
            'Goal target date has passed. Recovery plan needed.':
                'La fecha objetivo de la meta ya pasó. Hace falta un plan de recuperación.',
            'Goal target date is today.':
                'La fecha objetivo de la meta es hoy.',
            'Goal target date is upcoming.':
                'Se acerca la fecha objetivo de la meta.',
            'Loading your Timeline': 'Cargando tu Línea de Tiempo',
            'Checking saved tasks before showing your chronology.':
                'Comprobando las tareas guardadas antes de mostrar tu cronología.',
            'Loading saved Timeline activity.':
                'Cargando actividad guardada de la Línea de Tiempo.',
            'Timeline tasks could not be loaded':
                'No se pudieron cargar las tareas de la Línea de Tiempo',
            'Timeline tasks could not be loaded.':
                'No se pudieron cargar las tareas de la Línea de Tiempo.',
            'Nothing has been labeled empty. Retry the saved-task source.':
                'No se ha marcado nada como vacío. Reintenta la fuente de tareas guardadas.',
            'Retry loading tasks': 'Reintentar carga de tareas',
            'Saved Timeline activity could not be read':
                'No se pudo leer la actividad guardada de la Línea de Tiempo',
            'Saved Timeline activity could not be read.':
                'No se pudo leer la actividad guardada de la Línea de Tiempo.',
            'Your stored data was not erased. Preserve the original before repairing the active Timeline.':
                'Tus datos guardados no se borraron. Conserva el original antes de reparar la Línea de Tiempo activa.',
            'Preserve and repair Timeline':
                'Conservar y reparar Línea de Tiempo',
            'Some saved Timeline activity could not be read. Valid activity is shown; preserve the original before repairing it.':
                'No se pudo leer parte de la actividad guardada. Se muestra la actividad válida; conserva el original antes de repararla.',
            'Some saved Timeline activity could not be read. Valid activity is shown. Preserve the original before repairing it.':
                'No se pudo leer parte de la actividad guardada. Se muestra la actividad válida. Conserva el original antes de repararla.',
            'Task projections are unavailable. Saved Timeline activity is still shown.':
                'Las proyecciones de tareas no están disponibles. Se sigue mostrando la actividad guardada.',
            'Task projections are still loading. Saved Timeline activity is shown below.':
                'Las proyecciones de tareas siguen cargando. La actividad guardada se muestra abajo.',

            'Deep Work Mode': 'Concentración profunda',
            'Building Momentum': 'Desarrollando impulso',
            'Getting Started': 'Primeros pasos',
            'Your history remains. Choose a gentle restart.':
                'Tu historial permanece. Elige un reinicio gradual.',
            'A sustained rhythm is taking shape':
                'Se está formando un ritmo sostenido',
            'Consistency is building momentum':
                'La constancia está generando impulso',
            'Your current rhythm is building':
                'Tu ritmo actual se está consolidando',
            'Begin with one manageable action':
                'Empieza con una acción manejable',
            'High': 'Alta',
            'Medium': 'Media',
            'Low': 'Baja',
            'On Track': 'En buen camino',
            'Slightly Off': 'Con pequeños desvíos',
            'Off Track': 'Fuera de rumbo',
            'Light': 'Ligera',
            'Balanced': 'Equilibrada',
            'Heavy': 'Elevada',
            'Improving': 'Mejorando',
            'Declining': 'Disminuyendo',
            'Steady': 'Estable',
            'Not enough evidence': 'Evidencia insuficiente',
            'Not enough history': 'Historial insuficiente',
            'Open Timeline': 'Abrir Línea de Tiempo',
            'Open Creator': 'Abrir Creador',
            'Today': 'Hoy',
            'Week': 'Semana',
            'Month': 'Mes',
            'Year': 'Año',
            'All': 'Todo',
            'Overdue': 'Vencidos',
            'Upcoming': 'Próximos',
            'Milestones': 'Hitos',
            'Risks': 'Riesgos',
            'Recommendations': 'Recomendaciones',
            'Task': 'Tarea',
            'Goal': 'Meta',
            'Habit': 'Rutina',
            'Project': 'Proyecto',
            'Reflection': 'Reflexión',
            'Level Up': 'Nuevo nivel',
            'Goal Complete': 'Meta completada',
            'Streak': 'Racha',
            'Milestone': 'Hito',
            'Deadline': 'Fecha límite',
            'Forecast': 'Proyección',
            'Snapshot': 'Resumen',
            'Risk': 'Riesgo',
            'Recommendation': 'Recomendación',
            'Note': 'Nota',
            'Note Added': 'Nota añadida',
            'Note Updated': 'Nota actualizada',
            'Note Archived': 'Nota archivada',
            'Note Deleted': 'Nota eliminada',
          }[label] ??
          label
    : label;
