import 'dart:math' as math;

import 'package:flutter_haptics/flutter_haptics.dart';

/// Reading values back out of patterns: for drawing them, and for simulating
/// how they degrade on cheaper hardware.
abstract final class PatternMath {
  /// The value of [param] at relative time [t] (0.0–1.0 through its event).
  static double valueAt(HapticParam param, double t) {
    final clamped = t.clamp(0.0, 1.0);
    return switch (param) {
      ConstantParam(:final value) => value,
      LinearParam(:final from, :final to) => from + (to - from) * clamped,
      CurveParam(:final points) => _interpolate(points, clamped),
    };
  }

  /// Highest intensity [param] reaches.
  static double peakOf(HapticParam param) => switch (param) {
        ConstantParam(:final value) => value,
        LinearParam(:final from, :final to) => math.max(from, to),
        CurveParam(:final points) => points.isEmpty
            ? 0
            : points.map((p) => p.$2).reduce(math.max),
      };

  /// Average of [param] across its event — a good single number for a
  /// colour or a label.
  static double meanOf(HapticParam param) {
    const samples = 12;
    var sum = 0.0;
    for (var i = 0; i <= samples; i++) {
      sum += valueAt(param, i / samples);
    }
    return sum / (samples + 1);
  }

  static double _interpolate(List<(double, double)> points, double t) {
    if (points.isEmpty) return 0;
    if (t <= points.first.$1) return points.first.$2;
    for (var i = 1; i < points.length; i++) {
      final (t0, v0) = points[i - 1];
      final (t1, v1) = points[i];
      if (t <= t1) {
        final span = t1 - t0;
        if (span <= 0) return v1;
        return v0 + (v1 - v0) * ((t - t0) / span);
      }
    }
    return points.last.$2;
  }
}
