import 'package:fantastic_guacamole/domain/assistant/axiomara_memory_contract.dart';
import 'package:fantastic_guacamole/domain/assistant/axiomara_router_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('memory rejects a record from another account scope', () {
    final context = AxiomaraMemoryContext(
      accountScopeId: 'account-a',
      records: <AxiomaraMemoryRecord>[
        AxiomaraMemoryRecord(
          id: 'memory-1',
          accountScopeId: 'account-b',
          kind: AxiomaraMemoryKind.preference,
          provenance: AxiomaraMemoryProvenance.userProvided,
          text: 'Prefers morning planning.',
          recordedAt: DateTime.utc(2026, 9, 29),
        ),
      ],
    );
    expect(context.validate, throwsA(isA<AxiomaraMemoryContractException>()));
  });

  test('memory rejects non-finite confidence', () {
    final context = AxiomaraMemoryContext(
      accountScopeId: 'account-a',
      records: <AxiomaraMemoryRecord>[
        AxiomaraMemoryRecord(
          id: 'memory-1',
          accountScopeId: 'account-a',
          kind: AxiomaraMemoryKind.preference,
          provenance: AxiomaraMemoryProvenance.unknown,
          text: 'Prefers morning planning.',
          recordedAt: DateTime.utc(2026, 9, 29),
          confidence: double.nan,
        ),
      ],
    );
    expect(context.validate, throwsA(isA<AxiomaraMemoryContractException>()));
  });

  test('local, SI, and safety routes cannot consume Claude credits', () {
    for (final route in <AxiomaraRoute>[
      AxiomaraRoute.local,
      AxiomaraRoute.si,
      AxiomaraRoute.safety,
    ]) {
      final receipt = AxiomaraRouteReceipt(
        decision: AxiomaraRouteDecision(
          route: route,
          reason: 'deterministic evidence path',
          externalAiUsed: false,
          requiresCredits: false,
          readOnly: true,
        ),
        memoryContextCount: 2,
        latencyMs: 10,
        creditsUsed: 1,
      );
      expect(receipt.validate, throwsA(isA<AxiomaraRouterContractException>()));
    }
  });

  test(
    'Claude and hybrid routes explicitly require external AI and credits',
    () {
      for (final route in <AxiomaraRoute>[
        AxiomaraRoute.claude,
        AxiomaraRoute.hybrid,
      ]) {
        final decision = AxiomaraRouteDecision(
          route: route,
          reason: 'complex reasoning requested',
          externalAiUsed: true,
          requiresCredits: true,
          readOnly: true,
        );
        expect(decision.validate, returnsNormally);
      }
    },
  );
}
