import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/pattern_math.dart';
import 'package:flutter_haptics_showcase/src/features/studio/domain/studio_event.dart';

/// Where one event sits on the timeline, in milliseconds from the start.
@immutable
class StudioSpan {
  const StudioSpan({required this.id, required this.startMs, required this.endMs});

  final int id;
  final int startMs;
  final int endMs;

  int get centerMs => (startMs + endMs) ~/ 2;
}

/// The pattern being designed: a name, an ordered list of events, and
/// whether playback loops.
@immutable
class StudioDraft {
  const StudioDraft({
    this.name = 'Untitled',
    this.events = const [],
    this.loop = false,
  });

  /// Reads what [toJson] wrote. Throws [FormatException] for anything else,
  /// including a draft saved in another [jsonVersion].
  factory StudioDraft.fromJson(Object? json) {
    if (json
        case {
          'version': jsonVersion,
          'name': final String name,
          'loop': final bool loop,
          'events': final List<Object?> events,
        }) {
      return StudioDraft(
        name: name,
        loop: loop,
        events: [for (final event in events) StudioEvent.fromJson(event)],
      );
    }
    throw const FormatException('Not a version $jsonVersion Studio draft.');
  }

  final String name;
  final List<StudioEvent> events;
  final bool loop;

  /// Bumped whenever [toJson] changes shape; [StudioDraft.fromJson] reads
  /// this version only.
  static const jsonVersion = 1;

  bool get isEmpty => events.isEmpty;

  StudioDraft copyWith({
    String? name,
    List<StudioEvent>? events,
    bool? loop,
  }) =>
      StudioDraft(
        name: name ?? this.name,
        events: events ?? this.events,
        loop: loop ?? this.loop,
      );

  Map<String, Object?> toJson() => {
        'version': jsonVersion,
        'name': name,
        'loop': loop,
        'events': [for (final event in events) event.toJson()],
      };

  /// The draft as a playable pattern, built the way a client app would
  /// write it: with `HapticPatternBuilder`.
  HapticPattern toPattern() {
    if (events.isEmpty) return HapticPattern.empty;
    final builder = HapticPatternBuilder();
    for (final event in events) {
      if (event.gapMs > 0) builder.waitMs(event.gapMs);
      switch (event.kind) {
        case StudioEventKind.tap:
          builder.tap(intensity: event.intensity, sharpness: event.sharpness);
        case StudioEventKind.rumble:
          builder.rumbleCurved(
            duration: Duration(milliseconds: event.durationMs),
            intensity: event.curve.toParam(event.intensity),
            sharpness: ConstantParam(event.sharpness),
          );
      }
    }
    return builder.build();
  }

  /// Each event's place on the timeline, in order.
  List<StudioSpan> get spans {
    final result = <StudioSpan>[];
    var cursor = 0;
    for (final event in events) {
      final start = cursor + event.gapMs;
      final end = start + event.widthMs;
      result.add(StudioSpan(id: event.id, startMs: start, endMs: end));
      cursor = end;
    }
    return result;
  }

  /// A pattern of just [event], starting at zero — for auditioning one
  /// event and drawing it on its own.
  static HapticPattern single(StudioEvent event) =>
      StudioDraft(events: [event.copyWith(gapMs: 0)]).toPattern();

  /// Turns any pattern into Studio events. **Approximate** by design:
  ///
  /// - Events are laid end to end in start order. Overlapping events (an
  ///   `overlay`, a tap on top of a rumble) are pulled apart, since the
  ///   Studio timeline is sequential.
  /// - A rumble's intensity curve becomes the nearest Studio curve, peaking
  ///   at the curve's peak; its sharpness becomes its mean.
  /// - Rumble lengths are clamped to the Studio's 20–2000 ms range.
  ///
  /// Good enough to start from a library pattern or an imported `.ahap`
  /// and keep designing; not a lossless round trip.
  static List<StudioEvent> eventsFromPattern(
    HapticPattern pattern,
    int Function() nextId,
  ) {
    // Stable sort by start time: List.sort is not guaranteed stable.
    final indexed = [
      for (var i = 0; i < pattern.events.length; i++) (i, pattern.events[i]),
    ]..sort((a, b) {
        final byStart = a.$2.start.compareTo(b.$2.start);
        return byStart != 0 ? byStart : a.$1.compareTo(b.$1);
      });

    final result = <StudioEvent>[];
    var previousEnd = 0;
    for (final (_, event) in indexed) {
      final gap = math.max(0, event.start.inMilliseconds - previousEnd);
      switch (event) {
        case TransientEvent():
          result.add(
            StudioEvent(
              id: nextId(),
              kind: StudioEventKind.tap,
              gapMs: gap,
              intensity: _unit(event.intensity),
              sharpness: _unit(event.sharpness),
            ),
          );
          previousEnd = math.max(previousEnd, event.start.inMilliseconds) +
              HapticEvent.transientWidth.inMilliseconds;
        case ContinuousEvent():
          final curve = nearestCurve(event.intensity);
          final peak = PatternMath.peakOf(event.intensity);
          final duration = math.min(
            StudioEvent.maxDurationMs,
            math.max(StudioEvent.minDurationMs, event.duration.inMilliseconds),
          );
          result.add(
            StudioEvent(
              id: nextId(),
              kind: StudioEventKind.rumble,
              gapMs: gap,
              intensity: _unit(
                curve == StudioCurve.flat
                    ? PatternMath.meanOf(event.intensity)
                    : peak,
              ),
              sharpness: _unit(PatternMath.meanOf(event.sharpness)),
              durationMs: duration,
              curve: curve,
            ),
          );
          previousEnd =
              math.max(previousEnd, event.start.inMilliseconds) + duration;
      }
    }
    return result;
  }

  /// The Studio curve whose shape is closest to [param], by squared error
  /// over 21 samples with both scaled to the same peak.
  static StudioCurve nearestCurve(HapticParam param) {
    if (param is ConstantParam) return StudioCurve.flat;
    final peak = PatternMath.peakOf(param);
    if (peak <= 0) return StudioCurve.flat;

    var best = StudioCurve.flat;
    var bestError = double.infinity;
    for (final curve in StudioCurve.values) {
      final candidate = curve.toParam(peak);
      var error = 0.0;
      for (var i = 0; i <= 20; i++) {
        final t = i / 20;
        final d = PatternMath.valueAt(candidate, t) -
            PatternMath.valueAt(param, t);
        error += d * d;
      }
      if (error < bestError - 1e-9) {
        best = curve;
        bestError = error;
      }
    }
    return best;
  }

  static double _unit(double value) =>
      (value.clamp(0.0, 1.0) * 100).round() / 100;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudioDraft &&
          name == other.name &&
          loop == other.loop &&
          listEquals(events, other.events);

  @override
  int get hashCode => Object.hash(name, loop, Object.hashAll(events));
}
