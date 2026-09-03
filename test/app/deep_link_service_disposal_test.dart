import 'dart:async';

import 'package:fantastic_guacamole/app/router/deep_link_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dispose waits for deep-link stream cancellation', () async {
    final Completer<void> cancellationStarted = Completer<void>();
    final Completer<void> allowCancellation = Completer<void>();
    final StreamController<Uri> links = StreamController<Uri>(
      onCancel: () {
        cancellationStarted.complete();
        return allowCancellation.future;
      },
    );
    final DeepLinkService service = DeepLinkService.forTesting(
      initialLinkLoader: () async => null,
      uriLinkStream: links.stream,
    );
    await service.initializeEarly();

    bool disposalCompleted = false;
    final Future<void> disposal = service.dispose().then((_) {
      disposalCompleted = true;
    });

    await cancellationStarted.future;
    await Future<void>.delayed(Duration.zero);
    expect(disposalCompleted, isFalse);

    allowCancellation.complete();
    await disposal;
    expect(disposalCompleted, isTrue);
    await links.close();
  });

  test('awaited dispose exposes deep-link cancellation failures', () async {
    final StreamController<Uri> links = StreamController<Uri>(
      onCancel: () => Future<void>.error(StateError('cancel failed')),
    );
    final DeepLinkService service = DeepLinkService.forTesting(
      initialLinkLoader: () async => null,
      uriLinkStream: links.stream,
    );
    await service.initializeEarly();

    await expectLater(service.dispose(), throwsA(isA<StateError>()));
    await links.close();
  });
}
