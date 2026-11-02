import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/fidelity_simulator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FidelitySimulator', () {
    test('native leaves a pattern untouched', () {
      expect(
        FidelitySimulator.degrade(HapticPatterns.success, SimulatedTier.native),
        HapticPatterns.success,
      );
    });

    test('intensity tier keeps strength and timing, flattens sharpness', () {
      final degraded = FidelitySimulator.degrade(
        HapticPatterns.success,
        SimulatedTier.intensity,
      );
      final taps = degraded.events.cast<TransientEvent>();
      expect(taps.map((e) => e.intensity), [0.5, 0.7, 1.0]);
      expect(taps.map((e) => e.sharpness).toSet(), {0.5});
      expect(
        taps.map((e) => e.delay),
        HapticPatterns.success.events.map((e) => e.start),
      );
    });

    test('intensity tier steps a curve into constant segments', () {
      final degraded = FidelitySimulator.degrade(
        HapticPatterns.explosion, // 400 ms fade-out
        SimulatedTier.intensity,
      );
      expect(degraded.events, hasLength(10)); // 400 / 40
      expect(degraded.events.every((e) => e is ContinuousEvent), isTrue);
      expect(degraded.duration, HapticPatterns.explosion.duration);
    });

    test('rhythm tier turns every tap into a full-strength 50 ms pulse', () {
      final degraded = FidelitySimulator.degrade(
        HapticPatterns.doubleClick,
        SimulatedTier.rhythm,
      );
      expect(degraded.events, hasLength(2));
      for (final event in degraded.events) {
        expect(event, isA<ContinuousEvent>());
        expect(
          (event as ContinuousEvent).duration,
          FidelitySimulator.rhythmTapWidth,
        );
        expect(event.intensity, const ConstantParam(1));
      }
      // Spacing — the only thing a rotary motor keeps — survives.
      expect(degraded.events[1].start, const Duration(milliseconds: 100));
    });

    test('rhythm tier keeps only the loud part of a fade', () {
      final degraded = FidelitySimulator.degrade(
        HapticPatterns.explosion, // 1.0 → 0.0 over 400 ms
        SimulatedTier.rhythm,
      );
      expect(degraded.events, hasLength(1));
      final run = degraded.events.single as ContinuousEvent;
      expect(run.start, Duration.zero);
      // On while at or above the plugin's 0.15 threshold: about 85% of it.
      expect(run.duration.inMilliseconds, inInclusiveRange(320, 360));
    });

    test('rhythm tier drops a tap too quiet to switch the motor on', () {
      const pattern = HapticPattern([
        TransientEvent(intensity: 0.1, sharpness: 0.9),
        TransientEvent(intensity: 0.6, delay: Duration(milliseconds: 100)),
      ]);

      final degraded = FidelitySimulator.degrade(pattern, SimulatedTier.rhythm);

      // The plugin's on/off path plays nothing below 0.15 rather than
      // playing it at full strength.
      expect(degraded.events, hasLength(1));
      expect(degraded.events.single.start, const Duration(milliseconds: 100));
    });
  });
}
