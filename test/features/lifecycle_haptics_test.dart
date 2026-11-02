import 'package:flutter/material.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_patterns.dart';
import 'package:flutter_haptics_showcase/src/features/lab/presentation/demos/breathing_coach_demo.dart';
import 'package:flutter_haptics_showcase/src/features/lab/presentation/demos/hold_to_confirm_demo.dart';
import 'package:flutter_haptics_showcase/src/features/lab/presentation/demos/morse_code_demo.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/haptics_harness.dart';

/// What a long-running haptic does when its page leaves the screen, or a
/// second finger arrives.
void main() {
  late HapticsHarness harness;

  setUp(() => harness = HapticsHarness()..install());
  tearDown(() => harness.uninstall());

  /// [child] as the tab shell holds it: alive, with tickers muted while
  /// another tab is showing.
  Future<ValueNotifier<bool>> pumpInTab(WidgetTester tester, Widget child) async {
    final onstage = ValueNotifier(true);
    addTearDown(onstage.dispose);
    await harness.pump(
      tester,
      Scaffold(
        body: ValueListenableBuilder<bool>(
          valueListenable: onstage,
          builder: (context, on, child) =>
              TickerMode(enabled: on, child: child!),
          child: child,
        ),
      ),
    );
    return onstage;
  }

  testWidgets('Morse stops when its tab is left', (tester) async {
    final onstage = await pumpInTab(tester, const MorseCodeDemo());

    await tester.tap(find.text('Play in Morse'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(harness.fake.played, hasLength(1));
    expect(harness.fake.stopCount, 0);

    onstage.value = false;
    await tester.pump();

    expect(harness.fake.stopCount, 1);
  });

  testWidgets('Breathing Coach stops when its tab is left', (tester) async {
    final onstage = await pumpInTab(tester, const BreathingCoachDemo());

    await tester.tap(find.text('Start'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(harness.fake.stopCount, 0);

    onstage.value = false;
    await tester.pump();

    expect(harness.fake.stopCount, 1);
    onstage.value = true;
    await tester.pump();
    expect(find.text('Start'), findsOneWidget, reason: 'the session ended');
  });

  testWidgets('a second finger neither restarts nor ends a hold',
      (tester) async {
    await harness.pump(tester, const Scaffold(body: HoldToConfirmDemo()));
    final target = tester.getCenter(find.byIcon(Icons.delete_forever_rounded));

    final first = await tester.startGesture(target, pointer: 1);
    await tester.pump(); // the ring starts on this frame
    await tester.pump(const Duration(milliseconds: 200));
    final second = await tester.startGesture(target, pointer: 2);
    await tester.pump(const Duration(milliseconds: 100));
    await second.up();
    await tester.pump(const Duration(milliseconds: 600));

    // 900 ms after the first finger: one rise, uninterrupted, ending in the
    // lock. Restarted by the second finger, it would still be rising.
    expect(harness.fake.played, [HapticPatterns.chargeUp, AppPatterns.lock]);
    expect(harness.fake.stopCount, 0);

    await first.up();
    await tester.pump(const Duration(milliseconds: 400));
  });
}
