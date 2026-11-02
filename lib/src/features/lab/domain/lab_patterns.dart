import 'package:flutter_haptics/flutter_haptics.dart';

/// Small builders the Lab experiments share.
abstract final class LabPatterns {
  /// A single tap at the given strength and crispness.
  static HapticPattern tap(double intensity, double sharpness) => HapticPattern(
    [TransientEvent(intensity: intensity, sharpness: sharpness)],
  );

  /// [count] taps evenly spread from [from] to [to] intensity — a ladder of
  /// prepared strengths for effects whose strength varies continuously.
  static List<HapticPattern> ladder({
    required int count,
    required double from,
    required double to,
    required double sharpness,
    double? sharpnessTo,
  }) => [
    for (var i = 0; i < count; i++)
      tap(
        from + (to - from) * (count == 1 ? 1 : i / (count - 1)),
        sharpnessTo == null
            ? sharpness
            : sharpness +
                  (sharpnessTo - sharpness) *
                      (count == 1 ? 1 : i / (count - 1)),
      ),
  ];
}
