import 'package:flutter/foundation.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics/testing.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_haptics.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/fidelity_simulator.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/haptic_tracer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/haptics_harness.dart';

void main() {
  late HapticsHarness harness;

  setUp(() {
    harness = HapticsHarness()..install();
  });
  tearDown(() => harness.uninstall());

  test('on Android, an intent takes the native route when it can', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    final route = await FlutterHaptics.perform(AppHaptics.success);

    expect(route, HapticRoute.system);
    expect(harness.fake.systemHaptics, [AndroidHaptic.confirm]);
    expect(harness.fake.played, isEmpty);
  });

  test('on iOS, the same intent names the iOS constant', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    await FlutterHaptics.perform(AppHaptics.success);

    expect(harness.fake.systemHaptics, [IOSHaptic.notificationSuccess]);
  });

  test('a device that declines the constant gets the pattern', () async {
    harness.uninstall();
    harness = HapticsHarness(
      fake: FakeHapticsPlatform(playsSystemHaptics: false),
    )..install();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    final route = await FlutterHaptics.perform(AppHaptics.switchOn);

    expect(route, HapticRoute.pattern);
    expect(harness.fake.lastPlayed, AppHaptics.switchOn.pattern);
  });

  test('caution on Android plays its pattern by choice, without asking',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    final route = await FlutterHaptics.perform(AppHaptics.caution);

    expect(route, HapticRoute.pattern);
    expect(
      harness.fake.systemHaptics,
      isEmpty,
      reason: 'a pattern arm is chosen, not recovered: nothing was asked for',
    );
    expect(harness.fake.played, [HapticPatterns.warning]);
  });

  test('caution on iOS is the native warning', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    expect(await FlutterHaptics.perform(AppHaptics.caution), HapticRoute.system);
    expect(harness.fake.systemHaptics, [IOSHaptic.notificationWarning]);
    expect(harness.fake.played, isEmpty);
  });

  test('the tracer forwards the intent to the platform beneath it', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    await FlutterHaptics.perform(AppHaptics.caution);

    // A wrapper that dropped noteIntent would leave this empty, silently.
    expect(harness.fake.intents, [AppHaptics.caution]);
  });

  test('switching haptics off silences every verb', () async {
    FlutterHaptics.enabled = false;

    await FlutterHaptics.perform(AppHaptics.press);
    await FlutterHaptics.perform(AppHaptics.caution);
    await FlutterHaptics.play(HapticPatterns.heartbeat);

    expect(harness.fake.systemHaptics, isEmpty);
    expect(harness.fake.played, isEmpty);
  });

  test('the tracer reports what reached the platform', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final traces = <HapticTrace>[];
    final sub = harness.tracer.traces.listen(traces.add);
    addTearDown(sub.cancel);

    await FlutterHaptics.perform(AppHaptics.tick);
    await FlutterHaptics.play(HapticPatterns.heartbeat);
    await pumpEventQueue();

    expect(traces.map((t) => t.kind), [
      HapticTraceKind.system,
      HapticTraceKind.pattern,
    ]);
    expect(traces.first.system, AndroidHaptic.clockTick);
    expect(traces.last.pattern, HapticPatterns.heartbeat);
  });

  testWidgets('a handle paces itself on the clock testWidgets advances',
      (tester) async {
    final handle = FlutterHaptics.register(
      HapticPatterns.selection,
      minInterval: const Duration(milliseconds: 40),
    );
    addTearDown(handle.dispose);
    await handle.ready;

    expect(await handle.play(), HapticRoute.pattern);
    expect(
      await handle.play(),
      HapticRoute.none,
      reason: 'no time has passed: a pump without a duration advances none',
    );

    await tester.pump(const Duration(milliseconds: 50));
    expect(await handle.play(), HapticRoute.pattern);

    expect(harness.fake.replays, hasLength(2));
    expect(harness.fake.played, isEmpty, reason: 'every play was a replay');
  });

  test('a handle whose registration is lost falls back through the tracer',
      () async {
    final traces = <HapticTrace>[];
    final sub = harness.tracer.traces.listen(traces.add);
    addTearDown(sub.cancel);

    final handle = FlutterHaptics.register(
      HapticPatterns.selection,
      minInterval: Duration.zero,
    );
    addTearDown(handle.dispose);
    await handle.ready;

    harness.fake.debugLoseRegistrations();
    expect(await handle.play(), HapticRoute.pattern);
    await pumpEventQueue();

    expect(harness.fake.played, [HapticPatterns.selection]);
    expect(handle.isPrepared, isFalse);
    expect(
      traces.map((t) => t.kind),
      [HapticTraceKind.pattern],
      reason: 'the failed replay is not traced; the fallback is, once',
    );
  });

  test('a simulated rhythm tier declines constants, like the real one',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    harness.tracer.tier = SimulatedTier.rhythm;

    final route = await FlutterHaptics.perform(AppHaptics.success);

    // The native route never reached the fake; the recovery did, degraded.
    expect(route, HapticRoute.pattern);
    expect(harness.fake.systemHaptics, isEmpty);
    expect(
      harness.fake.lastPlayed,
      FidelitySimulator.degrade(HapticPatterns.success, SimulatedTier.rhythm),
    );
  });

  test('a simulated rhythm tier still passes playSystem through, like the '
      'real one', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    harness.tracer.tier = SimulatedTier.rhythm;

    final route = await FlutterHaptics.playSystem(AndroidHaptic.confirm);

    // The plugin second-guesses only `perform`, which has a pattern to fall
    // back on. A constant asked for by name is handed over.
    expect(route, HapticRoute.system);
    expect(harness.fake.systemHaptics, [AndroidHaptic.confirm]);
  });

  group('a pinned tier', () {
    // A fresh instance each time: the pin sticks to the instance.
    HapticPattern pattern() => HapticPattern([...HapticPatterns.success.events]);

    test('replaces the app-wide tier, so it is simulated once', () async {
      harness.tracer.tier = SimulatedTier.rhythm;
      final traces = <HapticTrace>[];
      final sub = harness.tracer.traces.listen(traces.add);
      addTearDown(sub.cancel);

      await FlutterHaptics.play(
        harness.tracer.pinTier(pattern(), SimulatedTier.intensity),
      );
      await pumpEventQueue();

      expect(
        harness.fake.lastPlayed,
        FidelitySimulator.degrade(pattern(), SimulatedTier.intensity),
      );
      expect(traces.single.tier, SimulatedTier.intensity);
    });

    test('at native plays the pattern untouched', () async {
      harness.tracer.tier = SimulatedTier.rhythm;

      await FlutterHaptics.play(
        harness.tracer.pinTier(pattern(), SimulatedTier.native),
      );

      expect(harness.fake.lastPlayed, pattern());
    });

    test('leaves other patterns on the app-wide tier', () async {
      harness.tracer
        ..tier = SimulatedTier.rhythm
        ..pinTier(pattern(), SimulatedTier.native);

      await FlutterHaptics.play(pattern());

      expect(
        harness.fake.lastPlayed,
        FidelitySimulator.degrade(pattern(), SimulatedTier.rhythm),
      );
    });
  });
}
