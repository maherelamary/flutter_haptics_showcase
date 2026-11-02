import 'dart:convert';

import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/features/studio/domain/studio_codegen.dart';
import 'package:flutter_haptics_showcase/src/features/studio/domain/studio_draft.dart';
import 'package:flutter_haptics_showcase/src/features/studio/domain/studio_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const draft = StudioDraft(
    name: 'Door knock',
    events: [
      StudioEvent(
        id: 0,
        kind: StudioEventKind.tap,
        intensity: 0.8,
        sharpness: 0.75,
      ),
      StudioEvent(
        id: 1,
        kind: StudioEventKind.rumble,
        gapMs: 60,
        intensity: 0.8,
        sharpness: 0.35,
        durationMs: 280,
        curve: StudioCurve.spike,
      ),
      StudioEvent(
        id: 2,
        kind: StudioEventKind.rumble,
        gapMs: 40,
        intensity: 0.6,
        sharpness: 0.4,
        durationMs: 200,
      ),
    ],
  );

  group('StudioCodegen.dart', () {
    test('writes a builder chain that rebuilds the draft', () {
      expect(StudioCodegen.dart(draft), '''
// Flutter Haptics Tactile Studio · Door knock · 3 events · 605ms
final doorKnock = HapticPatternBuilder()
    .tap(intensity: 0.8, sharpness: 0.75)
    .waitMs(60)
    .rumbleCurved(
      duration: const Duration(milliseconds: 280),
      intensity: const HapticParam.curve([(0.0, 0.0), (0.15, 0.8), (1.0, 0.0)]),
      sharpness: const HapticParam.constant(0.35),
    )
    .waitMs(40)
    .rumble(
      duration: const Duration(milliseconds: 200),
      intensity: 0.6,
      sharpness: 0.4,
    )
    .build();

await FlutterHaptics.play(doorKnock);''');
    });

    test('writes every curve as the matching HapticParam', () {
      for (final curve in StudioCurve.values) {
        final code = StudioCodegen.dart(
          StudioDraft(
            events: [
              StudioEvent(
                id: 0,
                kind: StudioEventKind.rumble,
                intensity: 0.5,
                curve: curve,
              ),
            ],
          ),
        );
        expect(
          code,
          contains(
            curve == StudioCurve.flat
                ? '.rumble('
                : StudioCodegen.param(curve.toParam(0.5)),
          ),
          reason: curve.name,
        );
      }
    });

    test('writes an empty draft as HapticPattern.empty', () {
      expect(StudioCodegen.dart(const StudioDraft()), '''
// Flutter Haptics Tactile Studio · Untitled · 0 events · 0ms
const untitled = HapticPattern.empty;

await FlutterHaptics.play(untitled);''');
    });

    test('counts a single event in the singular', () {
      final code = StudioCodegen.dart(
        const StudioDraft(
          events: [StudioEvent(id: 0, kind: StudioEventKind.tap)],
        ),
      );
      expect(code.split('\n').first, endsWith('· 1 event · 25ms'));
    });
  });

  group('StudioCodegen.number', () {
    test('trims trailing zeros but keeps one decimal', () {
      expect(StudioCodegen.number(0.7), '0.7');
      expect(StudioCodegen.number(1), '1.0');
      expect(StudioCodegen.number(0.35), '0.35');
      // A ramp from 0.3 of a 0.75 peak: two places would print 0.22.
      expect(StudioCodegen.number(0.3 * 0.75), '0.225');
      expect(StudioCodegen.number(0.7000000001), '0.7');
    });
  });

  group('StudioCodegen.ahap', () {
    test('writes valid AHAP with Studio metadata', () {
      final export = StudioCodegen.ahap(draft);
      expect(export.error, isNull);

      final json = jsonDecode(export.json!) as Map<String, Object?>;
      expect(json['Version'], Ahap.version);
      expect(json['Metadata'], containsPair('Description', 'Door knock'));
      expect(json['Metadata'], containsPair('Project', isNotEmpty));
      expect(json['Pattern'], isA<List<Object?>>());
    });

    test('decodes back to the pattern it was written from', () {
      final pattern = Ahap.decode(StudioCodegen.ahap(draft).json!);
      final original = draft.toPattern();

      expect(pattern.events, hasLength(original.events.length));
      expect(pattern.duration, original.duration);
      for (var i = 0; i < original.events.length; i++) {
        expect(pattern.events[i].runtimeType, original.events[i].runtimeType);
        expect(pattern.events[i].start, original.events[i].start);
      }
    });

    test('exports every Studio curve', () {
      for (final curve in StudioCurve.values) {
        final export = StudioCodegen.ahap(
          StudioDraft(
            events: [
              StudioEvent(id: 0, kind: StudioEventKind.rumble, curve: curve),
            ],
          ),
        );
        expect(export.error, isNull, reason: curve.name);
      }
    });

    test('exports an empty draft as an empty pattern', () {
      final export = StudioCodegen.ahap(const StudioDraft());
      expect(export.error, isNull);
      expect(Ahap.decode(export.json!).events, isEmpty);
    });
  });
}
