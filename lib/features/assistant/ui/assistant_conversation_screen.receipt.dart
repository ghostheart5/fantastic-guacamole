part of 'assistant_conversation_screen.dart';

/// What a reply used and cost, the balance in the header, and the ways out of
/// running out of credits or being offline. Only values the app really has
/// are shown: the counts come from the packet sent for the reply, the
/// credits from the server's answer, and the balance from
/// [aiCreditKnownBalanceProvider]. Nothing is fetched to show a balance.
extension _ReplyReceipt on _AssistantConversationScreenState {
  String _countLabel(
    int count,
    String en,
    String enMany,
    String es,
    String esMany,
  ) => copy(
    count == 1 ? '1 $en' : '$count $enMany',
    count == 1 ? '1 $es' : '$count $esMany',
  );

  String _receiptText(ConversationReplyReceipt receipt) {
    final used = <String>[
      copy('your question', 'tu pregunta'),
      if (receipt.tasks > 0)
        _countLabel(receipt.tasks, 'task', 'tasks', 'tarea', 'tareas'),
      if (receipt.goals > 0)
        _countLabel(receipt.goals, 'goal', 'goals', 'meta', 'metas'),
      if (receipt.milestones > 0)
        _countLabel(
          receipt.milestones,
          'milestone',
          'milestones',
          'hito',
          'hitos',
        ),
      if (receipt.schedule > 0)
        _countLabel(
          receipt.schedule,
          'schedule item',
          'schedule items',
          'elemento de la agenda',
          'elementos de la agenda',
        ),
      if (receipt.note) copy('your note', 'tu nota'),
      if (receipt.energy) copy('your energy', 'tu energía'),
      if (receipt.emotion) copy('your emotional state', 'tu estado emocional'),
      if (receipt.earlierMessages > 0)
        _countLabel(
          receipt.earlierMessages,
          'earlier message',
          'earlier messages',
          'mensaje anterior',
          'mensajes anteriores',
        ),
    ].join(', ');
    final cost = _countLabel(
      receipt.creditsCharged,
      'credit',
      'credits',
      'crédito',
      'créditos',
    );
    // The balance at the time of this reply, not necessarily now.
    final left = receipt.remainingCredits;
    return copy(
      'Used: $used · Cost: $cost · $left left after this reply',
      'Usó: $used · Costo: $cost · ${left == 1 ? 'Queda 1' : 'Quedan $left'} después de esta respuesta',
    );
  }

  /// The footer under an AI reply; replies saved before receipts have none.
  Widget _replyReceipt(Map<String, String> turn, {required Color color}) {
    final receipt = ConversationReplyReceipt.decode(
      turn[ConversationReplyReceipt.turnKey],
    );
    if (receipt == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        _receiptText(receipt),
        key: const Key('conversation-reply-receipt'),
        style: TextStyle(color: color, fontSize: 12),
      ),
    );
  }

  /// The balance the server last reported for this account while the app
  /// runs (an AI chat answer, or a wallet read made elsewhere). Watching it
  /// never reads the wallet, and it is empty after an account change.
  Widget _balanceLine() {
    final balance = ref.watch(aiCreditKnownBalanceProvider);
    if (balance == null) return const SizedBox.shrink();
    return Text(
      copy(
        'Your balance: ${balance == 1 ? '1 credit' : '$balance credits'}',
        'Tu saldo: ${balance == 1 ? '1 crédito' : '$balance créditos'}',
      ),
      key: const Key('conversation-balance'),
      style: const TextStyle(color: Colors.white70),
    );
  }

  /// Records what an answer for [packet] said about the balance: the figure
  /// the server sent, or, when the request was sent for a reply without one,
  /// no figure until the server reports one again.
  void _noteBalance(
    ConversationPacket packet,
    int? reported, {
    required bool sentForReply,
  }) {
    final known = ref.read(aiCreditKnownBalanceProvider.notifier);
    if (reported != null) {
      // Kept only if nothing changed since this request entered the paid
      // step in this run; a recovered request's figure stays in its footer.
      known.reportAnswer(packet.accountScope, packet.requestId, reported);
    } else if (sentForReply) {
      known.forget(packet.accountScope, packet.requestId);
    }
  }

  bool get _canBuyCredits => ref.read(subscriptionPurchasingEnabledProvider);

  String _outOfCreditsText({int? balance, required int needed}) {
    final detail = balance == null
        ? ''
        : copy(
            ': you have $balance and it needs $needed',
            ': tienes $balance y necesita $needed',
          );
    return copy(
          'You do not have enough AI credits for this message$detail. No credits were charged. Your question is kept.',
          'No tienes suficientes créditos de IA para este mensaje$detail. No se cobraron créditos. Tu pregunta se conserva.',
        ) +
        (_canBuyCredits
            ? copy(
                ' Get credits, or wait for your monthly allowance, then tap send to ask again as a new message.',
                ' Consigue créditos o espera tu asignación mensual; después toca enviar para preguntar de nuevo como un mensaje nuevo.',
              )
            : copy(
                ' Buying credits is not available in this version of the app. Wait for your monthly allowance, then tap send to ask again as a new message, or choose On this device · free, which needs no credits.',
                ' Comprar créditos no está disponible en esta versión de la app. Espera tu asignación mensual y luego toca enviar para preguntar de nuevo como un mensaje nuevo, o elige En este dispositivo · gratis, que no usa créditos.',
              ));
  }

  /// Opens the existing plans and credits screen. A purchase may follow, so
  /// the balance shown here is forgotten now; a wallet read made there, or
  /// later, reports the new one.
  void _openCredits() {
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    ref.read(aiCreditKnownBalanceProvider.notifier).walletChanged();
    unawaited(router.push<void>(ref.read(routeSurfaceProvider).paywall));
  }

  Widget _getCreditsAction() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Align(
      alignment: AlignmentDirectional.centerStart,
      child: FilledButton.icon(
        key: const Key('conversation-get-credits'),
        style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
        onPressed: _busy ? null : _openCredits,
        icon: const Icon(Icons.add_card_outlined),
        label: Text(copy('Get credits', 'Conseguir créditos')),
      ),
    ),
  );

  /// Known only from the connection status the app shell keeps running;
  /// Chat never starts it. Unknown is not treated as offline.
  bool get _offline =>
      ref.exists(networkStatusProvider) &&
      ref.read(networkInterfaceAvailabilityProvider) ==
          NetworkInterfaceAvailability.unavailable;

  String get _offlineText => copy(
    'You are offline. AI chat needs an internet connection, so nothing was sent and nothing was charged. Your question is kept; connect, then tap send again. The free assistant on this device works without a connection.',
    'No tienes conexión. El chat con IA necesita internet, así que no se envió nada y no se cobró nada. Tu pregunta se conserva; conéctate y vuelve a tocar enviar. El asistente gratis en este dispositivo funciona sin conexión.',
  );
}
