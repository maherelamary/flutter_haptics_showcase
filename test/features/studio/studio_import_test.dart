import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/features/studio/domain/studio_codegen.dart';
import 'package:flutter_haptics_showcase/src/features/studio/domain/studio_draft.dart';
import 'package:flutter_haptics_showcase/src/features/studio/domain/studio_event.dart';
import 'package:flutter_haptics_showcase/src/features/studio/domain/studio_import.dart';
import 'package:flutter_test/flutter_test.dart';

/// A draft's events with the ids zeroed, since an import assigns new ones.
List<StudioEvent> _shape(Iterable<StudioEvent> events) =>
    [for (final e in events) e.copyWith(id: 0)];

/// Exports [draft] as AHAP and imports it back as Studio events.
List<StudioEvent> _roundTrip(StudioDraft draft) {
  final imported = StudioImport.ahap(StudioCodegen.ahap(draft).json!);
  var id = 0;
  return StudioDraft.eventsFromPattern(imported.pattern!, () => id++);
}

void main() {
  group('StudioImport.ahap', () {
    test('reads a valid file', () {
      final result = StudioImport.ahap('''
{
  "Version": 1,
  "Pattern": [
    {"Event": {"Time": 0.0, "EventType": "HapticTransient"}},
    {"Event": {"Time": 0.1, "EventType": "HapticContinuous",
               "EventDuration": 0.2}}
  ]
}''');
      expect(result.error, isNull);
      expect(result.pattern!.events, [
        isA<TransientEvent>(),
        isA<ContinuousEvent>(),
      ]);
    });

    test('rejects an empty clipboard', () {
      for (final text in ['', '  \n\t ']) {
        final result = StudioImport.ahap(text);
        expect(result.pattern, isNull);
        expect(result.error, startsWith('The clipboard is empty'));
      }
    });

    test('rejects text that is not JSON', () {
      final result = StudioImport.ahap('{"Pattern": [');
      expect(result.pattern, isNull);
      expect(result.error, startsWith('Not valid AHAP: Not valid JSON'));
    });

    test('rejects JSON that is not AHAP', () {
      expect(
        StudioImport.ahap('[1, 2]').error,
        'Not valid AHAP: AHAP root must be a JSON object.',
      );
      expect(
        StudioImport.ahap('{"Pattern": "taps"}').error,
        'Not valid AHAP: AHAP is missing its "Pattern" array.',
      );
    });

    test('rejects a file with nothing to feel', () {
      for (final text in [
        '{"Pattern": []}',
        '{"Pattern": [{"Event": {"Time": 0, "EventType": "AudioCustom"}}]}',
      ]) {
        final result = StudioImport.ahap(text);
        expect(result.pattern, isNull, reason: text);
        expect(result.error, startsWith('That AHAP has no haptic events'));
      }
    });

    test('ignores fields it does not know', () {
      final result = StudioImport.ahap('''
{
  "Version": 1,
  "Vendor": {"Tool": "elsewhere"},
  "Pattern": [
    {"Event": {"Time": 0, "EventType": "HapticTransient", "Color": "red"}},
    {"Parameter": {"ParameterID": "HapticIntensityControl",
                   "ParameterValue": 0.5, "Time": 0}}
  ]
}''');
      expect(result.error, isNull);
      expect(result.pattern!.events, hasLength(1));
    });
  });

  group('AHAP round trip', () {
    test('keeps a Studio draft as it was', () {
      final draft = StudioDraft(
        events: [
          const StudioEvent(
            id: 0,
            kind: StudioEventKind.tap,
            intensity: 0.8,
            sharpness: 0.75,
          ),
          for (final (i, curve) in StudioCurve.values.indexed)
            StudioEvent(
              id: i + 1,
              kind: StudioEventKind.rumble,
              gapMs: 40,
              intensity: 0.6,
              sharpness: 0.4,
              durationMs: 200,
              curve: curve,
            ),
          const StudioEvent(
            id: 99,
            kind: StudioEventKind.tap,
            gapMs: 30,
            intensity: 0.5,
            sharpness: 0.3,
          ),
        ],
      );
      expect(_shape(_roundTrip(draft)), _shape(draft.events));
    });

    test('keeps back-to-back rumbles apart', () {
      const draft = StudioDraft(
        events: [
          StudioEvent(
            id: 0,
            kind: StudioEventKind.rumble,
            intensity: 0.6,
            durationMs: 200,
          ),
          StudioEvent(
            id: 1,
            kind: StudioEventKind.rumble,
            intensity: 0.5,
            durationMs: 300,
            curve: StudioCurve.fadeOut,
          ),
        ],
      );
      expect(_shape(_roundTrip(draft)), _shape(draft.events));
    });
  });

  group('StudioDraft.eventsFromPattern approximates', () {
    test('by pulling overlapping events apart', () {
      final pattern = HapticPattern([
        const TransientEvent(intensity: 0.9),
        ContinuousEvent(
          intensity: 0.5,
          duration: const Duration(milliseconds: 100),
        ),
      ]);
      var id = 0;
      final draft = StudioDraft(
        events: StudioDraft.eventsFromPattern(pattern, () => id++),
      );

      expect(draft.events.map((e) => e.kind), [
        StudioEventKind.tap,
        StudioEventKind.rumble,
      ]);
      final [tap, rumble] = draft.spans;
      expect(rumble.startMs, tap.endMs);
    });

    test('by clamping rumbles to the Studio range', () {
      final pattern = HapticPattern([
        ContinuousEvent(
          intensity: 0.5,
          duration: const Duration(milliseconds: 5),
        ),
        ContinuousEvent(
          intensity: 0.5,
          duration: const Duration(seconds: 3),
          delay: const Duration(milliseconds: 100),
        ),
      ]);
      var id = 0;
      final events = StudioDraft.eventsFromPattern(pattern, () => id++);

      expect(events.map((e) => e.durationMs), [
        StudioEvent.minDurationMs,
        StudioEvent.maxDurationMs,
      ]);
    });

    test('by fitting an arbitrary curve to the nearest Studio curve', () {
      const pattern = HapticPattern([
        ContinuousEvent.curved(
          intensity: HapticParam.curve([(0.0, 0.0), (0.45, 0.7), (1.0, 0.1)]),
          duration: Duration(milliseconds: 300),
        ),
      ]);
      var id = 0;
      final [event] = StudioDraft.eventsFromPattern(pattern, () => id++);

      expect(event.curve, StudioCurve.pulse);
      expect(event.intensity, 0.7);
    });
  });
}
