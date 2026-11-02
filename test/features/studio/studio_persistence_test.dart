import 'dart:convert';

import 'package:flutter_haptics_showcase/src/core/haptics/haptics_providers.dart';
import 'package:flutter_haptics_showcase/src/features/studio/domain/studio_draft.dart';
import 'package:flutter_haptics_showcase/src/features/studio/domain/studio_event.dart';
import 'package:flutter_haptics_showcase/src/features/studio/presentation/providers/studio_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('StudioDraft JSON', () {
    test('reads back what it writes', () {
      final draft = StudioDraft(
        name: 'Heartbeat',
        loop: true,
        events: [
          const StudioEvent(id: 4, kind: StudioEventKind.tap, sharpness: 0.9),
          for (final (i, curve) in StudioCurve.values.indexed)
            StudioEvent(
              id: 10 + i,
              kind: StudioEventKind.rumble,
              gapMs: 35,
              intensity: 0.65,
              durationMs: 420,
              curve: curve,
            ),
        ],
      );
      final json = jsonDecode(jsonEncode(draft.toJson()));
      expect(StudioDraft.fromJson(json), draft);
    });

    test('rejects another version, or anything that is not a draft', () {
      final json = const StudioDraft().toJson();
      for (final bad in [
        {...json, 'version': StudioDraft.jsonVersion + 1},
        {...json, 'events': 'none'},
        <String, Object?>{'name': 'Untitled'},
        'a string',
        null,
      ]) {
        expect(
          () => StudioDraft.fromJson(bad),
          throwsFormatException,
          reason: '$bad',
        );
      }
    });

    test('rejects an event of an unknown kind or curve', () {
      final event = const StudioEvent(id: 0, kind: StudioEventKind.tap).toJson();
      for (final bad in [
        {...event, 'kind': 'buzz'},
        {...event, 'curve': 'wobble'},
        {...event, 'gapMs': '60'},
      ]) {
        expect(() => StudioEvent.fromJson(bad), throwsFormatException);
      }
    });

    test('pulls values back into the Studio ranges', () {
      final event = StudioEvent.fromJson({
        ...const StudioEvent(id: 0, kind: StudioEventKind.rumble).toJson(),
        'gapMs': -5,
        'intensity': 1.4,
        'sharpness': -0.2,
        'durationMs': 9000,
      });
      expect(event.gapMs, 0);
      expect(event.intensity, 1.0);
      expect(event.sharpness, 0.0);
      expect(event.durationMs, StudioEvent.maxDurationMs);
    });
  });

  group('StudioNotifier', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    ProviderContainer launch() {
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      return container;
    }

    Future<void> settle() =>
        Future<void>.delayed(StudioNotifier.saveDelay * 2);

    test('opens the starter draft on a first launch', () {
      final draft = launch().read(studioProvider);
      expect(draft.name, 'Untitled');
      expect(draft.events, hasLength(3));
    });

    test('restores the draft from the last launch', () async {
      final first = launch();
      first.read(studioProvider.notifier)
        ..rename('Knock knock')
        ..add(StudioEventKind.rumble)
        ..setLoop(true);
      final edited = first.read(studioProvider);
      await settle();

      expect(launch().read(studioProvider), edited);
    });

    test('keeps ids unique after a restore', () async {
      final first = launch();
      first.read(studioProvider.notifier).add(StudioEventKind.tap);
      final saved = first.read(studioProvider).events.map((e) => e.id);
      await settle();

      final id = launch().read(studioProvider.notifier).add(StudioEventKind.tap);
      expect(saved, isNot(contains(id)));
    });

    test('restores a cleared timeline as cleared', () async {
      launch().read(studioProvider.notifier).clear();
      await settle();

      expect(launch().read(studioProvider).events, isEmpty);
    });

    test('saves a pending edit when it is disposed', () {
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      container.read(studioProvider.notifier).rename('Last second');
      container.dispose();

      expect(launch().read(studioProvider).name, 'Last second');
    });

    test('opens the starter draft when the saved one is damaged', () async {
      await prefs.setString(StudioNotifier.storageKey, '{"version": 1, "na');
      expect(launch().read(studioProvider).events, hasLength(3));
    });
  });
}
