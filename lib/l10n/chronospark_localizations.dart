import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:fantastic_guacamole/l10n/creator_copy.dart';
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

  CreatorCopy get creator => CreatorCopy(isSpanish);

  String text(ChronoSparkString key) =>
      (isSpanish ? _es : _en)[key] ?? _en[key] ?? key.name;

  String moreInTimeline(int count) =>
      isSpanish ? '+$count más en la agenda' : '+$count more in schedule';

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
      'createFirstItem' => 'Añade tu primera tarea',
      'scheduleFirstItem' => 'Elige cuándo hacerla',
      'reviewTimeline' => 'Encuentra tu tarea guardada',
      'nexus' => 'Revisa el próximo paso sugerido',
      'smartPlanner' => 'Pide ayuda con un plan',
      'timelineExecution' => 'Registra lo que pasó',
      'siConsole' => 'Pregunta qué falta',
      'trajectoryEngine' => 'Compara otra opción',
      'progression' => 'Revisa tu actividad',
      _ => fallback,
    };
  }

  String guideBody(String id, String fallback) {
    if (!isSpanish) return fallback;
    return switch (id) {
      'createFirstItem' =>
        'Escribe una cosa que necesites hacer. Revísala y confirma para guardarla. Después puedes elegir cuándo hacerla.',
      'scheduleFirstItem' =>
        'Asigna una fecha y una hora a tu tarea para que aparezca en tu plan. Puedes cambiar la hora después.',
      'reviewTimeline' =>
        'Abre la tarea que acabas de guardar en tu agenda. Revisa su fecha y sus detalles.',
      'nexus' =>
        'Revisa la razón y la incertidumbre mostradas junto al bloque antes de actuar.',
      'smartPlanner' =>
        'Haz una pregunta específica sobre la tarea elegida, sus límites o qué debería moverse.',
      'timelineExecution' =>
        'Completa, aplaza o corrige un bloque. Solo el resultado guardado hace avanzar esta guía.',
      'siConsole' =>
        'Pregunta qué evidencia falta y qué dato podría cambiar la recomendación. '
            'Las herramientas gratuitas no usan créditos; las preguntas a la IA en la nube muestran su precio, de hasta 5 créditos, antes de confirmar. Los planes gratuitos elegibles incluyen 20 créditos al mes sin acumulación; consulta tu asignación y fecha de renovación en Ajustes.',
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
      'createFirstItem' => 'Añadir una tarea',
      'scheduleFirstItem' => 'Elegir fecha y hora',
      'reviewTimeline' => 'Abrir Mi plan',
      'nexus' => 'Revisar en Hoy',
      'smartPlanner' => 'Pedir un próximo paso',
      'timelineExecution' => 'Abrir Mi plan',
      'siConsole' => 'Revisar las fuentes',
      'trajectoryEngine' => 'Comparar opciones',
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
    ChronoSparkString.nexus: 'Today',
    ChronoSparkString.smartPlanner: 'Choose a step',
    ChronoSparkString.creator: 'Add something',
    ChronoSparkString.siConsole: 'Chat',
    ChronoSparkString.timeline: 'My plan',
    ChronoSparkString.trajectoryEngine: 'Insights',
    ChronoSparkString.progression: 'Activity',
    ChronoSparkString.preparingSummary: 'Preparing your summary',
    ChronoSparkString.retryNexus: 'Try again',
    ChronoSparkString.whatMattersNext: 'What matters next',
    ChronoSparkString.topRisk: 'What may need attention',
    ChronoSparkString.whatChanged: 'What changed',
    ChronoSparkString.openCreator: 'Add something',
    ChronoSparkString.startInCreator: 'Add your first task',
    ChronoSparkString.todayTimeBlocks: "Today's time blocks",
    ChronoSparkString.openTimeline: 'Open My plan',
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
    ChronoSparkString.livingDecisionSystem: 'A little space to think',
    ChronoSparkString.onboardingWelcomeBody:
        'Put your thoughts into words, review your plans, or choose one small step. You decide what to save.',
    ChronoSparkString.next: 'Next',
    ChronoSparkString.initialize: 'Get started',
    ChronoSparkString.initializeSystem: 'Get started',
    ChronoSparkString.skip: 'Skip',
    ChronoSparkString.nameQuestion: 'What should I call you?',
    ChronoSparkString.name: 'Name',
    ChronoSparkString.nameHint: 'Enter your name…',
    ChronoSparkString.primaryGoal: 'Primary goal',
    ChronoSparkString.goalExecution: 'Getting things done',
    ChronoSparkString.goalGrowth: 'Personal growth',
    ChronoSparkString.goalWellness: 'Wellbeing',
    ChronoSparkString.goalExplore: 'Just exploring',
    ChronoSparkString.personalize: 'Personalize',
    ChronoSparkString.lifeDirection: 'What would help you?',
    ChronoSparkString.calibrateExperience: 'Choose what you want help with.',
    ChronoSparkString.contextualGuidance: 'Help with this page',
    ChronoSparkString.openContextualGuidance: 'Open help for this page',
    ChronoSparkString.collapseGuidance: 'Hide help',
    ChronoSparkString.useThisScreen: 'Continue here',
    ChronoSparkString.notNow: 'Not now',
    ChronoSparkString.cancel: 'Cancel',
    ChronoSparkString.securingAccountData: 'Securing account data',
    ChronoSparkString.accountDataLockIssue:
        'Axiomara could not verify account data safely. Sign out and try again.',
    ChronoSparkString.signOutAndReturnToLogin: 'Sign out and return to login',
    ChronoSparkString.accountRecoveryInProgress:
        'Completing account recovery action',
    ChronoSparkString.accountRecoveryFailed:
        'That recovery action could not be completed. Please try again or sign out.',
    ChronoSparkString.onboardingPrivacy:
        'Your display name stays on this device unless you choose cloud backup. Planning and conversation tools use saved plans. External AI is optional; Settings explains what is shared.',
    ChronoSparkString.onboardingWideBody:
        'Choose a name to use in the app. You can change it later.',
    ChronoSparkString.onboardingCompactBody:
        'What should we call you? You can change this later.',
    ChronoSparkString.onboardingFinishError:
        'Unable to finish onboarding. Please try again.',
    ChronoSparkString.onboardingContinueError:
        'Unable to continue. Please try again.',
    ChronoSparkString.loginCreateAccountEyebrow: 'New here?',
    ChronoSparkString.loginAccessSystemEyebrow: 'Your account',
    ChronoSparkString.loginCreateWorkspace: 'Create your account',
    ChronoSparkString.loginWelcomeBack: 'Welcome back',
    ChronoSparkString.loginSecureAccessBody:
        'Sign in to open your saved plans.',
    ChronoSparkString.loginEmailAddress: 'Email address',
    ChronoSparkString.loginPassword: 'Password',
    ChronoSparkString.loginShowPassword: 'Show password',
    ChronoSparkString.loginHidePassword: 'Hide password',
    ChronoSparkString.loginForgotPassword: 'Forgot Password?',
    ChronoSparkString.loginInitializeProfile: 'Create account',
    ChronoSparkString.loginEnterSystem: 'Sign in',
    ChronoSparkString.loginContinueDivider: 'Or continue with',
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
        'This removes preserved planning records, schedule history, offline actions, notification schedules, profile progress, and local intelligence from this device. It does not delete your cloud account. This cannot be undone.',
    ChronoSparkString.privacyPolicyTitle: 'Privacy Policy',
    ChronoSparkString.privacyPolicyBody:
        'Read how Axiomara uses, stores, and deletes information. Open the current privacy policy below.',
    ChronoSparkString.openHostedPrivacyPolicy: 'Read privacy policy',
    ChronoSparkString.deleteAccountTitle: 'Delete Account',
    ChronoSparkString.deleteAccountBody:
        'Open the account deletion instructions to send a request and review what is deleted or kept.',
    ChronoSparkString.openHostedDeleteAccountPage: 'Open deletion instructions',
    ChronoSparkString.termsTitle: 'Terms of Service',
    ChronoSparkString.termsBody:
        'Read the terms for using Axiomara. The link below opens the current version.',
    ChronoSparkString.openHostedTerms: 'Read terms',
    ChronoSparkString.supportTitle: 'Support',
    ChronoSparkString.supportBody:
        'Get help with the app or your account. Open the support page below.',
    ChronoSparkString.openHostedSupportPage: 'Get help',
    ChronoSparkString.openWebsite: 'Open Website',
    ChronoSparkString.unableToOpenWebsite:
        'Unable to open the website from this device.',
    ChronoSparkString.couldNotLoadContent: 'Could not load content.',
    ChronoSparkString.aboutTitle: 'About Axiomara',
    ChronoSparkString.aboutSubtitle:
        'Space to think and find a manageable next step.',
    ChronoSparkString.aboutEyebrow: 'About this app',
    ChronoSparkString.aboutWhatItDoesTitle: 'What you can do',
    ChronoSparkString.aboutWhatItDoesBody:
        'Write down a thought, save something you need to do, or ask for help with your plans. Suggestions are there to review. You choose what happens next.',
    ChronoSparkString.aboutCoreSurfacesTitle: 'Find your way around',
    ChronoSparkString.aboutCoreSurfacesBody:
        'Start at Today. Add something saves tasks, notes, goals, and habits. Choose a step helps with planning. Chat answers questions about your plans. My plan shows tasks, goals, habits, your schedule, and history. Insights shows patterns, predictions, and future outcomes to review. Activity shows recorded progress.',
    ChronoSparkString.aboutGuidingPrincipleTitle: 'You stay in control',
    ChronoSparkString.aboutGuidingPrincipleBody:
        'Review suggestions before acting. Estimates can be wrong. You can review or correct recorded outcomes.',
    ChronoSparkString.aboutPrivacyAndSupportTitle: 'Privacy and Support',
    ChronoSparkString.aboutVoiceFeaturesTitle: 'Voice Features',
    ChronoSparkString.aboutVoiceFeaturesBody:
        'Use the microphone only when you want to speak instead of type. Voice input starts after you choose it and grant permission.',
    ChronoSparkString.routerErrorTitle: "We couldn't open that link",
    ChronoSparkString.routerErrorBody:
        'This link does not open an available page. Return to Today or open Help to continue.',
    ChronoSparkString.routerErrorReturnNexus: 'Return to Today',
    ChronoSparkString.routerErrorReturnLogin: 'Return to Login',
    ChronoSparkString.routerErrorReturnOnboarding: 'Return to Setup',
    ChronoSparkString.routerErrorReturnSupport: 'Return to Support',
  };

  static const Map<ChronoSparkString, String> _es = <ChronoSparkString, String>{
    ChronoSparkString.nexus: 'Hoy',
    ChronoSparkString.smartPlanner: 'Elegir un paso',
    ChronoSparkString.creator: 'Añadir algo',
    ChronoSparkString.siConsole: 'Chat',
    ChronoSparkString.timeline: 'Mi plan',
    ChronoSparkString.trajectoryEngine: 'Perspectivas',
    ChronoSparkString.progression: 'Actividad',
    ChronoSparkString.preparingSummary: 'Preparando tu resumen',
    ChronoSparkString.retryNexus: 'Reintentar',
    ChronoSparkString.whatMattersNext: 'Lo más importante ahora',
    ChronoSparkString.topRisk: 'Qué puede necesitar atención',
    ChronoSparkString.whatChanged: 'Qué cambió',
    ChronoSparkString.openCreator: 'Añadir algo',
    ChronoSparkString.startInCreator: 'Añade tu primera tarea',
    ChronoSparkString.todayTimeBlocks: 'Bloques de tiempo de hoy',
    ChronoSparkString.openTimeline: 'Abrir Mi plan',
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
    ChronoSparkString.livingDecisionSystem: 'Un espacio para pensar',
    ChronoSparkString.onboardingWelcomeBody:
        'Expresa tus ideas, revisa tus planes o elige un pequeño paso. Tú decides qué guardar.',
    ChronoSparkString.next: 'Siguiente',
    ChronoSparkString.initialize: 'Empezar',
    ChronoSparkString.initializeSystem: 'Empezar',
    ChronoSparkString.skip: 'Omitir',
    ChronoSparkString.nameQuestion: '¿Cómo debo llamarte?',
    ChronoSparkString.name: 'Nombre',
    ChronoSparkString.nameHint: 'Escribe tu nombre…',
    ChronoSparkString.primaryGoal: 'Objetivo principal',
    ChronoSparkString.goalExecution: 'Hacer cosas',
    ChronoSparkString.goalGrowth: 'Crecimiento personal',
    ChronoSparkString.goalWellness: 'Bienestar',
    ChronoSparkString.goalExplore: 'Solo explorando',
    ChronoSparkString.personalize: 'Personaliza',
    ChronoSparkString.lifeDirection: '¿Qué te ayudaría?',
    ChronoSparkString.calibrateExperience: 'Elige en qué quieres ayuda.',
    ChronoSparkString.contextualGuidance: 'Ayuda con esta página',
    ChronoSparkString.openContextualGuidance: 'Abrir ayuda de esta página',
    ChronoSparkString.collapseGuidance: 'Ocultar ayuda',
    ChronoSparkString.useThisScreen: 'Continuar aquí',
    ChronoSparkString.notNow: 'Ahora no',
    ChronoSparkString.cancel: 'Cancelar',
    ChronoSparkString.securingAccountData: 'Protegiendo datos de la cuenta',
    ChronoSparkString.accountDataLockIssue:
        'Axiomara no pudo verificar los datos de la cuenta de forma segura. Cierra sesión e inténtalo de nuevo.',
    ChronoSparkString.signOutAndReturnToLogin:
        'Cerrar sesión y volver al inicio',
    ChronoSparkString.accountRecoveryInProgress:
        'Completando la acción de recuperación de la cuenta',
    ChronoSparkString.accountRecoveryFailed:
        'No se pudo completar esa acción de recuperación. Inténtalo de nuevo o cierra sesión.',
    ChronoSparkString.onboardingPrivacy:
        'Tu nombre se queda en este dispositivo salvo que elijas la copia en la nube. Las herramientas usan tus planes guardados. La IA externa es opcional; Ajustes explica qué se comparte.',
    ChronoSparkString.onboardingWideBody:
        'Elige un nombre para la app. Puedes cambiarlo después.',
    ChronoSparkString.onboardingCompactBody:
        '¿Cómo te llamamos? Puedes cambiarlo después.',
    ChronoSparkString.onboardingFinishError:
        'No se pudo terminar la introducción. Inténtalo de nuevo.',
    ChronoSparkString.onboardingContinueError:
        'No se pudo continuar. Inténtalo de nuevo.',
    ChronoSparkString.loginCreateAccountEyebrow: '¿Primera vez?',
    ChronoSparkString.loginAccessSystemEyebrow: 'Tu cuenta',
    ChronoSparkString.loginCreateWorkspace: 'Crea tu cuenta',
    ChronoSparkString.loginWelcomeBack: 'Te damos la bienvenida',
    ChronoSparkString.loginSecureAccessBody:
        'Inicia sesión para abrir tus planes guardados.',
    ChronoSparkString.loginEmailAddress: 'Correo electrónico',
    ChronoSparkString.loginPassword: 'Contraseña',
    ChronoSparkString.loginShowPassword: 'Mostrar contraseña',
    ChronoSparkString.loginHidePassword: 'Ocultar contraseña',
    ChronoSparkString.loginForgotPassword: '¿Olvidaste la contraseña?',
    ChronoSparkString.loginInitializeProfile: 'Crear cuenta',
    ChronoSparkString.loginEnterSystem: 'Iniciar sesión',
    ChronoSparkString.loginContinueDivider: 'O continúa con',
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
        'Esto elimina de este dispositivo los registros de planificación, historial de agenda, acciones sin conexión, recordatorios, progreso del perfil e inteligencia local conservados. No elimina tu cuenta en la nube. No se puede deshacer.',
    ChronoSparkString.privacyPolicyTitle: 'Política de privacidad',
    ChronoSparkString.privacyPolicyBody:
        'Lee cómo Axiomara usa, guarda y elimina información. Abre la política de privacidad actual.',
    ChronoSparkString.openHostedPrivacyPolicy: 'Leer política de privacidad',
    ChronoSparkString.deleteAccountTitle: 'Eliminar cuenta',
    ChronoSparkString.deleteAccountBody:
        'Abre las instrucciones de eliminación de cuenta para enviar una solicitud y revisar qué se elimina o conserva.',
    ChronoSparkString.openHostedDeleteAccountPage:
        'Abrir instrucciones de eliminación',
    ChronoSparkString.termsTitle: 'Términos de servicio',
    ChronoSparkString.termsBody:
        'Lee los términos de uso de Axiomara. El enlace abre la versión actual.',
    ChronoSparkString.openHostedTerms: 'Leer términos',
    ChronoSparkString.supportTitle: 'Soporte',
    ChronoSparkString.supportBody:
        'Obtén ayuda con la app o tu cuenta. Abre la página de soporte.',
    ChronoSparkString.openHostedSupportPage: 'Obtener ayuda',
    ChronoSparkString.openWebsite: 'Abrir sitio web',
    ChronoSparkString.unableToOpenWebsite:
        'No se pudo abrir el sitio web desde este dispositivo.',
    ChronoSparkString.couldNotLoadContent: 'No se pudo cargar el contenido.',
    ChronoSparkString.aboutTitle: 'Acerca de Axiomara',
    ChronoSparkString.aboutSubtitle:
        'Espacio para pensar y encontrar un próximo paso manejable.',
    ChronoSparkString.aboutEyebrow: 'Sobre esta app',
    ChronoSparkString.aboutWhatItDoesTitle: 'Qué puedes hacer',
    ChronoSparkString.aboutWhatItDoesBody:
        'Escribe una idea, guarda algo que necesites hacer o pide ayuda con tus planes. Puedes revisar las sugerencias. Tú decides qué hacer después.',
    ChronoSparkString.aboutCoreSurfacesTitle: 'Cómo moverte por la app',
    ChronoSparkString.aboutCoreSurfacesBody:
        'Empieza en Hoy. Añadir algo guarda tareas, notas, metas y hábitos. Elegir un paso ayuda a planificar. Chat responde preguntas sobre tus planes. Mi plan muestra tareas, metas, hábitos, tu agenda e historial. Perspectivas muestra patrones, predicciones y resultados futuros para revisar. Actividad muestra avances registrados.',
    ChronoSparkString.aboutGuidingPrincipleTitle: 'Tú decides',
    ChronoSparkString.aboutGuidingPrincipleBody:
        'Revisa las sugerencias antes de actuar. Las estimaciones pueden equivocarse. Puedes revisar o corregir los resultados registrados.',
    ChronoSparkString.aboutPrivacyAndSupportTitle: 'Privacidad y soporte',
    ChronoSparkString.aboutVoiceFeaturesTitle: 'Funciones de voz',
    ChronoSparkString.aboutVoiceFeaturesBody:
        'Usa el micrófono cuando quieras hablar en vez de escribir. La entrada de voz empieza cuando la eliges y das permiso.',
    ChronoSparkString.routerErrorTitle: 'No pudimos abrir ese enlace',
    ChronoSparkString.routerErrorBody:
        'Este enlace no abre una página disponible. Vuelve a Hoy o abre Ayuda para continuar.',
    ChronoSparkString.routerErrorReturnNexus: 'Volver a Hoy',
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
      ? 'No se pudo verificar el acceso a Elegir un paso. No se enviará ninguna solicitud de orientación.'
      : 'Choose a step access could not be verified. No guidance request will be sent.';
  String get checkingAccess => isSpanish
      ? 'Verificando el acceso a Elegir un paso...'
      : 'Checking Choose a step access...';
  String get accessUnavailable => isSpanish
      ? 'Elegir un paso no está habilitado para esta cuenta. No se enviará ninguna solicitud de orientación.'
      : 'Choose a step is not enabled for this account. No guidance request will be sent.';
  String get onDeviceReady => isSpanish
      ? 'Elegir un paso está listo en el dispositivo.'
      : 'On-device Choose a step is ready.';
  String get retryAccessCheck =>
      isSpanish ? 'Reintentar verificación de acceso' : 'Retry access check';
  String get guidanceUnavailable => isSpanish
      ? 'Elegir un paso aún no está habilitado para esta cuenta. Tu registro no se guardó ni cambió.'
      : 'Choose a step is not enabled for this account yet. Your check-in was not saved or changed.';
  String get guidanceRetry => isSpanish
      ? 'No se pudo generar la orientación. Tu registro sigue aquí. Pulsa Obtener una sugerencia para reintentar.'
      : 'Guidance could not be generated. Your check-in is still here. Tap Get a suggestion to retry.';
  String get personContextChanged => isSpanish
      ? 'La información personal que compartiste cambió, por lo que se borró la orientación anterior. Pulsa Obtener una sugerencia para revisar un plan actual.'
      : 'Your shared personal information changed, so the previous guidance was cleared. Tap Get a suggestion to review a current plan.';
  String get guidanceTimeout => isSpanish
      ? 'La solicitud de orientación agotó el tiempo. Pulsa Obtener una sugerencia otra vez o acorta el texto para recibir una respuesta más rápida.'
      : 'Guidance request timed out. Tap Get a suggestion again or shorten your input for a faster response.';
  String get followUpTimeout => isSpanish
      ? 'El seguimiento agotó el tiempo. Tu mensaje sigue aquí; puedes editarlo o pulsar Reintentar seguimiento.'
      : 'Follow-up timed out. Your message is still here; edit it or tap Retry follow-up.';
  String get followUpTransmitFailed => isSpanish
      ? 'No se pudo enviar el seguimiento. Tu mensaje sigue aquí. Pulsa Reintentar seguimiento.'
      : 'Follow-up could not be sent. Your message is still here. Tap Retry follow-up.';
  String get plannerPanelTitle => isSpanish ? 'TU PLAN' : 'YOUR PLAN';
  String get plannerLocalSource => isSpanish
      ? 'Planificación local a partir de tu contexto'
      : 'Local planning from your context';
  String get plannerExternalSource => isSpanish
      ? 'Orientación generada con IA externa'
      : 'Guidance generated with external AI';
  String get yourNextStep => isSpanish ? 'SIGUIENTE PASO' : 'NEXT STEP';
  String get oneQuestion => isSpanish ? 'PARA ACLARARLO' : 'ONE QUESTION';
  String get whyThis => isSpanish ? 'Por qué este plan' : 'Why this';
  String get mattersMost =>
      isSpanish ? 'LO MÁS IMPORTANTE' : 'WHAT MATTERS MOST';
  String get evidence => isSpanish ? 'Evidencia' : 'Evidence';
  String get useThisPlan => isSpanish ? 'Usar este plan' : 'Use this plan';
  String get makeSmaller => isSpanish ? 'Hacer más pequeño' : 'Make smaller';
  String get differentApproach =>
      isSpanish ? 'Otro enfoque' : 'Different approach';
  String get rememberPreference =>
      isSpanish ? 'Recordar una preferencia' : 'Remember a preference';
  String get alternativeOptions =>
      isSpanish ? 'Comparar tiempo y esfuerzo' : 'Compare time and effort';
  String get fullResponse =>
      isSpanish ? 'Ver respuesta completa' : 'View full response';
  String tradeoff(String value) =>
      isSpanish ? 'Lo que implica: $value' : 'Tradeoff: $value';
  String optionKind(String kind) => switch (kind) {
    'minimum' => isSpanish ? 'MÍNIMO' : 'MINIMUM',
    'stretch' => isSpanish ? 'MÁS ESFUERZO' : 'STRETCH',
    _ => isSpanish ? 'MÁS ADECUADO' : 'BEST-FIT',
  };
  String optionSemantic(String label) =>
      isSpanish ? 'Plan $label' : '$label plan';
  String get followUpQuestion =>
      isSpanish ? 'Pregunta de seguimiento' : 'Follow-up question';
  String get followUpHint => isSpanish
      ? '¿Qué necesitas cambiar o aclarar?'
      : 'What needs changing or clarifying?';
  String get retryFollowUp =>
      isSpanish ? 'Reintentar seguimiento' : 'Retry follow-up';
  String followUpFailed(String error) =>
      isSpanish ? 'Falló el seguimiento. $error' : 'Follow-up failed. $error';
  String sendMessage({required bool sending}) => isSpanish
      ? sending
            ? 'Enviando mensaje'
            : 'Enviar mensaje'
      : sending
      ? 'Sending message'
      : 'Send message';
  String get differentApproachQuestion => isSpanish
      ? '¿Qué dificulta este enfoque: los pasos, el horario, las interrupciones u otra cosa?'
      : 'What makes this approach difficult: the steps, timing, interruptions, or something else?';
  String get minimumReachedStatus => isSpanish
      ? 'El plan ya está en su paso más pequeño. Puedes pedir otro enfoque.'
      : 'The plan is already at its smallest step. You can ask for a different approach.';
  String get externalExplanationTitle =>
      isSpanish ? 'Explicación opcional con IA' : 'Optional AI explanation';
  String get externalExplanationBody => isSpanish
      ? 'La IA puede explicar el plan. No puede cambiarlo ni guardarlo.'
      : 'AI can explain the plan. It cannot change or save it.';
  String get explanationRequesting =>
      isSpanish ? 'SOLICITANDO...' : 'REQUESTING...';
  String get explanationRetry =>
      isSpanish ? 'Reintentar la misma solicitud' : 'Retry same request';
  String get explainPlan =>
      isSpanish ? 'Explicar este plan' : 'Explain this plan';
  String get anotherExplanation =>
      isSpanish ? 'Solicitar otra explicación' : 'Request another explanation';
  String get explanationReady => isSpanish
      ? 'La explicación opcional con IA externa está lista'
      : 'Optional external AI explanation ready';
  String explanationReceipt(int credits) => isSpanish
      ? '$credits créditos de IA · sin cambios en el plan'
      : '$credits AI credits · no plan changes';
  String get currentEnergy => isSpanish ? 'Energía actual' : 'Current energy';
  String get notSet => isSpanish ? 'Sin indicar' : 'Not set';
  String energyPercent(int value) =>
      isSpanish ? '$value por ciento' : '$value percent';
  String emotionName(String name) => !isSpanish
      ? name
      : switch (name) {
          'neutral' => 'neutral',
          'positive' => 'positivo',
          'negative' => 'negativo',
          'energized' => 'con energía',
          'fatigued' => 'con cansancio',
          'engaged' => 'con interés',
          'scattered' => 'disperso',
          'anxious' => 'con ansiedad',
          'calm' => 'en calma',
          _ => name,
        };
  String emotionalSelection(String? name) => isSpanish
      ? name == null
            ? 'Estado emocional. Sin indicar.'
            : 'Estado emocional. ${emotionName(name)} seleccionado.'
      : name == null
      ? 'Emotional state. Not set.'
      : 'Emotional state. $name selected.';
  String selectEmotion(String name) => isSpanish
      ? 'Seleccionar estado emocional ${emotionName(name)}'
      : 'Select $name emotional state';
  String get planningSafetyLabel => isSpanish
      ? 'Información de seguridad de la orientación de planificación'
      : 'Planning guidance safety information';
  String get planningSafetyBody => isSpanish
      ? 'Esto ayuda a planificar, no sustituye la atención médica, nutricional, de ejercicio o de salud mental. Si los síntomas son urgentes o empeoran, contacta con un profesional cualificado o el servicio de emergencias local.'
      : 'This supports planning, not medical, nutrition, exercise, or mental-health care. For urgent or worsening symptoms, contact a qualified professional or local emergency service.';
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
      ? 'Así es más fácil empezar. El resto puede esperar.'
      : 'This makes it easier to start. The rest can wait.';
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
      ? 'Aquí tienes otra forma de empezar. No se guardó nada.'
      : 'Here is another way to start. Nothing has been saved.';
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
      ? 'Resumen de voz de Elegir un paso'
      : 'Choose a step voice summary';
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
      ? 'Abrir la guía de accesibilidad de Elegir un paso y leerla en voz alta'
      : 'Open Choose a step accessibility guide and read it aloud';
  String get accessibilityTitle =>
      isSpanish ? 'Guía de accesibilidad' : 'Accessibility Guide';
  String get accessibilityBody => isSpanish
      ? 'Elige cómo leer o escuchar las sugerencias.'
      : 'Choose how to read or listen to suggestions.';
  String get accessibilityButton =>
      isSpanish ? 'Ayuda de lectura y voz' : 'Reading and voice help';
  String get accessibilitySurface =>
      isSpanish ? 'Elegir un paso' : 'Choose a step';
  List<String> get accessibilityControls => isSpanish
      ? const <String>[
          'Ajusta el control de energía para definir la intensidad',
          'Selecciona el estado emocional para adaptar la orientación',
          'Usa Obtener una sugerencia para generar una respuesta de planificación',
          'Usa el botón de voz para leer en voz alta la orientación más reciente',
          'Usa el botón de resumen para escuchar un repaso breve',
          'Usa el botón del micrófono para las interacciones de voz',
        ]
      : const <String>[
          'Adjust energy slider to set intensity',
          'Select emotional state to tune guidance',
          'Use Get a suggestion to generate a planning response',
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
  String get optionalPlanningInputs => isSpanish
      ? 'La energía y el contexto son opcionales. Si los dejas en blanco, la orientación usará el contexto guardado disponible.'
      : 'Energy and planning context are optional. Leave them blank to use the available saved context.';
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
      ? 'Tus palabras y tu registro son temporales. Este dispositivo puede guardar qué orientación se mostró o usó. Solo se guardan otros detalles si eliges recordar una preferencia.'
      : 'Your words and check-in are temporary. This device may keep a record of the guidance shown or used. Other details are saved only if you choose to remember a preference.';
  String get checkingButton =>
      isSpanish ? 'VERIFICANDO ACCESO...' : 'CHECKING ACCESS...';
  String get unavailableButton =>
      isSpanish ? 'ELEGIR UN PASO NO DISPONIBLE' : 'CHOOSE A STEP UNAVAILABLE';
  String get thinkingButton => isSpanish ? 'PENSANDO...' : 'THINKING...';
  String guidanceButton({required bool refresh}) => isSpanish
      ? refresh
            ? 'Actualizar sugerencia'
            : 'Obtener una sugerencia'
      : refresh
      ? 'Update suggestion'
      : 'Get a suggestion';
  String get guidanceReady => isSpanish
      ? 'Orientación de planificación lista'
      : 'Planning guidance ready';
  String get subtitle => isSpanish
      ? 'Describe qué necesitas hacer. Recibe un próximo paso manejable para revisar.'
      : 'Describe what you need to do. Get a manageable next step to review.';
  String get eyebrow =>
      isSpanish ? 'Ayuda con tu próximo paso' : 'Help with your next step';
}

@immutable
final class SIRoutineCopy {
  const SIRoutineCopy(this.isSpanish);

  final bool isSpanish;

  String get accessCheckFailed => isSpanish
      ? 'No se pudo verificar el acceso a Chat. No se envió ninguna consulta.'
      : 'Chat access could not be verified. No query was sent.';
  String get checkingAccess =>
      isSpanish ? 'Verificando el acceso a Chat...' : 'Checking Chat access...';
  String get accessUnavailable => isSpanish
      ? 'Chat no está habilitado para esta cuenta. No se envió ninguna consulta.'
      : 'Chat is not enabled for this account. No query was sent.';
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
      ? 'Aún no hay información de planes guardada. La herramienta explicará qué no puede responder. $personBoundary'
      : 'No saved planning information yet. This tool will explain what it cannot answer. $personBoundary';
  String evidenceReady({
    required int tasks,
    required int goals,
    required int milestones,
    required int timeline,
    required String personBoundary,
  }) => isSpanish
      ? 'Información guardada: $tasks tareas · $goals metas · $milestones hitos · $timeline entradas de agenda. $personBoundary'
      : 'Saved information: $tasks tasks · $goals goals · $milestones milestones · $timeline schedule entries. $personBoundary';
  String get personContextUnavailable => isSpanish
      ? 'Tus detalles compartidos no están disponibles. No se supusieron datos personales.'
      : 'Your shared details are unavailable. No personal details were guessed.';
  String get personContextNotRelevant => isSpanish
      ? 'Ninguno de tus detalles compartidos se aplica a esta pregunta.'
      : 'None of your shared details apply to this question.';
  String personContextEvidence(int count) => isSpanish
      ? 'Información personal que compartiste: $count ${count == 1 ? 'elemento declarado por el usuario disponible' : 'elementos declarados por el usuario disponibles'}. Cada respuesta cita solo el contexto pertinente a esa pregunta; no se verifica de forma independiente.'
      : 'Personal information you shared: $count user-reported ${count == 1 ? 'item available' : 'items available'}. Each answer cites only context relevant to that question; it is not independently verified.';
  String get retryEvidence => isSpanish
      ? 'Reintentar carga de información guardada'
      : 'Try loading saved information again';
  String get unavailableSavedWork => isSpanish
      ? 'Esta cuenta no tiene acceso actualmente. Tu trabajo guardado no cambió.'
      : 'This account does not currently have access. Your saved work is unchanged.';
  String get welcomeNoEvidence => isSpanish
      ? 'Todavía no hay planes guardados para revisar. La herramienta explicará qué falta.'
      : 'There are no saved plans to review yet. The tool will explain what is missing.';
  String get welcomeReady => isSpanish
      ? 'Pregunta sobre tareas, metas, hitos o tu agenda. Esta herramienta local puede leerlos, pero no cambiarlos.'
      : 'Ask about saved tasks, goals, milestones, or your schedule. This local tool can read them, but cannot change them.';
  String get localProcessingBoundary => isSpanish
      ? 'Este modo usa reglas locales: no envía preguntas a una IA externa ni gasta créditos de IA. Las herramientas de voz requieren un consentimiento aparte.'
      : 'This mode uses local rules: it does not send questions to external AI or spend AI credits. Voice tools require separate consent.';
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
      ? 'Pregunta sobre tus planes guardados'
      : 'Ask about your saved plans';
  String get backToNexus => isSpanish ? 'Volver a Hoy' : 'Back to Today';
  String get title => 'Chat';
  String get subtitle => isSpanish
      ? 'Pregunta sobre tus planes guardados. Revisa la respuesta antes de decidir.'
      : 'Ask a question about your saved plans. Review the answer before deciding.';
  String get eyebrow => isSpanish
      ? 'Ayuda para entender tus planes'
      : 'Help understanding your plans';
  String get readSummary => isSpanish ? 'Leer resumen' : 'Read summary';
  String get accessibilityGuide =>
      isSpanish ? 'Guía de accesibilidad' : 'Accessibility guide';
  String get advanced => isSpanish ? 'Avanzado' : 'Advanced';
  String get advancedSubtitle => isSpanish
      ? 'Elige qué información guardada usar'
      : 'Choose which saved information to use';
  String get queryBuilder =>
      isSpanish ? 'Opciones de la pregunta' : 'Question options';
  String get entityFilter => isSpanish
      ? 'Buscar un título guardado (opcional)'
      : 'Find a saved title (optional)';
  String get scenarioAssumption => isSpanish
      ? '¿Qué podría cambiar? (opcional)'
      : 'What might change? (optional)';
  String get choosePowerAlias =>
      isSpanish ? 'Elegir un atajo' : 'Choose a shortcut';
  String get powerAliases => isSpanish ? 'Atajos' : 'Shortcuts';
  String get queryLabel => isSpanish ? 'Tu pregunta' : 'Your question';
  String get queryHint => isSpanish
      ? '¿Qué te gustaría entender sobre tus planes?'
      : 'What would you like to understand about your plans?';
  String get yourQuery => isSpanish ? 'Tu consulta' : 'Your query';
  String get siResponse => isSpanish ? 'Respuesta' : 'Answer';
  String whyThisAppears(String rationale) => isSpanish
      ? 'Por qué aparece: $rationale'
      : 'Why this appears: $rationale';
  String get directAnswer => isSpanish ? 'RESPUESTA DIRECTA' : 'DIRECT ANSWER';
  String get recommendation => isSpanish ? 'RECOMENDACIÓN' : 'RECOMMENDATION';
  String get responseAdvancedSubtitle => isSpanish
      ? 'Ve las fuentes, cálculos y dudas'
      : 'See sources, calculations, and what is uncertain';
  String get observedFacts =>
      isSpanish ? 'HECHOS OBSERVADOS' : 'OBSERVED FACTS';
  String get userReportedContext =>
      isSpanish ? 'CONTEXTO DECLARADO POR EL USUARIO' : 'USER-REPORTED CONTEXT';
  String get deterministicCalculations => isSpanish
      ? 'Calculado con tus registros'
      : 'Calculated from your records';
  String get inferences =>
      isSpanish ? 'Posibles explicaciones' : 'Possible explanations';
  String get missingOrConflicting => isSpanish
      ? 'INFORMACIÓN FALTANTE O CONTRADICTORIA'
      : 'MISSING OR CONFLICTING INFORMATION';
  String get scenarios => isSpanish ? 'ESCENARIOS' : 'SCENARIOS';
  String get scenarioAssumptions =>
      isSpanish ? 'SUPUESTOS DEL ESCENARIO' : 'SCENARIO ASSUMPTIONS';
  String get confidenceAnatomy =>
      isSpanish ? '¿Qué certeza tiene?' : 'How certain is this?';
  String get evidenceLinks => isSpanish ? 'Fuentes usadas' : 'Sources used';
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
          'Usa Atrás para volver a Hoy.',
        ]
      : const <String>[
          'Type a prompt in the input field, then send.',
          'Use Summary to hear recent assistant responses.',
          'Use Speak on assistant bubbles to read aloud.',
          'Use Back to return to Today.',
        ];
  List<String> get accessibilitySteps => isSpanish
      ? const <String>[
          '1. Escribe una indicación y luego envíala.',
          '2. Resumen lee respuestas recientes del asistente.',
          '3. Escuchar lee una respuesta en voz alta.',
          '4. Atrás vuelve a Hoy.',
        ]
      : const <String>[
          '1. Type a prompt, then send.',
          '2. Summary reads recent assistant responses.',
          '3. Speak reads one response aloud.',
          '4. Back returns to Today.',
        ];
  String get accessibilitySurface => 'Chat';
  String get personContextChanged => isSpanish
      ? 'Los detalles que compartiste cambiaron y se borraron las respuestas locales anteriores. Pregunta de nuevo para usar la información actualizada.'
      : 'The details you shared changed, so previous local answers were cleared. Ask again to use the updated information.';
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
      'timeline' => 'Agenda',
      'trajectory' => 'Perspectivas',
      'progression' => 'Actividad',
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
          final String aliases = item.advertisedAliases
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
      ? 'Cómo usar esta herramienta:\n- Usa Añadir algo para guardar una tarea.\n- Esta herramienta local puede leer tus planes, pero no cambiarlos.\n- Escribe una pregunta, usa las opciones de arriba o elige un atajo.\n\nPreguntas para probar:\n- "¿Qué necesita atención?"\n- "¿Por qué está en riesgo este objetivo?"\n- "Compara mis dos objetivos más próximos."\n- "¿Qué pasa si aplazo esta tarea?"\n- "¿Qué compromisos entran en conflicto?"\n- "¿Qué cambiaría tu recomendación?"'
      : 'How to use this tool:\n- Use Add something to save a task.\n- This local tool can read your plans but cannot change them.\n- Type a question, use the options above, or choose a shortcut.\n\nQuestions to try:\n- "What needs attention?"\n- "Why is this goal at risk?"\n- "Compare my two nearest goals."\n- "What happens if I defer this task?"\n- "Which commitments conflict?"\n- "What would change your recommendation?"';
  String statusLoading() => isSpanish
      ? 'ESTADO DE SI\n\nLas fuentes de datos locales todavía se están cargando. Reintenta /status en un momento.\nNo se cambió información guardada.'
      : 'SI STATUS\n\nLocal data sources are still loading. Retry /status in a second.\nNo saved information was changed.';
  String statusReady({
    required int tasks,
    required int goals,
    required int milestones,
    required int timeline,
    required int unavailableSources,
    required String revision,
    required String aliases,
  }) => isSpanish
      ? 'ESTADO DE SI\n\nChat de solo lectura:\n- tareas: $tasks\n- objetivos: $goals\n- hitos: $milestones\n- agenda: $timeline\n- fuentes no disponibles: $unavailableSources\n- revisión: $revision\n\nAtajos de fuentes disponibles: $aliases.'
      : 'SI STATUS\n\nRead-only Chat:\n- tasks: $tasks\n- goals: $goals\n- milestones: $milestones\n- schedule: $timeline\n- unavailable sources: $unavailableSources\n- revision: $revision\n\nAvailable source shortcuts: $aliases.';
  String get responseValidationFailed => isSpanish
      ? 'No se pudo comprobar esta respuesta. Reintenta o incluye más tareas, metas, hitos o entradas de agenda. No se cambió nada.'
      : 'We could not check this answer. Try again or include more saved tasks, goals, milestones, or schedule entries. Nothing was changed.';
  String get voiceSummaryTitle =>
      isSpanish ? 'Resumen de voz de Chat' : 'Chat voice summary';
  String voiceInputLabel({required bool listening}) => isSpanish
      ? listening
            ? 'Detener entrada de voz'
            : 'Iniciar entrada de voz'
      : listening
      ? 'Stop voice input'
      : 'Start voice input';
  String sendLabel({required bool enabled, required bool busy}) => isSpanish
      ? !enabled
            ? 'Chat no disponible'
            : busy
            ? 'SI está analizando'
            : 'Enviar consulta SI'
      : !enabled
      ? 'Chat unavailable'
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
