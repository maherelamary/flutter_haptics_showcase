import 'package:flutter_haptics_showcase/src/core/haptics/haptics_providers.dart';
import 'package:flutter_haptics_showcase/src/features/studio/presentation/providers/studio_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<SharedPreferences> prefsWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  ProviderContainer launch(SharedPreferences prefs) {
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> settle() => Future<void>.delayed(StudioNotifier.saveDelay * 2);

  test('opening the Studio writes nothing until something changes', () async {
    final prefs = await prefsWith({});

    launch(prefs).read(studioProvider);
    await settle();

    expect(prefs.getString(StudioNotifier.storageKey), isNull);
  });

  test('a draft it cannot read is kept, not overwritten', () async {
    const damaged = '{"version": 999, "events": "none"}';
    final prefs = await prefsWith({StudioNotifier.storageKey: damaged});

    final container = launch(prefs);
    expect(container.read(studioProvider).events, isNotEmpty); // the starter
    await settle();

    expect(prefs.getString(StudioNotifier.storageKey), damaged);
    expect(prefs.getString(StudioNotifier.unreadableKey), damaged);

    container.read(studioProvider.notifier).rename('Edited');
    await settle();
    expect(prefs.getString(StudioNotifier.unreadableKey), damaged);
  });
}
