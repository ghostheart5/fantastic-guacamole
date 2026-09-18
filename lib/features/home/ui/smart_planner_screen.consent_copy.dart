part of 'smart_planner_screen.dart';

@immutable
final class _SmartPlannerConsentCopy {
  const _SmartPlannerConsentCopy({required this.isSpanish});

  factory _SmartPlannerConsentCopy.of(BuildContext context) =>
      _SmartPlannerConsentCopy(
        isSpanish: ChronoSparkLocalizations.of(context).isSpanish,
      );

  final bool isSpanish;

  String get priorityTitle => isSpanish
      ? '¿Guardar tu prioridad actual?'
      : 'Save your current priority?';
  String get priorityIntroduction => isSpanish
      ? 'Opcional. Escribe una sola prioridad actual con tus propias palabras. No añadas un perfil de personalidad, una historia de vida ni una etiqueta emocional.'
      : 'Optional. Enter one exact current priority in your own words. Do not add a personality profile, life history, or emotional label.';
  String get priorityLabel =>
      isSpanish ? 'Prioridad actual exacta' : 'Exact current priority';
  String get priorityHint => isSpanish
      ? 'Ejemplo: La preparación para la prueba cerrada es lo primero.'
      : 'Example: Closed-test readiness comes first.';
  String get priorityDisclosure => isSpanish
      ? 'Propósito: apoyo para decisiones\nAlcance: solo Planificador Inteligente\nCaducidad: se elimina automáticamente después de 30 días\nEfecto: puede resolver un empate ajustado mientras esta prioridad esté activa; no se convierte en un dato de identidad.'
      : 'Purpose: decision support\nSurface scope: Smart Planner only\nExpiry: automatically deleted after 30 days\nEffect: may break a close ranking tie while this priority is active; it does not become an identity fact.';
  String get priorityConsent => isSpanish
      ? 'Doy mi consentimiento para guardar solo este texto exacto con el propósito, alcance y caducidad indicados arriba.'
      : 'I consent to saving only this exact text for the purpose, scope, and expiry above.';
  String get useOnlyThisTime =>
      isSpanish ? 'Usar solo esta vez' : 'Use only this time';
  String get saveWithConsent =>
      isSpanish ? 'Guardar con consentimiento' : 'Save with consent';
  String get prioritySaved => isSpanish
      ? 'Contexto opcional guardado con consentimiento · solo Planificador Inteligente · caduca en 30 días · revísalo o elimínalo en Ajustes de contexto.'
      : 'Optional context saved with consent · Smart Planner only · expires in 30 days · review or delete in Context settings.';
  String get preferenceTitle => isSpanish
      ? '¿Recordar una preferencia del Planificador Inteligente?'
      : 'Remember a Smart Planner preference?';
  String get preferenceIntroduction => isSpanish
      ? 'Usar solo esta vez es la opción predeterminada. Escribe únicamente la preferencia exacta sobre el estilo de planificación que quieras guardar; no se copiarán tu registro, emoción ni respuesta.'
      : 'Use only this time is the default. Enter only the exact planning-style preference you want stored; your check-in, emotion, and response are not copied.';
  String get preferenceLabel =>
      isSpanish ? 'Preferencia exacta' : 'Exact preference';
  String get preferenceHint => isSpanish
      ? 'Ejemplo: Prefiere un siguiente paso pequeño antes de ideas opcionales más ambiciosas.'
      : 'Example: Prefer one small next step before optional stretch ideas.';
  String get deleteAfter => isSpanish
      ? 'Eliminar automáticamente después de'
      : 'Automatically delete after';
  String retentionLabel(int days) {
    if (!isSpanish) return days == 365 ? '1 year' : '$days days';
    return days == 365 ? '1 año' : '$days días';
  }

  String receiptPreview(int days) => isSpanish
      ? 'Vista previa del recibo\nMotivo: guardar esta preferencia para tu revisión y uso futuro opcional\nLímite de recuperación: solo guía consentida del Planificador Inteligente\nOrigen: solo Planificador Inteligente\nCaducidad: $days días\nControles: ver, corregir, exportar y eliminar en Ajustes'
      : 'Receipt preview\nWhy: save this preference for your review and future opt-in use\nRecall boundary: consented Smart Planner guidance only\nSource: Smart Planner only\nExpiry: $days days\nControls: view, correct, export, delete in Settings';
  String get preferenceConsent => isSpanish
      ? 'Doy mi consentimiento explícito para guardar esta preferencia exacta.'
      : 'I explicitly consent to storing this exact preference.';
  String get rememberPreference =>
      isSpanish ? 'Recordar preferencia' : 'Remember preference';
  String get usedOnce => isSpanish
      ? 'Se usó solo para este registro. No se guardó memoria duradera.'
      : 'Used only for this check-in. No durable memory was saved.';
  String preferenceSaved(String expiry) => isSpanish
      ? 'Preferencia guardada con consentimiento. Su uso queda limitado a la guía del Planificador Inteligente · caduca $expiry · adminístrala en Ajustes.'
      : 'Preference saved with consent. Recall stays limited to Smart Planner guidance · expires $expiry · manage in Settings.';
  String get contextSaveFailed => isSpanish
      ? 'No se pudo guardar el contexto opcional. Tu texto no se añadió. Inténtalo de nuevo.'
      : 'Optional context could not be saved. Your text was not added. Retry.';
  String get preferenceSaveFailed => isSpanish
      ? 'No se pudo guardar la preferencia. No se creó memoria duradera. Inténtalo de nuevo.'
      : 'The preference could not be saved. No durable memory was created. Retry.';
}

extension _PlannerExplanationQuoteConsent on _SmartPlannerScreenState {
  Future<bool> _confirmPlannerExplanationQuote(
    PlannerExplanationQuote quote,
  ) async {
    final bool? approved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(
          journeyText(
            context,
            'External AI explanation',
            'Explicación de IA externa',
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                journeyText(
                  context,
                  'Your deterministic Planner V2 result remains the authority. This optional service can explain the visible plan but cannot change, save, schedule, or create anything.',
                  'El resultado determinista del Planificador V2 sigue siendo la referencia. Este servicio opcional puede explicar el plan visible, pero no puede cambiar, guardar, programar ni crear nada.',
                ),
              ),
              const SizedBox(height: 14),
              Text(
                journeyText(
                  context,
                  'Provider: ${quote.provider}',
                  'Proveedor: ${quote.provider}',
                ),
              ),
              Text(
                journeyText(
                  context,
                  'Model: ${quote.modelLabel}',
                  'Modelo: ${quote.modelLabel}',
                ),
              ),
              Text(
                journeyText(
                  context,
                  'Expected cost: ${quote.expectedCredits} AI credits',
                  'Costo previsto: ${quote.expectedCredits} créditos de IA',
                ),
              ),
              Text(
                journeyText(
                  context,
                  'First-party replay window: ${quote.replayWindowSeconds} seconds',
                  'Tiempo para repetir desde Axiomara: ${quote.replayWindowSeconds} segundos',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                journeyText(
                  context,
                  'Data sent after confirmation:',
                  'Datos enviados después de confirmar:',
                ),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              ...quote.transmittedDataCategories.map(
                (String category) => Text('• $category'),
              ),
              const SizedBox(height: 12),
              Text(
                journeyText(
                  context,
                  'The quote used this minimized packet only with Axiomara\'s first-party function. Nothing has been sent to Anthropic yet.',
                  'La cotización usó este paquete mínimo solo con la función propia de Axiomara. Aún no se ha enviado nada a Anthropic.',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                journeyText(
                  context,
                  'Axiomara keeps response content only for the short replay window, then retains billing metadata. This quote is available only after the first-party service reports the provider-retention and qualified safety-review gates approved. Independent release evidence is still required before this feature can be enabled.',
                  'Axiomara conserva la respuesta solo durante el breve periodo para repetirla y luego mantiene los datos de facturación. Esta cotización aparece solo cuando el servicio propio confirma la retención del proveedor y la revisión de seguridad aprobada. Antes de habilitar la función aún se necesita evidencia independiente del lanzamiento.',
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            key: const Key('planner-explanation-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(journeyText(context, 'Cancel', 'Cancelar')),
          ),
          FilledButton(
            key: const Key('planner-explanation-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              journeyText(
                context,
                'Send and spend ${quote.expectedCredits}',
                'Enviar y gastar ${quote.expectedCredits}',
              ),
            ),
          ),
        ],
      ),
    );
    return approved ?? false;
  }
}
