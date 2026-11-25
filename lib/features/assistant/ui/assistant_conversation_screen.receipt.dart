part of 'assistant_conversation_screen.dart';

/// What a reply used and cost, the balance in the header, and the ways out of
/// running out of credits or being offline. Only values the app really has
/// are shown: the counts come from the packet sent for the reply, the
/// credits from the server's answer, and the balance from the latest answer
/// or from the credit wallet the app already loaded. Nothing is fetched just
/// to show a balance.
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
    final left = receipt.remainingCredits;
    return copy(
      'Used: $used · Cost: $cost · ${left == 1 ? '1 credit left' : '$left credits left'}',
      'Usó: $used · Costo: $cost · ${left == 1 ? 'Queda 1 crédito' : 'Quedan $left créditos'}',
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

  /// The latest balance the server reported to this screen, otherwise the
  /// server wallet when the app has already loaded it. The wallet is only
  /// watched when it already exists, so opening Chat never loads it.
  int? _knownBalance() {
    if (_reportedBalance case final int balance) return balance;
    if (_walletUntrusted ||
        !ref.watch(aiCreditWalletFromServerProvider) ||
        !ref.exists(aiCreditWalletProvider)) {
      return null;
    }
    return ref.watch(aiCreditWalletProvider).asData?.value.balance;
  }

  Widget _balanceLine() {
    final balance = _knownBalance();
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

  /// The charge state changed or is unknown: the app's wallet is refreshed
  /// after this frame, once this screen has stopped watching it, so the
  /// refresh is read where it is next needed instead of fetched for Chat.
  void _refreshWalletLater() {
    final container = ProviderScope.containerOf(context, listen: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        container.invalidate(aiCreditWalletProvider);
      } on Object {
        // The app is closing; the wallet is read fresh next time.
      }
    });
  }

  /// Applies what a failed request says about the balance: the figure the
  /// server sent, or, when the request was sent for a reply without one, no
  /// figure until a reply or the wallet confirms it again.
  void _noteFailureBalance(int? reported, {required bool sentForReply}) {
    if (reported != null) {
      _reportedBalance = reported;
      return;
    }
    if (sentForReply) _reportedBalance = null;
    _walletUntrusted = true;
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
                ' Buying credits is not available in this version of the app. Wait for your monthly allowance, then tap send to ask again as a new message, or use Free tools, which need no credits.',
                ' Comprar créditos no está disponible en esta versión de la app. Espera tu asignación mensual y luego toca enviar para preguntar de nuevo como un mensaje nuevo, o usa Herramientas gratis, que no usan créditos.',
              ));
  }

  /// Opens the existing plans and credits screen. The balance shown here is
  /// then taken from the wallet that screen loads, so a purchase shows.
  void _openCredits() {
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    _rebuild(() {
      _reportedBalance = null;
      _walletUntrusted = false;
    });
    unawaited(
      router.push<void>(ref.read(routeSurfaceProvider).paywall).then((_) {
        if (mounted) _rebuild(() {});
      }),
    );
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
    'You are offline. AI chat needs an internet connection, so nothing was sent and nothing was charged. Your question is kept; connect, then tap send again. Free tools work without a connection.',
    'No tienes conexión. El chat con IA necesita internet, así que no se envió nada y no se cobró nada. Tu pregunta se conserva; conéctate y vuelve a tocar enviar. Herramientas gratis funciona sin conexión.',
  );
}
