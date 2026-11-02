# Setting up flutter_haptics in a client app

The examples assume a feature-first layout (`lib/src/{config,core,features}`), Riverpod 3, `shared_preferences` and package imports. Adapt the paths and the import prefix (`package:my_app/...`) to the project.

## 1. Dependency

```yaml
dependencies:
  flutter_haptics: ^1.0.0
  clock: ^1.1.1 # only if the app uses HapticPacer (§7)
```

A `git:` or `path:` dependency works the same while developing against an unreleased version.

Requirements: iOS 15+, Android API 24+ (the plugin never raises `minSdk`), Flutter 3.44+ (the plugin's pubspec says `flutter: '>=3.44.0'`, so an older SDK fails `pub get`). The plugin declares `VIBRATE` itself and needs no Info.plist keys.

## 2. `lib/src/core/haptics/app_haptics.dart`

Start from this and **delete the meanings the app doesn't use**. Rename meanings to the app's own words if that helps (`saved`, `sent`, `checkedIn`). The pairings are the part to keep.

```dart
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:my_app/src/core/haptics/app_patterns.dart';

/// Every meaning this app gives a haptic, and the only file that knows iOS
/// and Android exist. Call sites stay platform-blind:
/// `FlutterHaptics.perform(AppHaptics.press)`.
///
/// Each arm says what that platform does: `native(...)` plays its own
/// constant and recovers with the pattern where it can't be delivered,
/// `pattern()` plays the pattern by choice, `silent()` plays nothing.
///
/// Android API levels are noted where a constant needs more than minSdk 24;
/// below them the pattern plays instead.
abstract final class AppHaptics {
  // Acknowledge
  static const press = HapticIntent(
    ios: HapticArm.native(IOSHaptic.impactMedium),
    android: HapticArm.native(AndroidHaptic.contextClick),
    pattern: HapticPatterns.mediumTap,
  );
  static const tap = HapticIntent(
    ios: HapticArm.native(IOSHaptic.impactLight),
    android: HapticArm.native(AndroidHaptic.virtualKey),
    pattern: HapticPatterns.lightTap,
  );
  static const key = HapticIntent(
    ios: HapticArm.native(IOSHaptic.impactLight),
    android: HapticArm.native(AndroidHaptic.keyboardTap),
    pattern: AppPatterns.keyClick,
  );
  static const longPress = HapticIntent(
    ios: HapticArm.native(IOSHaptic.impactHeavy),
    android: HapticArm.native(AndroidHaptic.longPress),
    pattern: HapticPatterns.heavyTap,
  );

  // Select
  static const tick = HapticIntent(
    ios: HapticArm.native(IOSHaptic.selection),
    android: HapticArm.native(AndroidHaptic.clockTick),
    pattern: HapticPatterns.selection,
  );
  static const detent = HapticIntent(
    ios: HapticArm.native(IOSHaptic.selection),
    android: HapticArm.native(AndroidHaptic.segmentTick), // API 34
    pattern: AppPatterns.detent,
  );
  static const fineDetent = HapticIntent(
    ios: HapticArm.native(IOSHaptic.selection),
    android: HapticArm.native(AndroidHaptic.segmentFrequentTick), // API 34
    pattern: AppPatterns.fineDetent,
  );
  static const limit = HapticIntent(
    ios: HapticArm.native(IOSHaptic.impactRigid),
    android: HapticArm.native(AndroidHaptic.contextClick),
    pattern: AppPatterns.bump,
  );

  // Toggle — iOS has no toggle constant; light vs soft keeps direction felt.
  // For switches that stay quiet on iOS, use `ios: HapticArm.silent()`.
  static const switchOn = HapticIntent(
    ios: HapticArm.native(IOSHaptic.impactLight),
    android: HapticArm.native(AndroidHaptic.toggleOn), // API 34
    pattern: AppPatterns.switchOn,
  );
  static const switchOff = HapticIntent(
    ios: HapticArm.native(IOSHaptic.impactSoft),
    android: HapticArm.native(AndroidHaptic.toggleOff), // API 34
    pattern: AppPatterns.switchOff,
  );

  // Gestures
  static const armed = HapticIntent(
    ios: HapticArm.native(IOSHaptic.impactMedium),
    android: HapticArm.native(AndroidHaptic.gestureThresholdActivate), // API 34
    pattern: HapticPatterns.mediumTap,
  );
  static const disarmed = HapticIntent(
    ios: HapticArm.native(IOSHaptic.impactSoft),
    android: HapticArm.native(AndroidHaptic.gestureThresholdDeactivate), // API 34
    pattern: HapticPatterns.soft,
  );
  static const lift = HapticIntent(
    ios: HapticArm.native(IOSHaptic.impactMedium),
    android: HapticArm.native(AndroidHaptic.dragStart), // API 34
    pattern: HapticPatterns.rigid,
  );
  static const drop = HapticIntent(
    ios: HapticArm.native(IOSHaptic.impactLight),
    android: HapticArm.native(AndroidHaptic.gestureEnd), // API 30
    pattern: HapticPatterns.lightTap,
  );

  // Outcomes
  static const success = HapticIntent(
    ios: HapticArm.native(IOSHaptic.notificationSuccess),
    android: HapticArm.native(AndroidHaptic.confirm), // API 30
    pattern: HapticPatterns.success,
  );
  static const failure = HapticIntent(
    ios: HapticArm.native(IOSHaptic.notificationError),
    android: HapticArm.native(AndroidHaptic.reject), // API 30
    pattern: HapticPatterns.error,
  );

  // Caution — Android names no warning, so its arm plays the pattern by
  // choice. Never borrow an unrelated Android constant to fill the gap.
  static const caution = HapticIntent(
    ios: HapticArm.native(IOSHaptic.notificationWarning),
    android: HapticArm.pattern(),
    pattern: HapticPatterns.warning,
  );
}
```

## 3. `lib/src/core/haptics/app_patterns.dart`

Only the waveforms the app actually needs. Each one should be recognisable by its timing alone.

```dart
import 'package:flutter_haptics/flutter_haptics.dart';

abstract final class AppPatterns {
  static const keyClick = HapticPattern([TransientEvent(intensity: 0.45, sharpness: 0.75)]);
  static const detent = HapticPattern([TransientEvent(intensity: 0.55, sharpness: 0.9)]);
  static const fineDetent = HapticPattern([TransientEvent(intensity: 0.32, sharpness: 0.95)]);
  static const switchOn = HapticPattern([TransientEvent(intensity: 0.7, sharpness: 0.9)]);
  static const switchOff = HapticPattern([TransientEvent(intensity: 0.5, sharpness: 0.2)]);

  /// End stop: a dull thud and a small rebound — "no further".
  static const bump = HapticPattern([
    TransientEvent(intensity: 0.9, sharpness: 0.25),
    TransientEvent(intensity: 0.35, sharpness: 0.2, delay: Duration(milliseconds: 90)),
  ]);

  /// Undo: three taps falling away — success played backwards.
  static const rewind = HapticPattern([
    TransientEvent(intensity: 0.9, sharpness: 0.7),
    TransientEvent(intensity: 0.6, sharpness: 0.5, delay: Duration(milliseconds: 80)),
    TransientEvent(intensity: 0.35, sharpness: 0.3, delay: Duration(milliseconds: 160)),
  ]);

  /// A like or reaction landing: one bright pop. Its reversal is smaller.
  static const pop = HapticPattern([TransientEvent(intensity: 0.85, sharpness: 1.0)]);
  static const unpop = HapticPattern([TransientEvent(intensity: 0.3, sharpness: 0.2)]);

  /// A message leaving: a short swell that brightens as it goes.
  static const whoosh = HapticPattern([
    ContinuousEvent.curved(
      intensity: CurveParam([(0.0, 0.0), (0.35, 0.45), (1.0, 0.0)]),
      sharpness: LinearParam(from: 0.2, to: 0.8),
      duration: Duration(milliseconds: 180),
    ),
  ]);

  /// A bolt sliding home: rigid click, then a heavy seat (hold/slide to confirm).
  static const lock = HapticPattern([
    TransientEvent(intensity: 0.8, sharpness: 1.0),
    TransientEvent(intensity: 1.0, sharpness: 0.3, delay: Duration(milliseconds: 90)),
  ]);

  /// Something heavy landing: one deep hit with a short tail.
  static const thud = HapticPattern([
    TransientEvent(intensity: 1.0, sharpness: 0.15),
    ContinuousEvent.curved(
      intensity: CurveParam([(0.0, 0.5), (1.0, 0.0)]),
      sharpness: ConstantParam(0.1),
      duration: Duration(milliseconds: 90),
    ),
  ]);

  /// The once-per-purchase moment. The only long pattern allowed.
  static const celebrate = HapticPattern([
    TransientEvent(intensity: 0.55, sharpness: 0.5),
    TransientEvent(intensity: 0.75, sharpness: 0.65, delay: Duration(milliseconds: 80)),
    TransientEvent(intensity: 1.0, sharpness: 0.9, delay: Duration(milliseconds: 160)),
    ContinuousEvent.curved(
      intensity: CurveParam([(0.0, 0.0), (0.15, 0.5), (1.0, 0.0)]),
      sharpness: LinearParam(from: 0.8, to: 0.3),
      duration: Duration(milliseconds: 420),
      delay: Duration(milliseconds: 200),
    ),
  ]);
}
```

## 4. `lib/src/core/haptics/haptics_settings.dart`

```dart
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_app/src/core/storage/shared_preferences_provider.dart';

/// The user's Haptics switch, mirrored into the package so no call site ever
/// checks a preference.
class HapticsSettings extends Notifier<bool> {
  static const key = 'haptics.enabled';

  @override
  bool build() {
    final on = ref.watch(sharedPreferencesProvider).getBool(key) ?? true;
    FlutterHaptics.enabled = on;
    return on;
  }

  Future<void> set(bool on) async {
    state = on;
    FlutterHaptics.enabled = on;
    await ref.read(sharedPreferencesProvider).setBool(key, on);
  }
}

final hapticsSettingsProvider =
    NotifierProvider<HapticsSettings, bool>(HapticsSettings.new);

/// What this device can reproduce (cached by the package).
final hapticSupportProvider = FutureProvider<HapticSupport>(
  (ref) => FlutterHaptics.support,
);
```

```dart
// lib/src/core/storage/shared_preferences_provider.dart
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Overridden in main()'),
);
```

## 5. `main.dart` and the root widget

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  // Honour the switch before anything can play.
  FlutterHaptics.enabled = prefs.getBool(HapticsSettings.key) ?? true;
  // Warm the iOS engine so the first tap isn't the slow one (no-op on Android).
  FlutterHaptics.prepare();

  runApp(ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const App(),
  ));
}

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(hapticsSettingsProvider); // keep the switch alive and in sync
    return MaterialApp.router(/* … */);
  }
}
```

Optional: `FlutterHaptics.onFailure = HapticFailureMode.throwIt;` in an integration-test entry point, so a haptic that can't play fails the build. The default logs each distinct failure once in debug and stays silent in release.

Optional, for release builds: send failures to your own logger or crash reporter. It replaces the console and never throws, and each distinct failure arrives once:

```dart
FlutterHaptics.onFailureReport = (failure) {
  // failure.pattern / failure.haptic identify what didn't play.
  logger.info('haptic: $failure');
};
```

## 6. Settings tile

```dart
class HapticsTile extends ConsumerWidget {
  const HapticsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supported = ref.watch(hapticSupportProvider).value?.isSupported ?? true;
    if (!supported) return const SizedBox.shrink(); // nothing to switch on/off

    return SwitchListTile(
      title: const Text('Haptics'),
      value: ref.watch(hapticsSettingsProvider),
      onChanged: (on) async {
        final settings = ref.read(hapticsSettingsProvider.notifier);
        // Feel it go off before disabling; feel it come on after enabling.
        if (!on) await FlutterHaptics.perform(AppHaptics.switchOff);
        await settings.set(on);
        if (on) FlutterHaptics.perform(AppHaptics.switchOn);
      },
    );
  }
}
```

## 7. High-frequency haptics: handles, and a pacer where they can't reach

A registered handle needs no helper: `register` returns it synchronously, and
it paces itself to what the device can separate (25 ms on Core Haptics or an
envelope-capable Android, 35 ms on the intensity tier, 60 ms on a rotary
motor; 40 ms until the device has answered).

```dart
class _PickerState extends State<Picker> {
  // A plain `final`, not `late final`: a lazy field would register on the
  // first play, which is the round trip the handle exists to save.
  final _tick = FlutterHaptics.register(HapticPatterns.selection);

  void _onItemChanged(int _) => _tick.play(); // HapticRoute.none if paced out

  @override
  void dispose() {
    _tick.dispose();
    super.dispose();
  }
}
```

`minInterval:` overrides the floor. Pass `Duration.zero` only when the timing
is the content and is already scheduled: a metronome beat, or the one click in
a puzzle that must never be dropped.

A handle holds a **pattern**. Intents and system constants can't be
registered yet, so two cases still need a pacer:

- an intent fired from a drag (`perform(AppHaptics.fineDetent)` per notch);
- several handles that share one budget (a texture choosing one of five
  handles per grain: each paces only itself).

```dart
import 'package:clock/clock.dart';

/// Keeps drags and loops from flooding the actuator where a handle can't.
/// Below ~40 ms separate taps fuse into a buzz (and smear on rotary motors).
///
/// Reads the time through `package:clock`, as the package's own handles do,
/// so `testWidgets` pumps advance it. A `Stopwatch` measures real time, which
/// a pump does not move, and would drop haptics in widget tests.
class HapticPacer {
  HapticPacer({this.minInterval = const Duration(milliseconds: 40)});

  final Duration minInterval;
  DateTime? _last;

  bool ready() {
    final now = clock.now();
    final last = _last;
    if (last != null) {
      final since = now.difference(last);
      // A clock moved backwards (NTP, a manual change) plays rather than
      // muting the pacer until it catches up.
      if (!since.isNegative && since < minInterval) return false;
    }
    _last = now;
    return true;
  }

  void reset() => _last = null;
}
```

## 8. Test harness

```dart
// test/helpers/haptics_harness.dart
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics/testing.dart';
import 'package:flutter_test/flutter_test.dart';

FakeHapticsPlatform installFakeHaptics({
  bool playsSystemHaptics = true,
  HapticSupport support = const HapticSupport(
    fidelity: HapticFidelity.full,
    supportsContinuous: true,
  ),
}) {
  final fake = FakeHapticsPlatform(
    playsSystemHaptics: playsSystemHaptics,
    support: support,
  );
  FlutterHapticsPlatform.instance = fake;
  FlutterHaptics.enabled = true;
  FlutterHaptics.onFailureReport = null;
  FlutterHaptics.debugResetSupportCache();
  FlutterHaptics.debugResetFailureLog(); // each failure is reported once per run
  addTearDown(FlutterHapticsPlatform.reset);
  return fake;
}
```

```dart
testWidgets('switch feels its direction', (tester) async {
  final haptics = installFakeHaptics();
  await tester.pumpWidget(/* … */);
  await tester.tap(find.byType(Switch));
  await tester.pump();
  expect(haptics.intents, [AppHaptics.switchOn]); // the meaning asked for
  expect(haptics.systemHaptics, [AndroidHaptic.toggleOn]); // what played
}, variant: TargetPlatformVariant.only(TargetPlatform.android));
```

If the app wraps the platform (a tracer, a logger), the wrapper must override
`noteIntent` and forward it, or `haptics.intents` stays empty without error.

Handles and `HapticPacer` pace on the clock `testWidgets` controls. A bare
`tester.pump()` advances it by nothing, so two quick taps on a control that
plays a handle leave the second one paced out. Pump a realistic gap between
them.

## 9. `docs/haptics.md`

Create the app's haptic tune from `references/tune.md`: fill in Character
with the user (or leave the defaults marked as such), copy every
`AppHaptics` / `AppPatterns` entry into Meanings, and seed the Moments map
from the existing call sites:

```
grep -rnE "FlutterHaptics\.(perform|play|playSystem|register)|\.play\(\)" lib/
```
