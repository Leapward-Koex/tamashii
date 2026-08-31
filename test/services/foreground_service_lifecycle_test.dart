import 'package:flutter_test/flutter_test.dart';
import 'package:tamashii/services/foreground_service_lifecycle.dart';

void main() {
  group('ForegroundServiceInstanceTracker', () {
    test('old stop cannot clear replacement readiness during restart', () {
      final tracker = ForegroundServiceInstanceTracker()
        ..markReady('old-service')
        ..beginRestart();
      var replacementReadinessFailed = false;

      if (tracker.acceptStopped('old-service')) {
        replacementReadinessFailed = true;
      }

      expect(replacementReadinessFailed, isFalse);
      expect(tracker.activeInstanceId, isNull);
      expect(tracker.acceptsMessage('replacement-service'), isTrue);
    });

    test('late old stop cannot clear an already-ready replacement', () {
      final tracker = ForegroundServiceInstanceTracker()
        ..markReady('old-service')
        ..beginRestart()
        ..markReady('replacement-service');

      expect(tracker.acceptStopped('old-service'), isFalse);
      expect(tracker.activeInstanceId, 'replacement-service');
      expect(tracker.acceptStopped('replacement-service'), isTrue);
      expect(tracker.activeInstanceId, isNull);
    });

    test('intentional stop is retired before an immediate new start', () {
      final tracker = ForegroundServiceInstanceTracker()
        ..markReady('stopping-service')
        ..retireCurrent()
        ..markReady('new-service');

      expect(tracker.acceptStopped('stopping-service'), isFalse);
      expect(tracker.activeInstanceId, 'new-service');
    });

    test('unidentified and unrelated messages are rejected', () {
      final tracker = ForegroundServiceInstanceTracker()
        ..markReady('active-service');

      expect(tracker.acceptsMessage(null), isFalse);
      expect(tracker.acceptsMessage(''), isFalse);
      expect(tracker.acceptsMessage('unrelated-service'), isFalse);
      expect(tracker.acceptsMessage('active-service'), isTrue);
    });
  });

  group('DelayedServiceStopController', () {
    late void Function() elapse;
    late bool cancelled;
    late DelayedServiceStopController controller;

    setUp(() {
      cancelled = false;
      controller = DelayedServiceStopController(
        scheduler: (delay, callback) {
          expect(delay, const Duration(seconds: 5));
          elapse = callback;
          return () {
            cancelled = true;
          };
        },
      );
    });

    test('new work cancels a pending completion shutdown', () {
      var stopCalls = 0;
      controller.schedule(
        delay: const Duration(seconds: 5),
        onElapsed: (_) => stopCalls++,
      );

      controller.invalidate();
      elapse(); // Simulate a timer callback already posted to the event queue.

      expect(cancelled, isTrue);
      expect(stopCalls, 0);
      expect(controller.isScheduled, isFalse);
    });

    test('queued stop token is invalid after a new torrent starts', () {
      int? queuedGeneration;
      controller.schedule(
        delay: const Duration(seconds: 5),
        onElapsed: (generation) => queuedGeneration = generation,
      );
      elapse();
      expect(queuedGeneration, isNotNull);

      // onReceiveData invalidates synchronously, before start_download waits
      // behind earlier work in the task's serialized command queue.
      controller.invalidate();

      expect(controller.isCurrent(queuedGeneration!), isFalse);
    });

    test('repeated completion updates schedule only one stop', () {
      var scheduledCalls = 0;
      final deduplicatingController = DelayedServiceStopController(
        scheduler: (_, callback) {
          scheduledCalls++;
          elapse = callback;
          return () {};
        },
      );

      deduplicatingController.schedule(
        delay: const Duration(seconds: 5),
        onElapsed: (_) {},
      );
      deduplicatingController.schedule(
        delay: const Duration(seconds: 5),
        onElapsed: (_) {},
      );

      expect(scheduledCalls, 1);
    });
  });
}
