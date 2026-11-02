import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/pattern_math.dart';

/// A device tier to imitate on better hardware.
enum SimulatedTier {
  /// Play exactly what the device can do.
  native,

  /// Sharpness lost, curves stepped: Android composition primitives and
  /// amplitude waveforms.
  intensity,

  /// Timing only: a rotary (ERM) motor, common on budget handsets. `perform`
  /// declines system constants, as the plugin does on that tier.
  rhythm;

  String get label => switch (this) {
        SimulatedTier.native => 'Native',
        SimulatedTier.intensity => 'Intensity',
        SimulatedTier.rhythm => 'Rhythm',
      };

  String get explanation => switch (this) {
        SimulatedTier.native =>
          'Everything plays as this device renders it.',
        SimulatedTier.intensity =>
          'Sharpness flattened and curves stepped, like Android composition '
              'primitives or an amplitude waveform. Strength and rhythm survive.',
        SimulatedTier.rhythm =>
          'Only timing survives, like a single-speed rotary motor. Every tap '
              'is widened and full-strength, anything below 0.15 is dropped, '
              'and intents skip their system constant for their pattern.',
      };
}

/// Rewrites a pattern the way a less capable device would render it, so a
/// designer holding a flagship can feel what a budget phone will feel.
///
/// This mirrors the plugin's own degradation ladder (see the package README,
/// "Platform Support"): sharpness is the first thing to go, then intensity,
/// leaving rhythm.
abstract final class FidelitySimulator {
  /// How wide the plugin makes a tap on the on/off path
  /// (`ON_OFF_TRANSIENT_WIDTH_MS` in the Android `WaveformRenderer`).
  static const rhythmTapWidth = Duration(milliseconds: 50);

  /// Step size used to approximate a curve.
  static const step = Duration(milliseconds: 40);

  /// Intensity at which an on/off motor switches on, for taps and rumbles
  /// alike (`ON_OFF_THRESHOLD` in the Android `WaveformRenderer`). Anything
  /// quieter is not played at full strength — it is not played at all.
  static const onThreshold = 0.15;

  static HapticPattern degrade(HapticPattern pattern, SimulatedTier tier) =>
      switch (tier) {
        SimulatedTier.native => pattern,
        SimulatedTier.intensity => _intensityTier(pattern),
        SimulatedTier.rhythm => _rhythmTier(pattern),
      };

  static HapticPattern _intensityTier(HapticPattern pattern) {
    final events = <HapticEvent>[];
    for (final event in pattern.events) {
      switch (event) {
        case TransientEvent():
          events.add(
            TransientEvent(
              intensity: event.intensity,
              delay: event.delay,
            ),
          );
        case ContinuousEvent():
          events.addAll(
            _steps(event).map(
              (s) => ContinuousEvent(
                intensity: s.value,
                duration: s.length,
                delay: s.start,
              ),
            ),
          );
      }
    }
    return HapticPattern(events);
  }

  static HapticPattern _rhythmTier(HapticPattern pattern) {
    final events = <HapticEvent>[];
    for (final event in pattern.events) {
      switch (event) {
        case TransientEvent():
          if (event.intensity < onThreshold) continue;
          events.add(
            ContinuousEvent(
              intensity: 1,
              duration: rhythmTapWidth,
              delay: event.delay,
            ),
          );
        case ContinuousEvent():
          // Merge consecutive "on" steps into single full-strength runs.
          Duration? runStart;
          var runEnd = Duration.zero;
          for (final s in _steps(event)) {
            final on = s.value >= onThreshold;
            if (on) {
              runStart ??= s.start;
              runEnd = s.start + s.length;
            } else if (runStart != null) {
              events.add(
                ContinuousEvent(
                  intensity: 1,
                  duration: runEnd - runStart,
                  delay: runStart,
                ),
              );
              runStart = null;
            }
          }
          if (runStart != null) {
            events.add(
              ContinuousEvent(
                intensity: 1,
                duration: runEnd - runStart,
                delay: runStart,
              ),
            );
          }
      }
    }
    return HapticPattern(events);
  }

  static Iterable<_Step> _steps(ContinuousEvent event) sync* {
    final total = event.duration.inMilliseconds;
    if (total <= 0) return;
    final stepMs = step.inMilliseconds;
    for (var at = 0; at < total; at += stepMs) {
      final length = (total - at) < stepMs ? total - at : stepMs;
      final mid = (at + length / 2) / total;
      yield _Step(
        start: event.delay + Duration(milliseconds: at),
        length: Duration(milliseconds: length),
        value: PatternMath.valueAt(event.intensity, mid),
      );
    }
  }
}

class _Step {
  const _Step({required this.start, required this.length, required this.value});

  final Duration start;
  final Duration length;
  final double value;
}
