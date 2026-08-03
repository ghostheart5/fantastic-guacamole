import 'package:fake_async/fake_async.dart';
import 'package:fantastic_guacamole/system/system_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SystemScheduler', () {
    test('resume starts periodic callbacks and pause stops them', () {
      fakeAsync((FakeAsync async) {
        final SystemScheduler scheduler = SystemScheduler();
        int syncTicks = 0;
        int aiTicks = 0;

        scheduler.onSyncOfflineQueue = () => syncTicks++;
        scheduler.onPrecomputeAI = () => aiTicks++;

        scheduler.resume();
        expect(scheduler.isRunning, isTrue);

        async.elapse(const Duration(minutes: 60));
        expect(syncTicks, 4);
        expect(aiTicks, 3);

        scheduler.pause();
        expect(scheduler.isRunning, isFalse);

        async.elapse(const Duration(minutes: 30));
        expect(syncTicks, 4);
        expect(aiTicks, 3);
      });
    });

    test('resume is idempotent while already running', () {
      fakeAsync((FakeAsync async) {
        final SystemScheduler scheduler = SystemScheduler();
        int syncTicks = 0;

        scheduler.onSyncOfflineQueue = () => syncTicks++;

        scheduler.resume();
        scheduler.resume();

        async.elapse(const Duration(minutes: 30));
        expect(syncTicks, 2);
      });
    });
  });
}
