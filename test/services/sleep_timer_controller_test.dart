import 'package:flutter_test/flutter_test.dart';
import 'package:audiovault/services/sleep_timer_controller.dart';

void main() {
  // sleepTimerTick is tested in player_helpers_test.dart — no duplicate here.

  group('SleepTimerController', () {
    test('starts inactive', () {
      final c = SleepTimerController();
      expect(c.isActive, isFalse);
      expect(c.remaining.value, isNull);
      expect(c.stopAtChapterEnd.value, isFalse);
      c.disposeForTesting();
    });

    test('startTimed sets remaining and flags active', () {
      final c = SleepTimerController();
      c.startTimed(const Duration(minutes: 5), onFire: () {});
      expect(c.isActive, isTrue);
      expect(c.remaining.value, const Duration(minutes: 5));
      c.cancel();
      c.disposeForTesting();
    });

    test('setStopAtChapterEnd clears any pending timed countdown', () {
      final c = SleepTimerController();
      c.startTimed(const Duration(minutes: 5), onFire: () {});
      c.setStopAtChapterEnd(true);
      expect(c.remaining.value, isNull);
      expect(c.stopAtChapterEnd.value, isTrue);
      expect(c.isActive, isTrue);
      c.cancel();
      c.disposeForTesting();
    });

    test('cancel resets both flags', () {
      final c = SleepTimerController();
      c.setStopAtChapterEnd(true);
      c.cancel();
      expect(c.isActive, isFalse);
      expect(c.stopAtChapterEnd.value, isFalse);
      c.disposeForTesting();
    });

    test('startTimed with zero duration fires immediately and does not run',
        () {
      final c = SleepTimerController();
      var fired = 0;
      c.startTimed(Duration.zero, onFire: () => fired++);
      expect(fired, 1);
      expect(c.remaining.value, isNull);
      c.disposeForTesting();
    });

    testWidgets('timed countdown fires onFire after elapsing',
        (tester) async {
      final c = SleepTimerController();
      var fired = 0;
      c.startTimed(const Duration(seconds: 2), onFire: () => fired++);
      expect(fired, 0);
      await tester.pump(const Duration(seconds: 1));
      expect(c.remaining.value, const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(fired, 1);
      expect(c.remaining.value, isNull);
      c.disposeForTesting();
    });
  });
}
