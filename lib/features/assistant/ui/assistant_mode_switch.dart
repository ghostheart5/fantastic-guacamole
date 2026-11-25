import 'dart:async';

import 'package:fantastic_guacamole/domain/entities/assistant_conversation.dart';
import 'package:fantastic_guacamole/features/assistant/ui/ai_chat_consent.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/assistant_conversation_provider.dart';
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
    required this.surface,
    required this.aiSelected,
    required this.enabled,
    required this.onChooseOnDevice,
    required this.onChooseAi,
    this.aiOff = false,
    this.disabledReason,
    this.replyReady = false,
  });

  final ConversationSurface surface;
  final bool aiSelected;

  /// AI chat has not been allowed yet: the AI choice is not shown as chosen.
  final bool aiOff;
  final bool enabled;

  /// Said beside the dimmed control when [enabled] is false.
  final String? disabledReason;

  /// Something arrived in AI chat while the free assistant was shown.
  final bool replyReady;
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
    final block = ref.read(assistantChatBlockProvider(widget.surface));
    if (block != AiChatBlock.none) {
      _say(_blockText(block));
      return;
    }
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

  bool get _spanish => ChronoSparkLocalizations.of(context).isSpanish;

  String _blockText(AiChatBlock block) => switch (block) {
    AiChatBlock.accountNotReady =>
      _spanish
          ? 'El chat con IA no está disponible porque tu cuenta aún no está lista. Inténtalo en un momento.'
          : 'AI chat is not available because your account is not ready yet. Try again in a moment.',
    AiChatBlock.checking =>
      _spanish
          ? 'Estamos comprobando si el chat con IA está disponible. Inténtalo en un momento.'
          : 'Checking whether AI chat is available. Try again in a moment.',
    AiChatBlock.notAvailableNow =>
      _spanish
          ? 'El chat con IA no está disponible para esta cuenta en este momento. Lo gratis en este dispositivo sigue funcionando.'
          : 'AI chat is not available for this account right now. The free assistant on this device still works.',
    _ =>
      _spanish
          ? 'El chat con IA no está disponible en esta versión de la app ni para esta cuenta. Lo gratis en este dispositivo sigue funcionando.'
          : 'AI chat is not available in this version of the app or for this account. The free assistant on this device still works.',
  };

  void _say(String text) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(text)));
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
        dimmed: !widget.enabled,
        onPressed: widget.enabled && widget.aiSelected
            ? widget.onChooseOnDevice
            : null,
        icon: Icons.offline_bolt_outlined,
        tooltip: copy('On-device tools', 'Herramientas locales'),
        label: copy('On this device · free', 'En este dispositivo · gratis'),
      ),
      _ModeChoice(
        key: const Key('assistant-mode-ai'),
        selected: widget.aiSelected && !widget.aiOff,
        dimmed: !widget.enabled,
        onPressed: widget.enabled && !widget.aiSelected
            ? () => unawaited(_chooseAi())
            : null,
        icon: Icons.chat_bubble_outline,
        label: copy(
          widget.aiOff
              ? 'AI chat · off · $conversationMessageCredits credits per message'
              : 'AI chat · $conversationMessageCredits credits per message',
          widget.aiOff
              ? 'Chat con IA · desactivado · $conversationMessageCredits créditos por mensaje'
              : 'Chat con IA · $conversationMessageCredits créditos por mensaje',
        ),
      ),
    ];
    final note = !widget.enabled ? widget.disabledReason : null;
    final ready = widget.replyReady
        ? copy(
            'Something new arrived in AI chat. Choose AI chat to see it.',
            'Llegó algo nuevo al chat con IA. Elige Chat con IA para verlo.',
          )
        : null;
    final control = KeyedSubtree(
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
    );
    return Semantics(
      container: true,
      label: copy('How to use this screen', 'Cómo usar esta pantalla'),
      hint: note,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          control,
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                note,
                key: const Key('assistant-mode-disabled-reason'),
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          if (ready != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                ready,
                key: const Key('assistant-mode-reply-ready'),
                style: const TextStyle(color: Colors.cyanAccent),
              ),
            ),
        ],
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
    required this.dimmed,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.tooltip,
  });

  final bool selected;
  final bool dimmed;
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
          disabledForegroundColor: dimmed ? Colors.white60 : Colors.white,
          backgroundColor: dimmed
              ? const Color(0xFF0A1424)
              : selected
              ? const Color(0xFF1F4A6E)
              : const Color(0xFF10203F),
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          side: BorderSide(
            color: dimmed ? Colors.white30 : Colors.cyanAccent,
            width: selected ? 2 : 1,
          ),
        ),
        icon: Icon(selected ? Icons.check_circle : icon),
        label: Text(label, textAlign: TextAlign.center),
      ),
    );
    final hint = tooltip;
    return hint == null ? button : Tooltip(message: hint, child: button);
  }
}
