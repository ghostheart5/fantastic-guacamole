import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:fantastic_guacamole/domain/operating_system/operating_system_contract.dart';

class ChronoSparkLocalizations {
  const ChronoSparkLocalizations(this.locale);

  final Locale locale;

  static const LocalizationsDelegate<ChronoSparkLocalizations> delegate =
      _ChronoSparkLocalizationsDelegate();

  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  static ChronoSparkLocalizations of(BuildContext context) =>
      Localizations.of<ChronoSparkLocalizations>(
        context,
        ChronoSparkLocalizations,
      ) ??
      const ChronoSparkLocalizations(Locale('en'));

  bool get isSpanish => locale.languageCode.toLowerCase() == 'es';

  String text(ChronoSparkString key) =>
      (isSpanish ? _es : _en)[key] ?? _en[key] ?? key.name;

  String moreInTimeline(int count) => isSpanish
      ? '+$count más en la Línea de Tiempo'
      : '+$count more in Timeline';

  String completeTaskLabel(String title) =>
      isSpanish ? 'Completar $title' : 'Complete $title';

  String guideTitle(String id, String fallback) {
    if (!isSpanish) return fallback;
    return switch (id) {
      'createFirstItem' => 'Captura el primer compromiso real',
      'scheduleFirstItem' => 'Asigna una hora real al compromiso',
      'reviewTimeline' => 'Verifica dónde quedó el trabajo',
      'nexus' => 'Revisa por qué este bloque sigue',
      'smartPlanner' => 'Examina el plan activo',
      'timelineExecution' => 'Crea un resultado del que el sistema aprenda',
      'siConsole' => 'Cuestiona la evidencia débil o incompleta',
      'trajectoryEngine' => 'Compara una alternativa real',
      'progression' => 'Verifica qué se volvió confiable',
      _ => fallback,
    };
  }

  String guideBody(String id, String fallback) {
    if (!isSpanish) return fallback;
    return switch (id) {
      'createFirstItem' =>
        'Crea una tarea con un resultado concreto. La guía avanza solo después de guardarla.',
      'scheduleFirstItem' =>
        'Añade una fecha y una hora para conectar Creador, Planificador Inteligente y Línea de Tiempo con evidencia real.',
      'reviewTimeline' =>
        'Revisa el resultado guardado en Línea de Tiempo. Abrir el aviso no cuenta como completarlo.',
      'nexus' =>
        'Revisa la razón y la incertidumbre mostradas junto al bloque antes de actuar.',
      'smartPlanner' =>
        'Haz una pregunta específica sobre la tarea elegida, sus límites o qué debería moverse.',
      'timelineExecution' =>
        'Completa, aplaza o corrige un bloque. Solo el resultado guardado hace avanzar esta guía.',
      'siConsole' =>
        'Pregunta qué evidencia falta y qué dato podría cambiar la recomendación.',
      'trajectoryEngine' =>
        'Cambia tiempo, alcance o prioridad y compara las consecuencias y supuestos.',
      'progression' =>
        'Revisa los resultados detrás de la progresión. La revisión real completa esta guía.',
      _ => fallback,
    };
  }

  String guideAction(String id, String fallback) {
    if (!isSpanish) return fallback;
    return switch (id) {
      'createFirstItem' => 'Abrir Creador',
      'scheduleFirstItem' => 'Programar en Creador',
      'reviewTimeline' => 'Abrir Línea de Tiempo',
      'nexus' => 'Revisar en Nexus',
      'smartPlanner' => 'Preguntar al Planificador',
      'timelineExecution' => 'Abrir trabajo ejecutable',
      'siConsole' => 'Revisar evidencia',
      'trajectoryEngine' => 'Comparar caminos',
      'progression' => 'Revisar resultados',
      _ => fallback,
    };
  }

  String decisionConfidenceLabel(OperatingConfidence confidence) {
    final String label = isSpanish
        ? switch (confidence) {
            OperatingConfidence.high => 'alta',
            OperatingConfidence.moderate => 'moderada',
            OperatingConfidence.low => 'baja',
            OperatingConfidence.insufficientEvidence =>
              'evidencia insuficiente',
          }
        : switch (confidence) {
            OperatingConfidence.high => 'high',
            OperatingConfidence.moderate => 'moderate',
            OperatingConfidence.low => 'low',
            OperatingConfidence.insufficientEvidence => 'insufficient evidence',
          };
    return isSpanish ? 'Confianza: $label.' : 'Confidence: $label.';
  }

  static const Map<ChronoSparkString, String> _en = <ChronoSparkString, String>{
    ChronoSparkString.nexus: 'Nexus',
    ChronoSparkString.smartPlanner: 'Smart Planner',
    ChronoSparkString.creator: 'Creator',
    ChronoSparkString.siConsole: 'SI Console',
    ChronoSparkString.timeline: 'Timeline',
    ChronoSparkString.trajectoryEngine: 'Trajectory Engine',
    ChronoSparkString.progression: 'Progression',
    ChronoSparkString.preparingSummary: 'Preparing your summary',
    ChronoSparkString.retryNexus: 'Retry Nexus',
    ChronoSparkString.whatMattersNext: 'What matters next',
    ChronoSparkString.topRisk: 'Top risk',
    ChronoSparkString.whatChanged: 'What changed',
    ChronoSparkString.openCreator: 'Open Creator',
    ChronoSparkString.startInCreator: 'Start in Creator',
    ChronoSparkString.todayTimeBlocks: "Today's time blocks",
    ChronoSparkString.openTimeline: 'Open Timeline',
    ChronoSparkString.timeBlocksUnavailable:
        'Time blocks are unavailable right now.',
    ChronoSparkString.retry: 'Retry',
    ChronoSparkString.noTimeBlocks:
        'No time blocks yet. Add a task to build today’s plan.',
    ChronoSparkString.createTask: 'Create task',
    ChronoSparkString.upNext: 'Up next',
    ChronoSparkString.complete: 'Complete',
    ChronoSparkString.done: 'Done',
    ChronoSparkString.timeBlockCompleted: 'Time block completed.',
    ChronoSparkString.timeBlockCompletionFailed:
        'Could not complete that time block. Please retry.',
    ChronoSparkString.whyThisIsNext: 'Why this is next',
    ChronoSparkString.reviewOrCorrectPlan: 'Review or correct plan',
    ChronoSparkString.welcome: 'Welcome',
    ChronoSparkString.livingDecisionSystem: 'A living decision system',
    ChronoSparkString.onboardingWelcomeBody:
        'Plan with purpose. Act. Learn. ChronoSpark keeps the context behind your decisions.',
    ChronoSparkString.next: 'Next',
    ChronoSparkString.initialize: 'Initialize',
    ChronoSparkString.initializeSystem: 'Initialize system',
    ChronoSparkString.skip: 'Skip',
    ChronoSparkString.nameQuestion: 'What should I call you?',
    ChronoSparkString.name: 'Name',
    ChronoSparkString.nameHint: 'Enter your name…',
    ChronoSparkString.primaryGoal: 'Primary goal',
    ChronoSparkString.goalExecution: 'Execution & Productivity',
    ChronoSparkString.goalGrowth: 'Personal Growth',
    ChronoSparkString.goalWellness: 'Mental Wellness',
    ChronoSparkString.goalExplore: 'Just exploring',
    ChronoSparkString.personalize: 'Personalize',
    ChronoSparkString.lifeDirection: 'Your life direction',
    ChronoSparkString.calibrateExperience: 'Help us calibrate your experience',
    ChronoSparkString.contextualGuidance: 'Contextual guidance',
    ChronoSparkString.openContextualGuidance: 'Open contextual guidance',
    ChronoSparkString.collapseGuidance: 'Collapse guidance',
    ChronoSparkString.useThisScreen: 'Use this screen',
    ChronoSparkString.notNow: 'Not now',
    ChronoSparkString.cancel: 'Cancel',
    ChronoSparkString.securingAccountData: 'Securing account data',
    ChronoSparkString.onboardingPrivacy:
        'Your display name stays on this device unless you choose cloud backup. Smart Planner and SI Console use saved planning context; external AI processing is opt-in and explained in Settings.',
    ChronoSparkString.onboardingWideBody:
        'Choose what ChronoSpark should call you. The rest of setup learns from the real task you create next.',
    ChronoSparkString.onboardingCompactBody:
        'Choose what ChronoSpark should call you, then build your first real task.',
    ChronoSparkString.onboardingFinishError:
        'Unable to finish onboarding. Please try again.',
    ChronoSparkString.preservedDataIssue:
        'Preserved device data was found, but its account owner cannot be verified.',
    ChronoSparkString.preservedDataBody:
        'Continue only if this preserved device data belongs to the signed-in account.',
    ChronoSparkString.claimPreservedData:
        'Use preserved data with this account',
    ChronoSparkString.clearPreservedData: 'Clear preserved data',
    ChronoSparkString.clearPreservedDataTitle: 'Clear preserved data?',
    ChronoSparkString.clearPreservedDataBody:
        'This removes preserved planning records, Timeline history, offline actions, notification schedules, profile progress, and local intelligence from this device. It does not delete your cloud account. This cannot be undone.',
    ChronoSparkString.privacyPolicyTitle: 'Privacy Policy',
    ChronoSparkString.privacyPolicyBody:
        'ChronoSpark publishes its authoritative privacy policy at the public HTTPS URL below. Use the hosted policy for current data handling, retention, and support terms.',
    ChronoSparkString.openHostedPrivacyPolicy: 'Open Hosted Privacy Policy',
    ChronoSparkString.deleteAccountTitle: 'Delete Account',
    ChronoSparkString.deleteAccountBody:
        'ChronoSpark publishes account deletion steps at the public HTTPS URL below. Use the hosted page to submit a deletion request and review deletion and retention details.',
    ChronoSparkString.openHostedDeleteAccountPage:
        'Open Hosted Delete Account Page',
    ChronoSparkString.termsTitle: 'Terms of Service',
    ChronoSparkString.termsBody:
        'ChronoSpark maintains its current Terms of Service on the public HTTPS page below so release builds and store listings reference the same source of truth.',
    ChronoSparkString.openHostedTerms: 'Open Hosted Terms',
    ChronoSparkString.supportTitle: 'Support',
    ChronoSparkString.supportBody:
        'ChronoSpark publishes release-facing support and account assistance at the public HTTPS URL below so store reviewers and users can reach the current support process from every build.',
    ChronoSparkString.openHostedSupportPage: 'Open Hosted Support Page',
    ChronoSparkString.openWebsite: 'Open Website',
    ChronoSparkString.unableToOpenWebsite:
        'Unable to open the website from this device.',
    ChronoSparkString.couldNotLoadContent: 'Could not load content.',
    ChronoSparkString.routerErrorTitle: "We couldn't open that link",
    ChronoSparkString.routerErrorBody:
        'The link does not match an available ChronoSpark screen. We recorded a safe diagnostic event without exposing technical details.',
    ChronoSparkString.routerErrorReturnNexus: 'Return to Nexus',
    ChronoSparkString.routerErrorReturnLogin: 'Return to Login',
    ChronoSparkString.routerErrorReturnOnboarding: 'Return to Setup',
    ChronoSparkString.routerErrorReturnSupport: 'Return to Support',
  };

  static const Map<ChronoSparkString, String> _es = <ChronoSparkString, String>{
    ChronoSparkString.nexus: 'Nexus',
    ChronoSparkString.smartPlanner: 'Planificador Inteligente',
    ChronoSparkString.creator: 'Creador',
    ChronoSparkString.siConsole: 'Consola SI',
    ChronoSparkString.timeline: 'Línea de Tiempo',
    ChronoSparkString.trajectoryEngine: 'Motor de Trayectoria',
    ChronoSparkString.progression: 'Progresión',
    ChronoSparkString.preparingSummary: 'Preparando tu resumen',
    ChronoSparkString.retryNexus: 'Reintentar Nexus',
    ChronoSparkString.whatMattersNext: 'Lo más importante ahora',
    ChronoSparkString.topRisk: 'Riesgo principal',
    ChronoSparkString.whatChanged: 'Qué cambió',
    ChronoSparkString.openCreator: 'Abrir Creador',
    ChronoSparkString.startInCreator: 'Comienza en Creador',
    ChronoSparkString.todayTimeBlocks: 'Bloques de tiempo de hoy',
    ChronoSparkString.openTimeline: 'Abrir Línea de Tiempo',
    ChronoSparkString.timeBlocksUnavailable:
        'Los bloques de tiempo no están disponibles ahora.',
    ChronoSparkString.retry: 'Reintentar',
    ChronoSparkString.noTimeBlocks:
        'Aún no hay bloques de tiempo. Añade una tarea para crear el plan de hoy.',
    ChronoSparkString.createTask: 'Crear tarea',
    ChronoSparkString.upNext: 'Siguiente',
    ChronoSparkString.complete: 'Completar',
    ChronoSparkString.done: 'Hecho',
    ChronoSparkString.timeBlockCompleted: 'Bloque de tiempo completado.',
    ChronoSparkString.timeBlockCompletionFailed:
        'No se pudo completar ese bloque de tiempo. Inténtalo de nuevo.',
    ChronoSparkString.whyThisIsNext: 'Por qué sigue esto',
    ChronoSparkString.reviewOrCorrectPlan: 'Revisar o corregir el plan',
    ChronoSparkString.welcome: 'Bienvenido',
    ChronoSparkString.livingDecisionSystem: 'Un sistema vivo de decisiones',
    ChronoSparkString.onboardingWelcomeBody:
        'Planifica con propósito. Actúa. Aprende. ChronoSpark conserva el contexto detrás de tus decisiones.',
    ChronoSparkString.next: 'Siguiente',
    ChronoSparkString.initialize: 'Iniciar',
    ChronoSparkString.initializeSystem: 'Iniciar sistema',
    ChronoSparkString.skip: 'Omitir',
    ChronoSparkString.nameQuestion: '¿Cómo debo llamarte?',
    ChronoSparkString.name: 'Nombre',
    ChronoSparkString.nameHint: 'Escribe tu nombre…',
    ChronoSparkString.primaryGoal: 'Objetivo principal',
    ChronoSparkString.goalExecution: 'Ejecución y productividad',
    ChronoSparkString.goalGrowth: 'Crecimiento personal',
    ChronoSparkString.goalWellness: 'Bienestar mental',
    ChronoSparkString.goalExplore: 'Solo explorando',
    ChronoSparkString.personalize: 'Personaliza',
    ChronoSparkString.lifeDirection: 'La dirección de tu vida',
    ChronoSparkString.calibrateExperience: 'Ayúdanos a calibrar tu experiencia',
    ChronoSparkString.contextualGuidance: 'Guía contextual',
    ChronoSparkString.openContextualGuidance: 'Abrir guía contextual',
    ChronoSparkString.collapseGuidance: 'Contraer guía',
    ChronoSparkString.useThisScreen: 'Usar esta pantalla',
    ChronoSparkString.notNow: 'Ahora no',
    ChronoSparkString.cancel: 'Cancelar',
    ChronoSparkString.securingAccountData: 'Protegiendo datos de la cuenta',
    ChronoSparkString.onboardingPrivacy:
        'Tu nombre visible permanece en este dispositivo salvo que actives la copia en la nube. Planificador Inteligente y Consola SI usan el contexto guardado; el procesamiento externo con IA es opcional y se explica en Ajustes.',
    ChronoSparkString.onboardingWideBody:
        'Elige cómo debe llamarte ChronoSpark. El resto de la configuración aprenderá de la tarea real que crearás después.',
    ChronoSparkString.onboardingCompactBody:
        'Elige cómo debe llamarte ChronoSpark y luego crea tu primera tarea real.',
    ChronoSparkString.onboardingFinishError:
        'No se pudo terminar la introducción. Inténtalo de nuevo.',
    ChronoSparkString.preservedDataIssue:
        'Se encontraron datos conservados en el dispositivo, pero no se puede verificar su cuenta propietaria.',
    ChronoSparkString.preservedDataBody:
        'Continúa solo si estos datos conservados pertenecen a la cuenta iniciada.',
    ChronoSparkString.claimPreservedData:
        'Usar datos conservados con esta cuenta',
    ChronoSparkString.clearPreservedData: 'Borrar datos conservados',
    ChronoSparkString.clearPreservedDataTitle: '¿Borrar datos conservados?',
    ChronoSparkString.clearPreservedDataBody:
        'Esto elimina de este dispositivo los registros de planificación, historial de Línea de Tiempo, acciones sin conexión, recordatorios, progreso del perfil e inteligencia local conservados. No elimina tu cuenta en la nube. No se puede deshacer.',
    ChronoSparkString.privacyPolicyTitle: 'Política de privacidad',
    ChronoSparkString.privacyPolicyBody:
        'ChronoSpark publica su política de privacidad autorizada en la URL HTTPS pública de abajo. Usa la política alojada para consultar el manejo de datos, la retención y los términos de soporte actuales.',
    ChronoSparkString.openHostedPrivacyPolicy:
        'Abrir política de privacidad alojada',
    ChronoSparkString.deleteAccountTitle: 'Eliminar cuenta',
    ChronoSparkString.deleteAccountBody:
        'ChronoSpark publica los pasos para eliminar una cuenta en la URL HTTPS pública de abajo. Usa la página alojada para enviar una solicitud y revisar los detalles de eliminación y retención.',
    ChronoSparkString.openHostedDeleteAccountPage:
        'Abrir página alojada para eliminar cuenta',
    ChronoSparkString.termsTitle: 'Términos de servicio',
    ChronoSparkString.termsBody:
        'ChronoSpark mantiene sus Términos de servicio actuales en la página HTTPS pública de abajo para que las versiones de lanzamiento y las fichas de tienda apunten a la misma fuente de verdad.',
    ChronoSparkString.openHostedTerms: 'Abrir términos alojados',
    ChronoSparkString.supportTitle: 'Soporte',
    ChronoSparkString.supportBody:
        'ChronoSpark publica soporte y ayuda de cuenta para lanzamientos en la URL HTTPS pública de abajo para que revisores de tienda y usuarios puedan llegar al proceso de soporte actual desde cada versión.',
    ChronoSparkString.openHostedSupportPage: 'Abrir página de soporte alojada',
    ChronoSparkString.openWebsite: 'Abrir sitio web',
    ChronoSparkString.unableToOpenWebsite:
        'No se pudo abrir el sitio web desde este dispositivo.',
    ChronoSparkString.couldNotLoadContent: 'No se pudo cargar el contenido.',
    ChronoSparkString.routerErrorTitle: 'No pudimos abrir ese enlace',
    ChronoSparkString.routerErrorBody:
        'El enlace no coincide con una pantalla disponible de ChronoSpark. Registramos un diagnóstico seguro sin mostrar detalles técnicos.',
    ChronoSparkString.routerErrorReturnNexus: 'Volver a Nexus',
    ChronoSparkString.routerErrorReturnLogin: 'Volver al inicio de sesión',
    ChronoSparkString.routerErrorReturnOnboarding: 'Volver a configuración',
    ChronoSparkString.routerErrorReturnSupport: 'Volver a soporte',
  };
}

enum ChronoSparkString {
  nexus,
  smartPlanner,
  creator,
  siConsole,
  timeline,
  trajectoryEngine,
  progression,
  preparingSummary,
  retryNexus,
  whatMattersNext,
  topRisk,
  whatChanged,
  openCreator,
  startInCreator,
  todayTimeBlocks,
  openTimeline,
  timeBlocksUnavailable,
  retry,
  noTimeBlocks,
  createTask,
  upNext,
  complete,
  done,
  timeBlockCompleted,
  timeBlockCompletionFailed,
  whyThisIsNext,
  reviewOrCorrectPlan,
  welcome,
  livingDecisionSystem,
  onboardingWelcomeBody,
  next,
  initialize,
  initializeSystem,
  skip,
  nameQuestion,
  name,
  nameHint,
  primaryGoal,
  goalExecution,
  goalGrowth,
  goalWellness,
  goalExplore,
  personalize,
  lifeDirection,
  calibrateExperience,
  contextualGuidance,
  openContextualGuidance,
  collapseGuidance,
  useThisScreen,
  notNow,
  cancel,
  securingAccountData,
  onboardingPrivacy,
  onboardingWideBody,
  onboardingCompactBody,
  onboardingFinishError,
  preservedDataIssue,
  preservedDataBody,
  claimPreservedData,
  clearPreservedData,
  clearPreservedDataTitle,
  clearPreservedDataBody,
  privacyPolicyTitle,
  privacyPolicyBody,
  openHostedPrivacyPolicy,
  deleteAccountTitle,
  deleteAccountBody,
  openHostedDeleteAccountPage,
  termsTitle,
  termsBody,
  openHostedTerms,
  supportTitle,
  supportBody,
  openHostedSupportPage,
  openWebsite,
  unableToOpenWebsite,
  couldNotLoadContent,
  routerErrorTitle,
  routerErrorBody,
  routerErrorReturnNexus,
  routerErrorReturnLogin,
  routerErrorReturnOnboarding,
  routerErrorReturnSupport,
}

class _ChronoSparkLocalizationsDelegate
    extends LocalizationsDelegate<ChronoSparkLocalizations> {
  const _ChronoSparkLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ChronoSparkLocalizations.supportedLocales
      .any((Locale supported) => supported.languageCode == locale.languageCode);

  @override
  Future<ChronoSparkLocalizations> load(Locale locale) =>
      SynchronousFuture<ChronoSparkLocalizations>(
        ChronoSparkLocalizations(locale),
      );

  @override
  bool shouldReload(_ChronoSparkLocalizationsDelegate old) => false;
}
