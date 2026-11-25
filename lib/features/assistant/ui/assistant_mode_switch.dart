import 'dart:async';

import 'package:fantastic_guacamole/domain/entities/assistant_conversation.dart';
import 'package:fantastic_guacamole/features/assistant/ui/ai_chat_consent.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/personalization_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The one two-way control at the top of Chat and Choose a step: the free
/// on-device assistant or AI chat with its price. Both screens show it, so the
/// person can always move both ways. It only reports the choice; the screen
/// that owns the choice also carries the typed text across.
///
/// Choosing AI chat before it is allowed opens the same one-step consent sheet
/// as everywhere else. Nothing is sent and nothing is charged by choosing.
class AssistantModeSwitch extends ConsumerStatefulWidget {
  const AssistantModeSwitch({
    super.key,
    required this.aiSelected,
    required this.enabled,
    required this.onChooseOnDevice,
    required this.onChooseAi,
  });

  final bool aiSelected;
  final bool enabled;
  final VoidCallback onChooseOnDevice;
  final VoidCallback onChooseAi;

  @override
  ConsumerState<AssistantModeSwitch> createState() =>
      _AssistantModeSwitchState();
}

class _AssistantModeSwitchState extends ConsumerState<AssistantModeSwitch> {
  BuildContext? _sheet;
  Route<dynamic>? _sheetRoute;
  bool _choosing = false;

  @override
  void dispose() {
    final route = _sheetRoute;
    // An account change can remove this control while its sheet is open.
    if (route != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final navigator = route.navigator;
        if (route.isActive && navigator != null && navigator.mounted) {
          navigator.removeRoute(route, false);
        }
      });
    }
    super.dispose();
  }

  Future<void> _chooseAi() async {
    if (_choosing) return;
    if (ref.read(personalizationProfileProvider).externalAiAllowed) {
      widget.onChooseAi();
      return;
    }
    final scope = ref.read(accountStorageScopeProvider).v2Namespace;
    final authGeneration = ref.read(authSessionBoundaryProvider).generation;
    if (scope == null) return;
    _choosing = true;
    try {
      final allowed = await showAiChatConsentSheet(
        context,
        onRoute: (sheet) {
          _sheet = sheet;
          _sheetRoute = sheet == null ? null : ModalRoute.of(sheet);
        },
      );
      // The choice belongs to the account that saw the sheet.
      if (!allowed || !mounted || _accountChanged(scope, authGeneration)) {
        return;
      }
      // Waits for the stored profile, so the person's other choices are kept.
      await ref
          .read(personalizationProfileProvider.notifier)
          .setExternalAiAllowed(true);
      if (!mounted || _accountChanged(scope, authGeneration)) return;
      widget.onChooseAi();
    } on Object {
      if (!mounted) return;
      final spanish = ChronoSparkLocalizations.of(context).isSpanish;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            spanish
                ? 'No se pudo activar el chat con IA. Inténtalo de nuevo.'
                : 'AI chat could not be turned on. Please try again.',
          ),
        ),
      );
    } finally {
      _choosing = false;
    }
  }

  bool _accountChanged(String scope, int authGeneration) =>
      ref.read(accountStorageScopeProvider).v2Namespace != scope ||
      ref.read(authSessionBoundaryProvider).generation != authGeneration;

  @override
  Widget build(BuildContext context) {
    ref.listen(accountStorageScopeProvider, (previous, next) {
      if (previous?.v2Namespace == next.v2Namespace) return;
      final sheet = _sheet;
      if (sheet != null && sheet.mounted) Navigator.pop(sheet);
    });
    final spanish = ChronoSparkLocalizations.of(context).isSpanish;
    String copy(String en, String es) => spanish ? es : en;
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final choices = <Widget>[
      _ModeChoice(
        key: const Key('assistant-mode-on-device'),
        selected: !widget.aiSelected,
        onPressed: widget.enabled && widget.aiSelected
            ? widget.onChooseOnDevice
            : null,
        icon: Icons.offline_bolt_outlined,
        tooltip: copy('On-device tools', 'Herramientas locales'),
        label: copy('On this device · free', 'En este dispositivo · gratis'),
      ),
      _ModeChoice(
        key: const Key('assistant-mode-ai'),
        selected: widget.aiSelected,
        onPressed: widget.enabled && !widget.aiSelected
            ? () => unawaited(_chooseAi())
            : null,
        icon: Icons.chat_bubble_outline,
        label: copy(
          'AI chat · $conversationMessageCredits credits per message',
          'Chat con IA · $conversationMessageCredits créditos por mensaje',
        ),
      ),
    ];
    return Semantics(
      container: true,
      label: copy('How to use this screen', 'Cómo usar esta pantalla'),
      child: KeyedSubtree(
        key: const Key('assistant-mode-switch'),
        child: largeText
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [choices[0], const SizedBox(height: 8), choices[1]],
              )
            : Row(
                children: [
                  Expanded(child: choices[0]),
                  const SizedBox(width: 8),
                  Expanded(child: choices[1]),
                ],
              ),
      ),
    );
  }
}

/// One of the two choices. The chosen one is filled and announced as
/// selected; both are at least 48dp tall and wrap their text.
class _ModeChoice extends StatelessWidget {
  const _ModeChoice({
    super.key,
    required this.selected,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.tooltip,
  });

  final bool selected;
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          backgroundColor: selected
              ? const Color(0xFF1F4A6E)
              : const Color(0xFF10203F),
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          side: BorderSide(color: Colors.cyanAccent, width: selected ? 2 : 1),
        ),
        icon: Icon(selected ? Icons.check_circle : icon),
        label: Text(label, textAlign: TextAlign.center),
      ),
    );
    final hint = tooltip;
    return hint == null ? button : Tooltip(message: hint, child: button);
  }
}
