import 'dart:async';

import 'package:fantastic_guacamole/system/voice/voice_service.dart';
import 'package:fantastic_guacamole/ui/widgets/voice_playback_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  late _TestPlayback service;
  setUp(() => service = _TestPlayback());

  Future<GoRouter> mount(WidgetTester tester) async {
    final router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('SI')),
        ),
        GoRoute(
          path: '/planner',
          builder: (_, _) => const Scaffold(body: Text('Planner')),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        builder: (_, child) => Stack(
          children: <Widget>[
            Positioned.fill(child: child!),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: VoicePlaybackControls(
                service: service,
                navigation: router.routerDelegate,
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      router.dispose();
      await service.stop();
      service.state.dispose();
    });
    return router;
  }

  testWidgets('visible accessible Stop speaking cancels a long utterance', (
    tester,
  ) async {
    await mount(tester);
    final speech = service.speakChecked('A long planning response');
    await tester.pump();
    await tester.pump();
    expect(find.text('Stop speaking'), findsOneWidget);
    final before = service.stops;
    await tester.tap(find.text('Stop speaking'));
    await tester.pump();
    expect(service.stops, greaterThan(before));
    expect(service.isSpeaking, isFalse);
    expect(find.text('Stop speaking'), findsNothing);
    expect(await speech, isTrue);
  });

  testWidgets(
    'GoRouter screen change cancels speech without relying on disposal',
    (tester) async {
      final router = await mount(tester);
      final speech = service.speakChecked('Leaving SI');
      await tester.pump();
      await tester.pump();
      router.go('/planner');
      await tester.pumpAndSettle();
      expect(find.text('Planner'), findsOneWidget);
      expect(service.isSpeaking, isFalse);
      expect(find.text('Stop speaking'), findsNothing);
      await speech;
    },
  );

  testWidgets(
    'backgrounding cancels playback and resuming does not restart it',
    (tester) async {
      await mount(tester);
      final speech = service.speakChecked('Background cancellation');
      await tester.pump();
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(service.isSpeaking, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('Stop speaking'), findsNothing);
      expect(service.utterances, hasLength(1));
      await speech;
    },
  );

  testWidgets('natural completion removes the stop control', (tester) async {
    await mount(tester);
    final speech = service.speakChecked('Short response');
    await tester.pump();
    await tester.pump();
    expect(find.text('Stop speaking'), findsOneWidget);
    service.utterances.single.complete();
    await tester.pumpAndSettle();
    expect(find.text('Stop speaking'), findsNothing);
    expect(await speech, isTrue);
  });
}

class _TestPlayback extends VoiceService {
  final ValueNotifier<bool> state = ValueNotifier<bool>(false);
  final List<Completer<void>> utterances = <Completer<void>>[];
  int stops = 0;

  @override
  ValueNotifier<bool> get playback => state;
  @override
  bool get isSpeaking => state.value;

  @override
  Future<bool> speakChecked(String text) async {
    state.value = true;
    final pending = Completer<void>();
    utterances.add(pending);
    await pending.future;
    state.value = false;
    return true;
  }

  @override
  Future<void> stop() async {
    stops++;
    state.value = false;
    for (final pending in utterances) {
      if (!pending.isCompleted) pending.complete();
    }
  }
}
