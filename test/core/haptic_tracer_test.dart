import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics/testing.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/fidelity_simulator.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/haptic_pacer.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/haptic_tracer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/haptics_harness.dart';

const _saved = HapticIntent(
  ios: HapticArm.native(IOSHaptic.notificationSuccess),
  android: HapticArm.native(AndroidHaptic.confirm),
  pattern: HapticPatterns.success,
);

void main() {
  late HapticsHarness harness;
  late List<HapticTrace> traces;

  void install(FakeHapticsPlatform fake) {
    harness = HapticsHarness(fake: fake)..install();
    traces = [];
    harness.tracer.traces.listen(traces.add);
  }

  tearDown(() => harness.uninstall());

  group('recovery', () {
    test('a pattern perform recovers with is marked with the decline',
        () async {
      install(FakeHapticsPlatform(playsSystemHaptics: false));

      await FlutterHaptics.perform(_saved);
      await pumpEventQueue();

      final pattern = traces.last;
      expect(pattern.kind, HapticTraceKind.pattern);
      expect(pattern.recoveredFrom?.system, AndroidHaptic.confirm);
    });

    test('a failed playSystem followed by a play is not a recovery', () async {
      install(FakeHapticsPlatform(playsSystemHaptics: false));

      await FlutterHaptics.playSystem(AndroidHaptic.confirm);
      await FlutterHaptics.play(HapticPatterns.lightTap);
      await pumpEventQueue();

      expect(traces.last.recoveredFrom, isNull);
    });

    test('a silenced constant leaves nothing to recover', () async {
      install(FakeHapticsPlatform()..touchFeedbackOff = true);

      await FlutterHaptics.perform(_saved);
      await FlutterHaptics.play(HapticPatterns.lightTap);
      await pumpEventQueue();

      expect(traces.every((t) => t.recoveredFrom == null), isTrue);
    });
  });

  test('a handle replayed at a simulated tier is traced as a replay', () async {
    install(FakeHapticsPlatform());
    harness.tracer.tier = SimulatedTier.intensity;

    final handle = FlutterHaptics.register(
      HapticPatterns.selection,
      minInterval: Duration.zero,
    );
    addTearDown(handle.dispose);
    await handle.ready;
    await handle.play();
    await pumpEventQueue();

    expect(traces.last.kind, HapticTraceKind.replay);
    expect(traces.last.tier, SimulatedTier.intensity);
  });

  testWidgets('HapticPacer paces on the clock a widget test pumps',
      (tester) async {
    final pacer = HapticPacer();

    expect(pacer.ready(), isTrue);
    await tester.pump();
    expect(pacer.ready(), isFalse, reason: 'no time has passed');
    await tester.pump(const Duration(milliseconds: 100));
    expect(pacer.ready(), isTrue, reason: '100 ms is past the 40 ms floor');
  });
}
