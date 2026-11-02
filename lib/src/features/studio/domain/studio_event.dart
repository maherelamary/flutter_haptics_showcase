import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_haptics/flutter_haptics.dart';

/// What a Studio event is: a single tap, or a sustained rumble.
enum StudioEventKind {
  tap,
  rumble;

  String get label => switch (this) {
        StudioEventKind.tap => 'Tap',
        StudioEventKind.rumble => 'Rumble',
      };
}

/// The intensity shapes a rumble can take. Each is scaled so the event's
/// intensity is its peak.
enum StudioCurve {
  flat,
  fadeIn,
  fadeOut,
  rampUp,
  rampDown,
  pulse,
  spike;

  String get label => switch (this) {
        StudioCurve.flat => 'flat',
        StudioCurve.fadeIn => 'fade in',
        StudioCurve.fadeOut => 'fade out',
        StudioCurve.rampUp => 'ramp up',
        StudioCurve.rampDown => 'ramp down',
        StudioCurve.pulse => 'pulse',
        StudioCurve.spike => 'spike',
      };

  /// The curve as a package parameter, peaking at [peak]. Mirrors the
  /// `HapticParam` presets of the same names.
  HapticParam toParam(double peak) => switch (this) {
        StudioCurve.flat => ConstantParam(peak),
        StudioCurve.fadeIn => LinearParam(from: 0, to: peak),
        StudioCurve.fadeOut => LinearParam(from: peak, to: 0),
        StudioCurve.rampUp => LinearParam(from: 0.3 * peak, to: peak),
        StudioCurve.rampDown => LinearParam(from: peak, to: 0.3 * peak),
        StudioCurve.pulse => CurveParam([(0.0, 0.0), (0.5, peak), (1.0, 0.0)]),
        StudioCurve.spike => CurveParam([(0.0, 0.0), (0.15, peak), (1.0, 0.0)]),
      };
}

/// One event on the Studio timeline.
///
/// Timing is relative: [gapMs] is the silence after the previous event ends
/// (for the first event, the offset from the start). That keeps reordering
/// and resizing predictable — nothing downstream needs recalculating.
@immutable
class StudioEvent {
  const StudioEvent({
    required this.id,
    required this.kind,
    this.gapMs = 0,
    this.intensity = 0.7,
    this.sharpness = 0.5,
    this.durationMs = 240,
    this.curve = StudioCurve.flat,
  });

  /// Reads what [toJson] wrote, pulling values back into the Studio's
  /// ranges. Throws [FormatException] for anything else.
  factory StudioEvent.fromJson(Object? json) {
    if (json
        case {
          'id': final int id,
          'kind': final String kind,
          'gapMs': final int gapMs,
          'intensity': final num intensity,
          'sharpness': final num sharpness,
          'durationMs': final int durationMs,
          'curve': final String curve,
        }) {
      final eventKind = StudioEventKind.values.asNameMap()[kind];
      final eventCurve = StudioCurve.values.asNameMap()[curve];
      if (eventKind != null && eventCurve != null) {
        return StudioEvent(
          id: id,
          kind: eventKind,
          gapMs: math.max(0, gapMs),
          intensity: intensity.toDouble().clamp(0.0, 1.0),
          sharpness: sharpness.toDouble().clamp(0.0, 1.0),
          durationMs: durationMs.clamp(minDurationMs, maxDurationMs),
          curve: eventCurve,
        );
      }
    }
    throw FormatException('Not a Studio event: $json');
  }

  /// Shortest and longest rumble the Studio offers.
  static const minDurationMs = 20;
  static const maxDurationMs = 2000;

  final int id;
  final StudioEventKind kind;

  /// Silence before this event, after the previous one ends.
  final int gapMs;

  /// 0–1. For a rumble, the peak of its [curve].
  final double intensity;

  /// 0–1, dull to crisp.
  final double sharpness;

  /// Rumble length. Ignored for taps.
  final int durationMs;

  /// Rumble shape. Ignored for taps.
  final StudioCurve curve;

  bool get isTap => kind == StudioEventKind.tap;

  /// How long this event occupies the timeline. A tap counts as the
  /// package's nominal transient width, exactly as `HapticPatternBuilder`
  /// advances its cursor.
  int get widthMs =>
      isTap ? HapticEvent.transientWidth.inMilliseconds : durationMs;

  /// "Tap" or "Rumble · fade out".
  String get title => isTap ? kind.label : '${kind.label} · ${curve.label}';

  Map<String, Object?> toJson() => {
        'id': id,
        'kind': kind.name,
        'gapMs': gapMs,
        'intensity': intensity,
        'sharpness': sharpness,
        'durationMs': durationMs,
        'curve': curve.name,
      };

  StudioEvent copyWith({
    int? id,
    StudioEventKind? kind,
    int? gapMs,
    double? intensity,
    double? sharpness,
    int? durationMs,
    StudioCurve? curve,
  }) =>
      StudioEvent(
        id: id ?? this.id,
        kind: kind ?? this.kind,
        gapMs: gapMs ?? this.gapMs,
        intensity: intensity ?? this.intensity,
        sharpness: sharpness ?? this.sharpness,
        durationMs: durationMs ?? this.durationMs,
        curve: curve ?? this.curve,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudioEvent &&
          id == other.id &&
          kind == other.kind &&
          gapMs == other.gapMs &&
          intensity == other.intensity &&
          sharpness == other.sharpness &&
          durationMs == other.durationMs &&
          curve == other.curve;

  @override
  int get hashCode => Object.hash(
        id,
        kind,
        gapMs,
        intensity,
        sharpness,
        durationMs,
        curve,
      );
}
