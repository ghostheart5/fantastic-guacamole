import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:fantastic_guacamole/domain/operating_system/operating_system_contract.dart';
import 'package:fantastic_guacamole/domain/policies/emotional_safety_policy.dart';
import 'package:fantastic_guacamole/domain/strategic/si_console_shortcut_registry.dart';

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

  PlannerRoutineCopy get plannerRoutine => PlannerRoutineCopy(isSpanish);

  SIRoutineCopy get siRoutine => SIRoutineCopy(isSpanish);

  String text(ChronoSparkString key) =>
      (isSpanish ? _es : _en)[key] ?? _en[key] ?? key.name;

  String moreInTimeline(int count) => isSpanish
      ? '+$count más en la Línea de Tiempo'
      : '+$count more in Timeline';

  String completeTaskLabel(String title) =>
      isSpanish ? 'Completar $title' : 'Complete $title';

  String offlineSemanticLabel({
    required bool cloudSyncAvailable,
    required int pendingSyncCount,
  }) {
    if (!cloudSyncAvailable) {
      return text(ChronoSparkString.offlineLocalSemantic);
    }
    if (pendingSyncCount > 0) {
      return isSpanish
          ? 'Modo sin conexión. $pendingSyncCount acciones en cola. Las acciones se sincronizarán después.'
          : 'Offline mode. $pendingSyncCount actions queued. Actions will sync later.';
    }
    return text(ChronoSparkString.offlineSyncSemantic);
  }

  String offlineVisibleLabel({
    required bool cloudSyncAvailable,
    required int pendingSyncCount,
  }) {
    if (!cloudSyncAvailable) {
      return text(ChronoSparkString.offlineLocalVisible);
    }
    if (pendingSyncCount > 0) {
      return isSpanish
          ? 'Modo sin conexión — $pendingSyncCount en cola; se sincronizarán después'
          : 'Offline Mode — $pendingSyncCount queued, syncing later';
    }
    return text(ChronoSparkString.offlineSyncVisible);
  }

  String aboutPrivacyAndSupportBody({
    required String privacyUrl,
    required String termsUrl,
    required String supportUrl,
    required String supportEmail,
  }) => isSpanish
      ? 'Política de privacidad oficial: $privacyUrl. Términos: $termsUrl. Página de soporte: $supportUrl. Correo de soporte: $supportEmail.'
      : 'Official privacy policy: $privacyUrl. Terms: $termsUrl. Support page: $supportUrl. Support email: $supportEmail.';

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

  String provisionalEvidenceConfidenceLabel(OperatingConfidence confidence) {
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
    return isSpanish
        ? 'Confianza provisional de la evidencia: $label'
        : 'Provisional evidence confidence: $label';
  }

  String emotionalSafetyPauseReason(EmotionalSafetyPauseReasonCode code) {
    if (isSpanish) {
      return switch (code) {
        EmotionalSafetyPauseReasonCode.selfHarm =>
          'Pausamos la planificación normal porque tus palabras mencionan autolesión o suicidio. Es una precaución de enrutamiento, no un juicio sobre tu intención.',
        EmotionalSafetyPauseReasonCode.overdose =>
          'Pausamos la planificación normal porque tus palabras podrían describir una emergencia con medicamentos, drogas o envenenamiento.',
        EmotionalSafetyPauseReasonCode.abuseOrCoercion =>
          'Mantenemos tu seguridad y control en el centro, en lugar de convertir esto en una tarea rutinaria de productividad.',
        EmotionalSafetyPauseReasonCode.panic =>
          'Pausamos la guía de productividad mientras decides qué tipo de apoyo sería útil ahora.',
        EmotionalSafetyPauseReasonCode.grief =>
          'Damos espacio al duelo sin convertirlo en una tarea de productividad no relacionada.',
        EmotionalSafetyPauseReasonCode.relationshipDistress =>
          'Primero queremos entender qué apoyo buscas para tu relación antes de proponer una acción.',
        EmotionalSafetyPauseReasonCode.hallucination =>
          'Pausamos la planificación normal porque el apoyo inmediato puede ser más útil que una recomendación de tareas.',
        EmotionalSafetyPauseReasonCode.severeDistress =>
          'Pausamos la guía de productividad porque tus palabras indican que el apoyo puede importar más que un plan de tareas ahora.',
        EmotionalSafetyPauseReasonCode.general =>
          'Pausamos la planificación normal hasta que elijas qué tipo de ayuda quieres.',
      };
    }
    return switch (code) {
      EmotionalSafetyPauseReasonCode.selfHarm =>
        'Pausing ordinary planning because your words mention self-harm or suicide. This is a routing precaution, not a judgment about your intent.',
      EmotionalSafetyPauseReasonCode.overdose =>
        'Pausing ordinary planning because your words may describe a medication, drug, or poisoning emergency.',
      EmotionalSafetyPauseReasonCode.abuseOrCoercion =>
        'Keeping your safety and control central instead of turning this into a routine productivity task.',
      EmotionalSafetyPauseReasonCode.panic =>
        'Pausing productivity guidance while you decide what kind of support would be useful right now.',
      EmotionalSafetyPauseReasonCode.grief =>
        'Making room for grief without turning it into an unrelated productivity task.',
      EmotionalSafetyPauseReasonCode.relationshipDistress =>
        'Understanding what kind of relationship support you want before proposing an action.',
      EmotionalSafetyPauseReasonCode.hallucination =>
        'Pausing ordinary planning because immediate support may be more useful than a task recommendation.',
      EmotionalSafetyPauseReasonCode.severeDistress =>
        'Pausing productivity guidance because your words indicate that support may matter more than a task plan right now.',
      EmotionalSafetyPauseReasonCode.general =>
        'Pausing ordinary planning until you choose what kind of help you want.',
    };
  }

  String emotionalSafetySupportQuestion(
    EmotionalSafetySupportQuestionCode code,
  ) {
    if (isSpanish) {
      return switch (code) {
        EmotionalSafetySupportQuestionCode.abuseOrCoercion =>
          '¿Quieres recursos de seguridad inmediata, ayuda para contactar a alguien de confianza o una pregunta suave sobre una obligación práctica?',
        EmotionalSafetySupportQuestionCode.grief =>
          '¿Quieres pausar, buscar apoyo o hacer una pregunta suave sobre una obligación práctica?',
        EmotionalSafetySupportQuestionCode.relationshipDistress =>
          '¿Quieres ayuda para preparar una conversación, establecer un límite o decidir qué necesita atención primero?',
        EmotionalSafetySupportQuestionCode.panic =>
          '¿Quieres pausar, contactar a alguien de confianza o buscar recursos de apoyo inmediato?',
        EmotionalSafetySupportQuestionCode.hallucination =>
          '¿Quieres contactar a alguien de confianza o buscar recursos de apoyo inmediato?',
        EmotionalSafetySupportQuestionCode.general =>
          '¿Quieres pausar, contactar a alguien de confianza, buscar recursos de apoyo o continuar con una pregunta aclaratoria suave?',
      };
    }
    return switch (code) {
      EmotionalSafetySupportQuestionCode.abuseOrCoercion =>
        'Would you like immediate safety resources, help contacting someone you trust, or a gentle question about one practical obligation?',
      EmotionalSafetySupportQuestionCode.grief =>
        'Would you like to pause, find support, or ask one gentle question about a practical obligation?',
      EmotionalSafetySupportQuestionCode.relationshipDistress =>
        'Would you like help preparing a conversation, setting a boundary, or deciding what needs attention first?',
      EmotionalSafetySupportQuestionCode.panic =>
        'Would you like to pause, contact someone you trust, or find immediate support resources?',
      EmotionalSafetySupportQuestionCode.hallucination =>
        'Would you like to contact someone you trust or find immediate support resources?',
      EmotionalSafetySupportQuestionCode.general =>
        'Would you like to pause, contact someone you trust, find support resources, or continue with one gentle clarifying question?',
    };
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
    ChronoSparkString.accountDataLockIssue:
        'ChronoSpark could not verify account data safely. Sign out and try again.',
    ChronoSparkString.signOutAndReturnToLogin: 'Sign out and return to login',
    ChronoSparkString.accountRecoveryInProgress:
        'Completing account recovery action',
    ChronoSparkString.accountRecoveryFailed:
        'That recovery action could not be completed. Please try again or sign out.',
    ChronoSparkString.onboardingPrivacy:
        'Your display name stays on this device unless you choose cloud backup. Smart Planner and SI Console use saved planning context; external AI processing is opt-in and explained in Settings.',
    ChronoSparkString.onboardingWideBody:
        'Choose what ChronoSpark should call you. The rest of setup learns from the real task you create next.',
    ChronoSparkString.onboardingCompactBody:
        'Choose what ChronoSpark should call you, then build your first real task.',
    ChronoSparkString.onboardingFinishError:
        'Unable to finish onboarding. Please try again.',
    ChronoSparkString.onboardingContinueError:
        'Unable to continue. Please try again.',
    ChronoSparkString.loginCreateAccountEyebrow: 'CREATE ACCOUNT',
    ChronoSparkString.loginAccessSystemEyebrow: 'ACCESS SYSTEM',
    ChronoSparkString.loginCreateWorkspace: 'Create your workspace',
    ChronoSparkString.loginWelcomeBack: 'Welcome back',
    ChronoSparkString.loginSecureAccessBody:
        'Secure access to your connected planning workspace.',
    ChronoSparkString.loginEmailAddress: 'Email address',
    ChronoSparkString.loginPassword: 'Password',
    ChronoSparkString.loginShowPassword: 'Show password',
    ChronoSparkString.loginHidePassword: 'Hide password',
    ChronoSparkString.loginForgotPassword: 'Forgot Password?',
    ChronoSparkString.loginInitializeProfile: 'INITIALIZE PROFILE',
    ChronoSparkString.loginEnterSystem: 'ENTER SYSTEM',
    ChronoSparkString.loginContinueDivider: 'OR CONTINUE WITH',
    ChronoSparkString.loginContinueGoogle: 'Continue with Google',
    ChronoSparkString.loginContinueGithub: 'Continue with GitHub',
    ChronoSparkString.loginSwitchToLogin: 'Switch to Login',
    ChronoSparkString.loginCreateAccount: 'Create Account',
    ChronoSparkString.offlineLocalSemantic:
        'Offline mode. Local features remain available. Cloud sync is unavailable in this build.',
    ChronoSparkString.offlineSyncSemantic:
        'Offline mode. Actions will sync later.',
    ChronoSparkString.offlineLocalVisible:
        'Offline Mode — local features available; cloud sync unavailable',
    ChronoSparkString.offlineSyncVisible:
        'Offline Mode — actions will sync later',
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
    ChronoSparkString.aboutTitle: 'ABOUT CHRONOSPARK',
    ChronoSparkString.aboutSubtitle:
        'An adaptive planner built for clarity, momentum, and reflective execution.',
    ChronoSparkString.aboutEyebrow: 'SYSTEM IDENTITY',
    ChronoSparkString.aboutWhatItDoesTitle: 'What It Does',
    ChronoSparkString.aboutWhatItDoesBody:
        'ChronoSpark combines tasks, planning, logs, and AI-assisted strategy in one system so you can execute consistently without losing context.',
    ChronoSparkString.aboutCoreSurfacesTitle: 'Core Surfaces',
    ChronoSparkString.aboutCoreSurfacesBody:
        'Nexus for decisions, Trajectory Engine for possible paths, Timeline for history, and Profile for identity and progression. Smart Planner, Creator, SI Console, and Progression add depth when needed.',
    ChronoSparkString.aboutGuidingPrincipleTitle: 'Guiding Principle',
    ChronoSparkString.aboutGuidingPrincipleBody:
        'Reduce friction between intent and action. Keep planning lightweight, execution clear, and reflection actionable.',
    ChronoSparkString.aboutPrivacyAndSupportTitle: 'Privacy and Support',
    ChronoSparkString.aboutVoiceFeaturesTitle: 'Voice Features',
    ChronoSparkString.aboutVoiceFeaturesBody:
        'Microphone access powers optional voice-to-text in Smart Planner and the SI Console. Audio is used only after you start a voice action and remains off during normal planning flows.',
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
    ChronoSparkString.accountDataLockIssue:
        'ChronoSpark no pudo verificar los datos de la cuenta de forma segura. Cierra sesión e inténtalo de nuevo.',
    ChronoSparkString.signOutAndReturnToLogin:
        'Cerrar sesión y volver al inicio',
    ChronoSparkString.accountRecoveryInProgress:
        'Completando la acción de recuperación de la cuenta',
    ChronoSparkString.accountRecoveryFailed:
        'No se pudo completar esa acción de recuperación. Inténtalo de nuevo o cierra sesión.',
    ChronoSparkString.onboardingPrivacy:
        'Tu nombre visible permanece en este dispositivo salvo que actives la copia en la nube. Planificador Inteligente y Consola SI usan el contexto guardado; el procesamiento externo con IA es opcional y se explica en Ajustes.',
    ChronoSparkString.onboardingWideBody:
        'Elige cómo debe llamarte ChronoSpark. El resto de la configuración aprenderá de la tarea real que crearás después.',
    ChronoSparkString.onboardingCompactBody:
        'Elige cómo debe llamarte ChronoSpark y luego crea tu primera tarea real.',
    ChronoSparkString.onboardingFinishError:
        'No se pudo terminar la introducción. Inténtalo de nuevo.',
    ChronoSparkString.onboardingContinueError:
        'No se pudo continuar. Inténtalo de nuevo.',
    ChronoSparkString.loginCreateAccountEyebrow: 'CREAR CUENTA',
    ChronoSparkString.loginAccessSystemEyebrow: 'ACCEDER AL SISTEMA',
    ChronoSparkString.loginCreateWorkspace: 'Crea tu espacio de trabajo',
    ChronoSparkString.loginWelcomeBack: 'Te damos la bienvenida',
    ChronoSparkString.loginSecureAccessBody:
        'Acceso seguro a tu espacio de planificación conectado.',
    ChronoSparkString.loginEmailAddress: 'Correo electrónico',
    ChronoSparkString.loginPassword: 'Contraseña',
    ChronoSparkString.loginShowPassword: 'Mostrar contraseña',
    ChronoSparkString.loginHidePassword: 'Ocultar contraseña',
    ChronoSparkString.loginForgotPassword: '¿Olvidaste la contraseña?',
    ChronoSparkString.loginInitializeProfile: 'INICIAR PERFIL',
    ChronoSparkString.loginEnterSystem: 'ENTRAR AL SISTEMA',
    ChronoSparkString.loginContinueDivider: 'O CONTINÚA CON',
    ChronoSparkString.loginContinueGoogle: 'Continuar con Google',
    ChronoSparkString.loginContinueGithub: 'Continuar con GitHub',
    ChronoSparkString.loginSwitchToLogin: 'Volver al acceso',
    ChronoSparkString.loginCreateAccount: 'Crear cuenta',
    ChronoSparkString.offlineLocalSemantic:
        'Modo sin conexión. Las funciones locales siguen disponibles. La sincronización en la nube no está disponible en esta versión.',
    ChronoSparkString.offlineSyncSemantic:
        'Modo sin conexión. Las acciones se sincronizarán después.',
    ChronoSparkString.offlineLocalVisible:
        'Modo sin conexión — funciones locales disponibles; sincronización en la nube no disponible',
    ChronoSparkString.offlineSyncVisible:
        'Modo sin conexión — se sincronizará después',
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
    ChronoSparkString.aboutTitle: 'ACERCA DE CHRONOSPARK',
    ChronoSparkString.aboutSubtitle:
        'Un planificador adaptativo creado para aportar claridad, impulso y una ejecución reflexiva.',
    ChronoSparkString.aboutEyebrow: 'IDENTIDAD DEL SISTEMA',
    ChronoSparkString.aboutWhatItDoesTitle: 'Qué hace',
    ChronoSparkString.aboutWhatItDoesBody:
        'ChronoSpark combina tareas, planificación, registros y estrategia asistida por IA en un solo sistema para que puedas actuar de forma constante sin perder el contexto.',
    ChronoSparkString.aboutCoreSurfacesTitle: 'Áreas principales',
    ChronoSparkString.aboutCoreSurfacesBody:
        'Nexus ayuda con las decisiones, Motor de Trayectoria explora caminos posibles, Línea de Tiempo conserva el historial y Perfil reúne identidad y progreso. Planificador Inteligente, Creador, Consola SI y Progresión añaden profundidad cuando hace falta.',
    ChronoSparkString.aboutGuidingPrincipleTitle: 'Principio rector',
    ChronoSparkString.aboutGuidingPrincipleBody:
        'Reduce la fricción entre la intención y la acción. Mantén la planificación ligera, la ejecución clara y la reflexión práctica.',
    ChronoSparkString.aboutPrivacyAndSupportTitle: 'Privacidad y soporte',
    ChronoSparkString.aboutVoiceFeaturesTitle: 'Funciones de voz',
    ChronoSparkString.aboutVoiceFeaturesBody:
        'El acceso al micrófono permite usar voz a texto de forma opcional en Planificador Inteligente y Consola SI. El audio se usa solo después de que inicias una acción de voz y permanece desactivado durante la planificación normal.',
    ChronoSparkString.routerErrorTitle: 'No pudimos abrir ese enlace',
    ChronoSparkString.routerErrorBody:
        'El enlace no coincide con una pantalla disponible de ChronoSpark. Registramos un diagnóstico seguro sin mostrar detalles técnicos.',
    ChronoSparkString.routerErrorReturnNexus: 'Volver a Nexus',
    ChronoSparkString.routerErrorReturnLogin: 'Volver al inicio de sesión',
    ChronoSparkString.routerErrorReturnOnboarding: 'Volver a configuración',
    ChronoSparkString.routerErrorReturnSupport: 'Volver a soporte',
  };
}

@immutable
final class PlannerRoutineCopy {
  const PlannerRoutineCopy(this.isSpanish);

  final bool isSpanish;

  String get accessCheckFailed => isSpanish
      ? 'No se pudo verificar el acceso al Planificador Inteligente. No se enviará ninguna solicitud de orientación.'
      : 'Planner access could not be verified. No guidance request will be sent.';
  String get checkingAccess => isSpanish
      ? 'Verificando el acceso al Planificador Inteligente...'
      : 'Checking Smart Planner access...';
  String get accessUnavailable => isSpanish
      ? 'El Planificador Inteligente no está habilitado para esta cuenta. No se enviará ninguna solicitud de orientación.'
      : 'Smart Planner is not enabled for this account. No guidance request will be sent.';
  String get onDeviceReady => isSpanish
      ? 'El Planificador Inteligente en el dispositivo está listo.'
      : 'On-device Smart Planner is ready.';
  String get retryAccessCheck =>
      isSpanish ? 'Reintentar verificación de acceso' : 'Retry access check';
  String get guidanceUnavailable => isSpanish
      ? 'El Planificador Inteligente aún no está habilitado para esta cuenta. Tu registro no se guardó ni cambió.'
      : 'Smart Planner is not enabled for this account yet. Your check-in was not saved or changed.';
  String get guidanceRetry => isSpanish
      ? 'No se pudo generar la orientación. Tu registro sigue aquí. Pulsa OBTENER ORIENTACIÓN para reintentar.'
      : 'Guidance could not be generated. Your check-in is still here. Tap GET GUIDANCE to retry.';
  String get personContextChanged => isSpanish
      ? 'Tu Contexto Personal cambió, por lo que se borró la orientación anterior. Pulsa OBTENER ORIENTACIÓN para revisar un plan actual.'
      : 'Your Person Context changed, so the previous guidance was cleared. Tap GET GUIDANCE to review a current plan.';
  String get guidanceTimeout => isSpanish
      ? 'La solicitud de orientación agotó el tiempo. Pulsa OBTENER ORIENTACIÓN otra vez o acorta el texto para recibir una respuesta más rápida.'
      : 'Guidance request timed out. Tap GET GUIDANCE again or shorten your input for a faster response.';
  String get followUpTimeout => isSpanish
      ? 'La pregunta de seguimiento agotó el tiempo. Reintenta con una indicación más corta.'
      : 'Follow-up timed out. Retry with a shorter prompt.';
  String get followUpTransmitFailed => isSpanish
      ? 'No se pudo enviar el seguimiento. Pulsa REINTENTAR ENLACE.'
      : 'Follow-up transmit failed. Tap Retry Link.';
  String get smallerStatus => isSpanish
      ? 'El plan ahora es más pequeño. No se guardó nada.'
      : 'The plan is smaller. Nothing has been saved.';
  String smallerTitle(String title) =>
      isSpanish ? 'Más pequeño: $title' : 'Smaller: $title';
  String smallerDescription({required int minutes, required String detail}) =>
      isSpanish
      ? 'Empieza con un paso de preparación de $minutes minutos. $detail'
      : 'Begin with a $minutes-minute setup step. $detail';
  String get smallerTradeoff => isSpanish
      ? 'Esto reduce todavía más el costo de empezar y deja más trabajo para después.'
      : 'This reduces activation cost further and leaves more work for later.';
  String get smallerReason => isSpanish
      ? 'Pediste un comienzo más pequeño, así que se conserva solo un breve paso de preparación.'
      : 'You asked for a smaller start, so this keeps only a brief setup step.';
  String get minimumSelectedReason => isSpanish
      ? 'Pediste un plan más pequeño, así que ahora está seleccionada la opción mínima.'
      : 'You asked for a smaller plan, so the minimum option is now selected.';
  String get differentApproachStatus => isSpanish
      ? 'Se seleccionó un enfoque distinto. No se guardó nada.'
      : 'A different approach is selected. Nothing has been saved.';
  String get differentApproachReason => isSpanish
      ? 'Pediste un enfoque distinto, así que se seleccionó otra opción limitada.'
      : 'You asked for a different approach, so another bounded option is selected.';
  String get audioUnavailable => isSpanish
      ? 'El audio no está disponible. Revisa la configuración de texto a voz y el volumen multimedia.'
      : 'Audio is unavailable. Check text-to-speech settings and media volume.';
  String voiceReadLabel({required bool reading}) => isSpanish
      ? reading
            ? 'Leyendo en voz alta toda la orientación de planificación'
            : 'Leer en voz alta toda la orientación de planificación'
      : reading
      ? 'Reading full planning guidance aloud'
      : 'Read full planning guidance aloud';
  String voiceReadButton({required bool reading}) => isSpanish
      ? reading
            ? 'LEYENDO'
            : 'LEER EN VOZ ALTA'
      : reading
      ? 'READING'
      : 'READ ALOUD';
  String get voiceSummaryLabel => isSpanish
      ? 'Leer en voz alta un resumen breve de planificación'
      : 'Read condensed planning summary aloud';
  String get voiceSummaryTitle => isSpanish
      ? 'Resumen de voz del Planificador Inteligente'
      : 'Smart Planner voice summary';
  String get summaryButton => isSpanish ? 'RESUMEN' : 'SUMMARY';
  String energySummary(double? energy) => energy == null
      ? isSpanish
            ? 'No se indicó la energía'
            : 'Energy was not set'
      : isSpanish
      ? 'La energía es ${(energy * 100).round()} por ciento'
      : 'Energy is ${(energy * 100).round()} percent';
  String emotionSummary(String? emotion) => emotion == null
      ? isSpanish
            ? 'No se usó el estado emocional'
            : 'Emotional state was not used'
      : isSpanish
      ? 'El estado emocional es $emotion'
      : 'Emotion state is $emotion';
  String get accessibilityLabel => isSpanish
      ? 'Abrir la guía de accesibilidad del Planificador Inteligente y leerla en voz alta'
      : 'Open Smart Planner accessibility guide and read it aloud';
  String get accessibilityTitle =>
      isSpanish ? 'Guía de accesibilidad' : 'Accessibility Guide';
  String get accessibilityBody => isSpanish
      ? 'A11Y significa accesibilidad. Usa estos controles para facilitar la lectura y la orientación por audio.'
      : 'A11Y means accessibility. Use these controls for easier reading and audio guidance.';
  String get accessibilityButton => isSpanish ? 'ACCESO' : 'ACCESS';
  String get accessibilitySurface =>
      isSpanish ? 'Planificador Inteligente' : 'Smart Planner';
  List<String> get accessibilityControls => isSpanish
      ? const <String>[
          'Ajusta el control de energía para definir la intensidad',
          'Selecciona el estado emocional para adaptar la orientación',
          'Usa Obtener orientación para generar una respuesta de planificación',
          'Usa el botón de voz para leer en voz alta la orientación más reciente',
          'Usa el botón de resumen para escuchar un repaso breve',
          'Usa el botón del micrófono para las interacciones de voz',
        ]
      : const <String>[
          'Adjust energy slider to set intensity',
          'Select emotional state to tune guidance',
          'Use Get Guidance to generate a planning response',
          'Use the speak button to read the latest guidance aloud',
          'Use summary button for condensed voice recap',
          'Use microphone button for voice interactions',
        ];
  String voiceInputLabel({required bool listening}) => isSpanish
      ? listening
            ? 'Detener entrada de voz'
            : 'Iniciar entrada de voz'
      : listening
      ? 'Stop voice input'
      : 'Start voice input';
  String voiceInputButton({required bool listening}) => isSpanish
      ? listening
            ? 'ESCUCHANDO'
            : 'ENTRADA DE VOZ'
      : listening
      ? 'LISTENING'
      : 'VOICE INPUT';
  String get voiceInputUnavailable => isSpanish
      ? 'La entrada de voz no está disponible. Revisa el permiso y reintenta.'
      : 'Voice input is unavailable. Check permission and retry.';
  String get planningContextLabel =>
      isSpanish ? 'Contexto de planificación' : 'Planning context';
  String get currentCheckInSection =>
      isSpanish ? 'REGISTRO ACTUAL' : 'CURRENT CHECK-IN';
  String get emotionalStateSection =>
      isSpanish ? 'ESTADO EMOCIONAL' : 'EMOTIONAL STATE';
  String get planningContextSection =>
      isSpanish ? 'CONTEXTO DE PLANIFICACIÓN' : 'PLANNING CONTEXT';
  String emotionalStateNotice({required bool enabled}) => isSpanish
      ? enabled
            ? 'Solo se usa el estado que seleccionas para este registro.'
            : 'No se usa el estado emocional. Actívalo en Configuración para incluir una selección.'
      : enabled
      ? 'Only the state you select is used for this check-in.'
      : 'Emotional state is not used. Enable it in Settings to include a selection.';
  String get planningContextHint => isSpanish
      ? '¿Qué te gustaría planificar ahora?'
      : 'What would you like help planning right now?';
  String get ephemeralNotice => isSpanish
      ? 'Tus palabras y tu registro son temporales. Un recibo local de decisión puede registrar qué orientación se mostró o usó. No se guarda nada más salvo que recuerdes una preferencia de forma explícita.'
      : 'Your words and check-in stay ephemeral. A local decision receipt may record which guidance was shown or used. Nothing else is saved unless you explicitly remember a preference.';
  String get checkingButton =>
      isSpanish ? 'VERIFICANDO ACCESO...' : 'CHECKING ACCESS...';
  String get unavailableButton =>
      isSpanish ? 'PLANIFICADOR NO DISPONIBLE' : 'PLANNER UNAVAILABLE';
  String get thinkingButton => isSpanish ? 'PENSANDO...' : 'THINKING...';
  String guidanceButton({required bool refresh}) => isSpanish
      ? refresh
            ? 'ACTUALIZAR ORIENTACIÓN'
            : 'OBTENER ORIENTACIÓN'
      : refresh
      ? 'REFRESH GUIDANCE'
      : 'GET GUIDANCE';
  String get guidanceReady => isSpanish
      ? 'Orientación de planificación lista'
      : 'Planning guidance ready';
  String get subtitle => isSpanish
      ? 'Construye tu próximo plan con evidencia real.'
      : 'Build your next plan from real evidence.';
  String get eyebrow => isSpanish ? 'Espectro del plan' : 'Plan spectrum';
}

@immutable
final class SIRoutineCopy {
  const SIRoutineCopy(this.isSpanish);

  final bool isSpanish;

  String get accessCheckFailed => isSpanish
      ? 'No se pudo verificar el acceso a la Consola SI. No se envió ninguna consulta.'
      : 'SI Console access could not be verified. No query was sent.';
  String get checkingAccess => isSpanish
      ? 'Verificando el acceso a la Consola SI...'
      : 'Checking SI Console access...';
  String get accessUnavailable => isSpanish
      ? 'La Consola SI no está habilitada para esta cuenta. No se envió ninguna consulta.'
      : 'SI Console is not enabled for this account. No query was sent.';
  String get contextUnavailable => isSpanish
      ? 'El contexto estratégico no está disponible temporalmente. Tu trabajo guardado no cambió.'
      : 'Strategic context is temporarily unavailable. Saved work is unchanged.';
  String get initializingContext => isSpanish
      ? 'Inicializando el contexto SI...'
      : 'Initializing SI context...';
  String get evidenceUnavailable => isSpanish
      ? 'Estado de evidencia no disponible.'
      : 'Evidence state unavailable.';
  String noEvidence(String personBoundary) => isSpanish
      ? 'Todavía no hay evidencia de planificación. SI identificará lo que no puede determinar. $personBoundary'
      : 'No planning evidence yet. SI will identify what it cannot determine. $personBoundary';
  String evidenceReady({
    required int tasks,
    required int goals,
    required int milestones,
    required int timeline,
    required String personBoundary,
  }) => isSpanish
      ? 'Evidencia lista: $tasks tareas · $goals objetivos · $milestones hitos · $timeline en Línea de Tiempo. $personBoundary'
      : 'Evidence ready: $tasks tasks · $goals goals · $milestones milestones · $timeline Timeline. $personBoundary';
  String get personContextUnavailable => isSpanish
      ? 'Contexto personal: no disponible; SI no infirió nada personal.'
      : 'Person context: unavailable; SI inferred nothing personal.';
  String get personContextNotRelevant => isSpanish
      ? 'Contexto personal: compartido, pero ningún elemento fue relevante para este enfoque.'
      : 'Person context: shared but no item was relevant to this lens.';
  String personContextEvidence(int count) => isSpanish
      ? 'Contexto personal: ${count == 1 ? 'se cita 1 elemento pertinente declarado por el usuario' : 'se citan $count elementos pertinentes declarados por el usuario'} como evidencia no verificada de forma independiente.'
      : 'Person context: $count relevant user-reported ${count == 1 ? 'item is' : 'items are'} cited as evidence and not independently verified.';
  String get retryEvidence =>
      isSpanish ? 'Reintentar carga de evidencia' : 'Retry evidence loading';
  String get unavailableSavedWork => isSpanish
      ? 'Esta cuenta no tiene acceso actualmente. Tu trabajo guardado no cambió.'
      : 'This account does not currently have access. Your saved work is unchanged.';
  String get welcomeNoEvidence => isSpanish
      ? 'Todavía no hay evidencia de planificación disponible. SI indicará la evidencia faltante en vez de adivinar.'
      : 'No planning evidence is available yet. SI will name missing evidence instead of guessing.';
  String get welcomeReady => isSpanish
      ? 'Pregunta por tareas, objetivos, hitos o la Línea de Tiempo actuales. SI lee evidencia y no puede cambiar los datos guardados.'
      : 'Ask about current tasks, goals, milestones, or Timeline. SI reads evidence and cannot change saved data.';
  List<String> welcomeExamples({required bool noEvidence}) => isSpanish
      ? noEvidence
            ? const <String>['¿Qué evidencia falta?', '¿Qué puedes determinar?']
            : const <String>[
                '¿Qué necesita atención?',
                '¿Qué debería hacer después?',
              ]
      : noEvidence
      ? const <String>['What evidence is missing?', 'What can you determine?']
      : const <String>['What needs attention?', 'What should I do next?'];
  String get askFromEvidence => isSpanish
      ? 'Pregunta desde la evidencia actual'
      : 'Ask from current evidence';
  String get backToNexus => isSpanish ? 'Volver a Nexus' : 'Back to Nexus';
  String get title => isSpanish ? 'Consola SI V2' : 'SI Console V2';
  String get subtitle => isSpanish
      ? 'Inteligencia de sistemas · orientación con fuentes'
      : 'Systems intelligence · source-aware guidance';
  String get eyebrow => isSpanish ? 'Rastreo de evidencia' : 'Evidence trace';
  String get readSummary => isSpanish ? 'Leer resumen' : 'Read summary';
  String get accessibilityGuide =>
      isSpanish ? 'Guía de accesibilidad' : 'Accessibility guide';
  String get advanced => isSpanish ? 'Avanzado' : 'Advanced';
  String get advancedSubtitle => isSpanish
      ? 'Intención, fuentes, intervalo, filtros, supuestos y alias'
      : 'Intent, sources, range, filters, assumptions, and aliases';
  String get queryBuilder =>
      isSpanish ? 'GENERADOR DE CONSULTAS SI V2' : 'SI V2 QUERY BUILDER';
  String get entityFilter =>
      isSpanish ? 'Filtro de entidad (opcional)' : 'Entity filter (optional)';
  String get scenarioAssumption => isSpanish
      ? 'Supuesto del escenario (opcional)'
      : 'Scenario assumption (optional)';
  String get choosePowerAlias =>
      isSpanish ? 'Elegir un alias avanzado' : 'Choose a power alias';
  String get powerAliases => isSpanish ? 'ALIAS AVANZADOS' : 'POWER ALIASES';
  String get queryLabel => isSpanish ? 'Consulta SI' : 'SI query';
  String get queryHint => isSpanish
      ? 'Pregunta a SI V2 sobre la evidencia actual...'
      : 'Ask SI V2 about current evidence...';
  String get yourQuery => isSpanish ? 'Tu consulta' : 'Your query';
  String get siResponse => isSpanish ? 'Respuesta de SI' : 'SI response';
  String whyThisAppears(String rationale) => isSpanish
      ? 'Por qué aparece: $rationale'
      : 'Why this appears: $rationale';
  String get directAnswer => isSpanish ? 'RESPUESTA DIRECTA' : 'DIRECT ANSWER';
  String get recommendation => isSpanish ? 'RECOMENDACIÓN' : 'RECOMMENDATION';
  String get responseAdvancedSubtitle => isSpanish
      ? 'Confianza, evidencia, cálculos y supuestos'
      : 'Confidence, evidence, calculations, and assumptions';
  String get observedFacts =>
      isSpanish ? 'HECHOS OBSERVADOS' : 'OBSERVED FACTS';
  String get userReportedContext =>
      isSpanish ? 'CONTEXTO DECLARADO POR EL USUARIO' : 'USER-REPORTED CONTEXT';
  String get deterministicCalculations =>
      isSpanish ? 'CÁLCULOS DETERMINISTAS' : 'DETERMINISTIC CALCULATIONS';
  String get inferences => isSpanish ? 'INFERENCIAS' : 'INFERENCES';
  String get missingOrConflicting => isSpanish
      ? 'INFORMACIÓN FALTANTE O CONTRADICTORIA'
      : 'MISSING OR CONFLICTING INFORMATION';
  String get scenarios => isSpanish ? 'ESCENARIOS' : 'SCENARIOS';
  String get scenarioAssumptions =>
      isSpanish ? 'SUPUESTOS DEL ESCENARIO' : 'SCENARIO ASSUMPTIONS';
  String get confidenceAnatomy =>
      isSpanish ? 'ANATOMÍA DE LA CONFIANZA' : 'CONFIDENCE ANATOMY';
  String get evidenceLinks =>
      isSpanish ? 'ENLACES DE EVIDENCIA' : 'EVIDENCE LINKS';
  String get noneIdentified =>
      isSpanish ? 'No se identificó ninguno.' : 'None identified.';
  String evidenceStrength(String value) => isSpanish
      ? 'Solidez de la evidencia: $value'
      : 'Evidence strength: $value';
  String confidenceCoverage({required int covered, required int required}) =>
      isSpanish
      ? 'Cobertura: $covered de $required señales requeridas'
      : 'Coverage: $covered of $required required signals';
  String confidenceFreshness(String value) =>
      isSpanish ? 'Actualidad: $value' : 'Freshness: $value';
  String confidenceConflicts(int count) =>
      isSpanish ? 'Conflictos: $count' : 'Conflicts: $count';
  String confidenceAssumptions(int count) =>
      isSpanish ? 'Supuestos: $count' : 'Assumptions: $count';
  String get accessibilityTitle =>
      isSpanish ? 'Guía de accesibilidad' : 'Accessibility Guide';
  String get accessibilityBody => isSpanish
      ? 'Usa estos controles para obtener orientación legible y hablada.'
      : 'Use these controls for readable and spoken guidance.';
  List<String> get accessibilityControls => isSpanish
      ? const <String>[
          'Escribe una indicación en el campo y luego envíala.',
          'Usa Resumen para escuchar respuestas recientes del asistente.',
          'Usa Escuchar en las respuestas del asistente para leerlas en voz alta.',
          'Usa Atrás para volver a Nexus.',
        ]
      : const <String>[
          'Type a prompt in the input field, then send.',
          'Use Summary to hear recent assistant responses.',
          'Use Speak on assistant bubbles to read aloud.',
          'Use Back to return to Nexus.',
        ];
  List<String> get accessibilitySteps => isSpanish
      ? const <String>[
          '1. Escribe una indicación y luego envíala.',
          '2. Resumen lee respuestas recientes del asistente.',
          '3. Escuchar lee una respuesta en voz alta.',
          '4. Atrás vuelve a Nexus.',
        ]
      : const <String>[
          '1. Type a prompt, then send.',
          '2. Summary reads recent assistant responses.',
          '3. Speak reads one response aloud.',
          '4. Back returns to Nexus.',
        ];
  String get accessibilitySurface => isSpanish ? 'Consola SI' : 'SI Console';
  String get personContextChanged => isSpanish
      ? 'Tu Contexto Personal cambió, por lo que se borraron las respuestas anteriores basadas en evidencia de SI. Pregunta otra vez para usar la evidencia actual.'
      : 'Your Person Context changed, so previous SI evidence responses were cleared. Ask again to use the current evidence.';
  String unknownShortcut(String token) => isSpanish
      ? 'Atajo desconocido "$token". No se envió ni descartó ninguna parte de la solicitud. Usa /help para ver los atajos disponibles.'
      : 'Unknown shortcut "$token". No part of the request was sent or discarded. Use /help to list the available shortcuts.';
  String rejectedArguments({
    required String shortcut,
    required String arguments,
  }) => isSpanish
      ? '$shortcut no acepta texto adicional. No se ignoró ni envió ningún argumento. Usa $shortcut solo. Recibido: "$arguments"'
      : '$shortcut does not accept extra text. No argument was ignored or sent. Use $shortcut alone. Received: "$arguments"';
  String shortcutLabel(SIConsoleShortcutDefinition definition) {
    if (!isSpanish) return definition.label;
    return switch (definition.id) {
      'help' => 'Ayuda',
      'status' => 'Estado',
      'tasks' => 'Tareas',
      'goals' => 'Objetivos',
      'plan' => 'Plan',
      'milestones' => 'Hitos',
      'timeline' => 'Línea de Tiempo',
      'trajectory' => 'Trayectoria',
      'progression' => 'Progresión',
      'memories' => 'Memorias',
      'emotions' => 'Emociones',
      _ => definition.label,
    };
  }

  String shortcutDescription(SIConsoleShortcutDefinition definition) {
    if (!isSpanish) return definition.description;
    return switch (definition.id) {
      'help' => 'ver los atajos o explicar uno',
      'status' => 'mostrar qué fuentes de evidencia están disponibles',
      'tasks' => 'revisar tareas activas y próximos pasos',
      'goals' => 'resumir objetivos y desvíos',
      'plan' => 'resumir el horario y los próximos bloques',
      'milestones' => 'resumir salud, riesgo y próximo objetivo de los hitos',
      'timeline' => 'resumir hitos y eventos recientes',
      'trajectory' => 'resumir impulso, presión y predicción',
      'progression' => 'analizar nivel, XP, racha y señales de progreso',
      'memories' => 'analizar preferencias guardadas y memorias pertinentes',
      'emotions' => 'analizar evidencia explícita del registro emocional',
      _ => definition.description,
    };
  }

  String shortcutHelp({required String filter}) {
    final String normalized = filter.trim();
    final List<SIConsoleShortcutDefinition> selected = normalized.isEmpty
        ? SIConsoleShortcutRegistry.definitions
        : SIConsoleShortcutRegistry.definitions
              .where(
                (SIConsoleShortcutDefinition item) =>
                    item.matchesFilter(normalized),
              )
              .toList(growable: false);
    if (selected.isEmpty) {
      return isSpanish
          ? 'ATAJOS DE CONSULTA SI\n\nNingún atajo coincide con "$normalized". Usa /help para ver todos los atajos disponibles.'
          : 'SI QUERY SHORTCUTS\n\nNo shortcut matches "$normalized". Use /help to list every available shortcut.';
    }
    final String lines = selected
        .map((SIConsoleShortcutDefinition item) {
          final String aliases = item.aliases
              .where((String alias) => alias.startsWith('/'))
              .join(', ');
          final String aliasText = aliases.isEmpty
              ? ''
              : isSpanish
              ? ' (alias: $aliases)'
              : ' (aliases: $aliases)';
          return '- ${item.usage}$aliasText: ${shortcutDescription(item)}';
        })
        .join('\n');
    return isSpanish
        ? 'ATAJOS DE CONSULTA SI\n\nAtajos disponibles:\n$lines'
        : 'SI QUERY SHORTCUTS\n\nAvailable shortcuts:\n$lines';
  }

  String get shortcutRules => isSpanish
      ? 'Reglas:\n- Las tareas se crean solo en Creador. Usa Creador para crear tareas.\n- SI V2 tiene acceso de solo lectura a la evidencia y no puede modificar los datos del dominio.\n- El generador visible de consultas es el control principal; los atajos son alias.\n\nIndicaciones SI V2 de alta señal:\n- "¿Qué necesita atención?"\n- "¿Por qué está en riesgo este objetivo?"\n- "Compara mis dos objetivos más próximos."\n- "¿Qué pasa si aplazo esta tarea?"\n- "¿Qué compromisos entran en conflicto?"\n- "¿Qué cambiaría tu recomendación?"'
      : 'Rules:\n- Task creation is Creator-only. Use Creator to create tasks.\n- SI V2 has read-only evidence capability and cannot mutate domain data.\n- The visible query builder is primary; shortcuts are aliases.\n\nHigh-signal SI V2 prompts:\n- "What needs attention?"\n- "Why is this goal at risk?"\n- "Compare my two nearest goals."\n- "What happens if I defer this task?"\n- "Which commitments conflict?"\n- "What would change your recommendation?"';
  String statusLoading() => isSpanish
      ? 'ESTADO DE SI\n\nLas fuentes de datos locales todavía se están cargando. Reintenta /status en un momento.\nNo se cambió ningún dato del dominio.'
      : 'SI STATUS\n\nLocal data sources are still loading. Retry /status in a second.\nNo domain data was changed.';
  String statusReady({
    required int tasks,
    required int goals,
    required int milestones,
    required int timeline,
    required int unavailableSources,
    required String revision,
    required String aliases,
  }) => isSpanish
      ? 'ESTADO DE SI\n\nEnfoque de evidencia de solo lectura:\n- tareas: $tasks\n- objetivos: $goals\n- hitos: $milestones\n- Línea de Tiempo: $timeline\n- fuentes no disponibles: $unavailableSources\n- revisión: $revision\n\nAlias de evidencia disponibles: $aliases.'
      : 'SI STATUS\n\nRead-only Evidence Lens:\n- tasks: $tasks\n- goals: $goals\n- milestones: $milestones\n- Timeline: $timeline\n- unavailable sources: $unavailableSources\n- revision: $revision\n\nAvailable evidence aliases: $aliases.';
  String get responseValidationFailed => isSpanish
      ? 'SI V2 no pudo validar una respuesta de evidencia de solo lectura. Reintenta, amplía el Enfoque de Evidencia o selecciona tareas, objetivos, hitos o Línea de Tiempo. No se cambió nada.'
      : 'SI V2 could not validate a read-only evidence response. Retry, broaden the Evidence Lens, or select tasks, goals, milestones, or Timeline. Nothing was changed.';
  String get voiceSummaryTitle => isSpanish
      ? 'Resumen de voz de la Consola SI'
      : 'SI console voice summary';
  String voiceInputLabel({required bool listening}) => isSpanish
      ? listening
            ? 'Detener entrada de voz'
            : 'Iniciar entrada de voz'
      : listening
      ? 'Stop voice input'
      : 'Start voice input';
  String sendLabel({required bool enabled, required bool busy}) => isSpanish
      ? !enabled
            ? 'Consola SI no disponible'
            : busy
            ? 'SI está analizando'
            : 'Enviar consulta SI'
      : !enabled
      ? 'SI Console unavailable'
      : busy
      ? 'SI is analyzing'
      : 'Send SI query';
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
  accountDataLockIssue,
  signOutAndReturnToLogin,
  accountRecoveryInProgress,
  accountRecoveryFailed,
  onboardingPrivacy,
  onboardingWideBody,
  onboardingCompactBody,
  onboardingFinishError,
  onboardingContinueError,
  loginCreateAccountEyebrow,
  loginAccessSystemEyebrow,
  loginCreateWorkspace,
  loginWelcomeBack,
  loginSecureAccessBody,
  loginEmailAddress,
  loginPassword,
  loginShowPassword,
  loginHidePassword,
  loginForgotPassword,
  loginInitializeProfile,
  loginEnterSystem,
  loginContinueDivider,
  loginContinueGoogle,
  loginContinueGithub,
  loginSwitchToLogin,
  loginCreateAccount,
  offlineLocalSemantic,
  offlineSyncSemantic,
  offlineLocalVisible,
  offlineSyncVisible,
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
  aboutTitle,
  aboutSubtitle,
  aboutEyebrow,
  aboutWhatItDoesTitle,
  aboutWhatItDoesBody,
  aboutCoreSurfacesTitle,
  aboutCoreSurfacesBody,
  aboutGuidingPrincipleTitle,
  aboutGuidingPrincipleBody,
  aboutPrivacyAndSupportTitle,
  aboutVoiceFeaturesTitle,
  aboutVoiceFeaturesBody,
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
