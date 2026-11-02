# flutter_haptics 1.0 API reference

`import 'package:flutter_haptics/flutter_haptics.dart';` (tests: also `package:flutter_haptics/testing.dart`)

## FlutterHaptics (static)

| Member | Notes |
|---|---|
| `Future<HapticRoute> play(HapticPattern)` | Renders your pattern on any platform, degrading by tier. An empty pattern is a no-op. |
| `Future<HapticRoute> playSystem(SystemHaptic)` | One platform's constant, on that platform only. **Never falls back.** Other platform or old OS → `none`. |
| `Future<HapticRoute> perform(HapticIntent)` | Does what this platform's `HapticArm` says: `native` → `system`, or the pattern if declined; `pattern` → the pattern without asking; `silent` → `none`, never reported. On actuators without amplitude control or primitives, a native arm is declined and the pattern plays. |
| `HapticHandle register(HapticPattern, {Duration? minInterval})` | **Synchronous.** The platform prepares a copy in the background (a `play()` that arrives first waits for it); replays are cheap and **paced** — see HapticHandle. Always usable (`isPrepared` may be false). `dispose()` when done. Patterns only: intents and constants can't be registered yet. |
| `Future<void> prepare()` | Warms the iOS engine; no-op on Android. Call once at startup. |
| `Future<void> stop()` | Stops whatever is playing. Works even while `enabled` is false. |
| `Future<HapticSupport> support` | Cached for the app's lifetime. Never throws (web/desktop → `unsupported`). |
| `Future<bool> isSupported` | `support.isSupported`. |
| `bool enabled` | App-wide switch (default `true`). False → every verb returns `none`. Not persisted. |
| `HapticFailureMode onFailure` | `silent` / `log` / `throwIt` (throws `HapticFailure`). Default: `log` in debug, `silent` in release. `log` reports each distinct failure **once per run**; `throwIt` always throws. Switched-off and `silent` arms are never reported. |
| `HapticFailureReporter? onFailureReport` | `void Function(HapticFailure)`. When set, **replaces** `onFailure`: nothing is printed or thrown. Called once per distinct failure. For crash reporters in release. |
| `debugResetSupportCache()` | `@visibleForTesting`: clears the cached `support`. |
| `debugResetFailureLog()` | `@visibleForTesting`: forgets which failures were reported. |

`HapticFailure` (an `Exception`): `request` and `reason` (strings), plus `pattern` or `haptic` — the thing that didn't play, since two patterns can describe themselves identically.

`HapticRoute`: `system` (the OS constant played) · `pattern` (a pattern played) · `none`.

## HapticSupport / HapticFidelity

- `fidelity`: `none < rhythm < intensity < full`; `fidelity.atLeast(other)`.
- `supportsContinuous`: whether a rumble can sustain. False on the iPhone 7 UIKit fallback and on iPad.
- `isSupported`, `supportsIntensity` (≥ intensity), `supportsSharpness` (full).
- `HapticSupport.unsupported`; `const HapticSupport(fidelity:, supportsContinuous:)`.

Where each tier comes from:

| Tier | Hardware |
|---|---|
| `full` | iOS Core Haptics (iPhone 8+), Android 16 envelope hardware |
| `intensity` | iPhone 7 UIKit generators (taps only), Android 11+ composition primitives, Android 8+ amplitude waveform |
| `rhythm` | on/off waveform (ERM motors, any API), every Android 7 device |
| `none` | no vibrator, iPad, web, desktop |

## HapticIntent and HapticArm

```dart
const HapticIntent({
  required HapticArm<IOSHaptic> ios,
  required HapticArm<AndroidHaptic> android,
  required HapticPattern pattern,
});

const HapticArm.native(IOSHaptic.selection)  // the constant; recover with pattern if undelivered
const HapticArm.pattern()                    // the pattern, by choice
const HapticArm.silent()                     // nothing, by choice

intent.armFor(TargetPlatform.android)        // HapticArm<SystemHaptic>?; null off iOS/Android
```

- `HapticArm` is sealed: `NativeArm` (with `.haptic`), `PatternArm`, `SilentArm`, so a `switch` over an arm is exhaustive.
- The arms are typed; `ios: HapticArm.native(AndroidHaptic.x)` does not compile.
- A chosen pattern and a recovered one both return `HapticRoute.pattern`; the intent says which.
- With Dart 3.10+ dot shorthands, `ios: .native(IOSHaptic.selection)` also works where the context type is known.

## IOSHaptic (9, all available on iOS 15)

`impactLight`, `impactMedium`, `impactHeavy`, `impactRigid`, `impactSoft`, `notificationSuccess`, `notificationWarning`, `notificationError`, `selection`.

## AndroidHaptic (20) and minimum API

| Constant | API | Meaning |
|---|---|---|
| `longPress` | 3 | long press completed (heaviest) |
| `virtualKey` | 5 | on-screen key down |
| `keyboardTap` | 8 | keyboard key (same effect as `keyboardPress`) |
| `clockTick` | 21 | picker step |
| `contextClick` | 23 | firm confirmation press |
| `keyboardPress` / `keyboardRelease` | 27 | key down / up |
| `virtualKeyRelease` | 27 | on-screen key up |
| `textHandleMove` | 27 | dragging a selection handle |
| `confirm` / `reject` | 30 | action accepted / refused |
| `gestureStart` / `gestureEnd` | 30 | gesture begins / completes |
| `dragStart` | 34 | drag picks something up |
| `gestureThresholdActivate` / `Deactivate` | 34 | crossing the commit point / falling back |
| `segmentTick` / `segmentFrequentTick` | 34 | slider notch / close-spaced notch |
| `toggleOn` / `toggleOff` | 34 | switch on / off |

`NO_HAPTICS` is deliberately absent. There is no warning constant.

## HapticPattern

```dart
const HapticPattern(List<HapticEvent> events)
HapticPattern.single(event)
HapticPattern.forPlatform({required HapticPattern ios, HapticPattern? android}) // resolved at creation
HapticPattern.empty
pattern.duration                 // closing tap counts 25 ms (HapticEvent.transientWidth)
pattern.then(other)  / a + b     // sequential
pattern.overlay(other) / a | b   // simultaneous; Android envelope/waveform tiers flatten (loudest wins),
                                 // tap-only patterns on the primitive tier play overlapping taps back-to-back
pattern.repeat(n, gap: d)
pattern.scaled(0.5)              // intensity only
```

Patterns compare by value. All built-in patterns are `const`.

## Events and parameters

```dart
const TransientEvent({required double intensity, double sharpness = 0.5, Duration delay = Duration.zero})
ContinuousEvent({required double intensity, required Duration duration, double sharpness = 0.5, Duration delay})  // NOT const
const ContinuousEvent.curved({required HapticParam intensity, required Duration duration,
    HapticParam sharpness = const ConstantParam(0.5), Duration delay})
```

`delay` is measured from the start of the pattern. All values are 0.0–1.0.

```dart
HapticParam.constant(v) / ConstantParam(v)
HapticParam.linear(from:, to:) / LinearParam(from:, to:)
HapticParam.curve([(t, v), …]) / CurveParam([...])   // t, v in 0..1
```

| Preset | Shape |
|---|---|
| `HapticParam.fadeIn` | 0 → 1 |
| `HapticParam.fadeOut` | 1 → 0 |
| `HapticParam.rampUp` | 0.3 → 1 |
| `HapticParam.rampDown` | 1 → 0.3 |
| `HapticParam.pulse` | 0 → 1 → 0 |
| `HapticParam.spike` | quick rise, long decay |

## HapticPatternBuilder

```dart
HapticPatternBuilder()
  .tap({intensity = 0.7, sharpness = 0.5})          // advances cursor 25 ms
  .rumble({required duration, intensity = 0.7, sharpness = 0.5})
  .rumbleCurved({required duration, required HapticParam intensity, HapticParam sharpness})
  .fadeIn({required duration, sharpness}) .fadeOut(…) .pulse(…)
  .wait(Duration) .waitMs(int)
  .build();
```

## HapticPatterns (built-in)

| Group | Patterns |
|---|---|
| Taps | `lightTap` (0.4), `mediumTap` (0.7), `heavyTap` (1.0), `soft` (0.7 / 0.2), `rigid` (0.7 / 1.0) |
| UI | `selection`, `doubleClick` (100 ms), `tripleClick` (80 ms steps) |
| Notifications | `success` (3 rising taps), `warning` (2 taps), `error` (3 strong taps) |
| Expressive | `heartbeat` (130 ms), `buzz` / `longBuzz` (100 / 300 ms) |
| Curved | `explosion` (400 ms fade-out), `engineRev` (600 ms), `pulseWave` (400 ms), `impactDecay`, `chargeUp` (800 ms) |

## HapticHandle

From `FlutterHaptics.register(pattern, {minInterval})`, synchronously.

| Member | Notes |
|---|---|
| `play()` | `HapticRoute`. Obeys `enabled`. Returns `none` if it falls within `minInterval` of the last play (dropped, not delayed), or after `dispose()`. Falls back to `play(pattern)` where the platform can't hold a copy, has lost it, or won't replay it this time. |
| `minInterval` | The pacing floor in force. Default from `support.fidelity`: `full` 25 ms, `intensity` 35 ms, `rhythm` 60 ms; 40 ms until support resolves. Pass `Duration.zero` to fire every call. |
| `ready` | `Future<void>`: completes once registration and `minInterval` have settled. Never errors. Only needed to *display* them. |
| `isPrepared` / `isDisposed` / `pattern` | `isPrepared` is false while registering, where the platform can't hold one, or after a lost registration. |
| `dispose()` | Releases the native copy. Safe to call twice. |

Pacing uses `package:clock`, which `testWidgets` advances when you pump a duration.

## Ahap

| Member | Notes |
|---|---|
| `Ahap.decode(String)` | Throws `FormatException` on invalid input. Numbers written as strings are read; NaN and infinities are treated as absent. |
| `Ahap.decodeMap(map)` | Same, from an already-decoded map. |
| `Ahap.loadAsset(key, {bundle})` | Reads an asset and decodes it. |
| `Ahap.encode(pattern, {metadata, pretty = true})` | Throws `StateError` when a curve has more than 16 points, which Core Haptics would cut short in a file. Playback has no such limit: iOS chains a longer curve. |
| `Ahap.encodeMap(pattern, {metadata})` | Same, as a map. |
| `Ahap.maxControlPoints` | 16 |

Audio events and standalone `Parameter` entries are dropped. Control-point times are relative to their curve's own `Time`, and curves modulate their event's value (both handled for you).

AHAP curves apply to the whole pattern, not to one event, so two things don't round-trip:

- **Encoding** a tap that overlaps a curved rumble writes a file where the rumble's curve also shapes the tap, until a reset at the rumble's end. `encode` doesn't refuse it.
- **Decoding** a curve that shapes several taps (common in Apple-authored files) gives those taps a flat strength.

Keep taps clear of curved rumbles in patterns you plan to export.

## Testing: FakeHapticsPlatform

```dart
FlutterHapticsPlatform.instance = FakeHapticsPlatform(
  support: const HapticSupport(fidelity: HapticFidelity.full, supportsContinuous: true),
  playsSystemHaptics: true,   // false → an OS too old for the constant: intents recover
  canRegister: true,          // false → handles are unprepared but still play
  declineReason: '…',
);
tearDown(FlutterHapticsPlatform.reset);
```

The fake behaves like the device `support` describes:

- `rhythm` (no amplitude control): `perform` declines constants and recovers with the pattern; `playSystem` still plays them.
- `HapticSupport.unsupported`: every pattern fails.
- `supportsContinuous: false`: a pattern with no taps fails (the iPhone 7 case).

What it records:

- `played` (every pattern *asked for*, including ones it refused) and `systemHaptics` (constants)
- `intents` (every intent given to `perform`, before its arm is resolved, even while haptics are off)
- `requiredPerceptible` (true when the request came from `perform`)
- `registrations`, `replays`, `releases`
- `prepareCount`, `stopCount`
- `lastPlayed`, `lastSystemHaptic`, `lastIntent`
- `clear()` resets all of the above, and leaves live registrations alone
- `debugLoseRegistrations()` drops every live registration, to test a handle that has lost its copy
- `refuseReplays = true` makes replays fail while keeping the registrations, to test a handle riding out an engine that won't play

## FlutterHapticsPlatform (the seam)

`querySupport`, `play`, `playSystem(haptic, requirePerceptible:)`, `register`, `playRegistered` (returns `NativeResult`; `registrationLost: true` tells the handle its copy is gone, and any other failure is retried next time), `unregister`, `prepare`, `stop`, and `noteIntent(intent)` (a no-op by default).

It is also the seam for decorators: an app can wrap it to log every haptic, or show it in a debug overlay. **A wrapper must forward `noteIntent`** and return `playRegistered`'s result unchanged.
