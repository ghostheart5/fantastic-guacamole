import 'dart:math';

import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/billing_availability_provider.dart';
import 'package:fantastic_guacamole/state/providers/paywall_provider.dart';
import 'package:fantastic_guacamole/state/providers/personalization_provider.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef CreditTestReply = ({int status, Map<String, dynamic> data});
typedef CreditTestTransport =
    Future<CreditTestReply> Function(Map<String, dynamic> body);

final internalCreditTestTransportProvider = Provider<CreditTestTransport>((
  ref,
) {
  final client = ref.watch(supabaseClientProvider);
  return (body) async {
    if (client?.auth.currentUser == null) throw StateError('Sign-in required');
    try {
      final response = await client!.functions
          .invoke('ai-proxy', body: body)
          .timeout(const Duration(seconds: 45));
      return (
        status: response.status,
        data: Map<String, dynamic>.from(response.data as Map),
      );
    } on FunctionException catch (error) {
      return (
        status: error.status,
        data: error.details is Map
            ? Map<String, dynamic>.from(error.details as Map)
            : <String, dynamic>{},
      );
    }
  };
});

class InternalCreditTestState {
  const InternalCreditTestState({
    this.busy = false,
    this.message = 'Ready for a synthetic credit test.',
    this.lastRequest,
  });
  final bool busy;
  final String message;
  final Map<String, dynamic>? lastRequest;
}

final internalCreditTestProvider =
    NotifierProvider<InternalCreditTestController, InternalCreditTestState>(
      InternalCreditTestController.new,
    );

class InternalCreditTestController extends Notifier<InternalCreditTestState> {
  int _generation = 0;

  @override
  InternalCreditTestState build() {
    ref.watch(accountStorageScopeProvider.select((scope) => scope.v2Namespace));
    ref.watch(internalCreditTestEnabledProvider);
    ref.watch(
      personalizationProfileProvider.select((p) => p.externalAiAllowed),
    );
    _generation++;
    return const InternalCreditTestState();
  }

  Future<void> run({bool twoCredits = false, bool replay = false}) async {
    if (state.busy) return;
    if (!ref.read(internalCreditTestEnabledProvider) ||
        !ref.read(accountStorageScopeProvider).isWritable ||
        !ref.read(personalizationProfileProvider).externalAiAllowed) {
      state = const InternalCreditTestState(
        message: 'An authorized account and external AI consent are required.',
      );
      return;
    }
    final previous = state.lastRequest;
    if (replay && previous == null) return;
    final body = replay
        ? previous!
        : <String, dynamic>{
            'prompt': twoCredits
                ? 'This is a synthetic credit test with no personal information. In one short sentence, describe a useful way to arrange a fictional gardening tool shelf. Do not refer to any real person or app data.'
                : 'In one short sentence, describe how to organize a fictional tool shelf.',
            'history': const <Map<String, String>>[],
            'context': const <String, dynamic>{},
            'personality': 'planner',
            'allowExternalAi': true,
            'requestId':
                'credit-test-${List.generate(16, (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0')).join()}',
          };
    final generation = _generation;
    final account = ref.read(accountStorageScopeProvider).v2Namespace;
    state = InternalCreditTestState(
      busy: true,
      message: 'Waiting for the server result…',
      lastRequest: Map.unmodifiable(body),
    );
    var message =
        'Result not confirmed. Refresh the balance, then retry the same request.';
    try {
      final reply = await ref.read(internalCreditTestTransportProvider)(body);
      final data = reply.data;
      final charged = data['creditsCharged'];
      final remaining = data['remainingCredits'];
      final expectedCost = (body['prompt'] as String).length > 120 ? 2 : 1;
      if (reply.status == 200 &&
          data['requestId'] == body['requestId'] &&
          charged is num &&
          charged == expectedCost &&
          remaining is num &&
          remaining >= 0 &&
          data['message'] is String &&
          (data['message'] as String).trim().isNotEmpty) {
        message =
            'Server confirmed: ${charged.toInt()} credit(s) used. Balance: ${remaining.toInt()}.\n${data['message']}';
      } else if (reply.status == 402) {
        message = 'Insufficient credits. The server rejected this request.';
      } else if (reply.status == 409 && data['error'] == 'request_completed') {
        message =
            'The server already completed this request. No second charge was made.';
      } else if (reply.status == 409) {
        message =
            'The original request is still unresolved. Refresh the balance and retry this same request.';
      } else {
        message =
            'The server did not confirm a reply (HTTP ${reply.status}). Refresh the balance before retrying this request.';
      }
    } on Object {
      // Never expose transport credentials, raw provider errors, or tokens.
    }
    if (!ref.mounted ||
        account != ref.read(accountStorageScopeProvider).v2Namespace) {
      return;
    }
    ref.invalidate(aiCreditWalletProvider);
    if (generation != _generation) return;
    state = InternalCreditTestState(
      message: message,
      lastRequest: Map.unmodifiable(body),
    );
  }
}
