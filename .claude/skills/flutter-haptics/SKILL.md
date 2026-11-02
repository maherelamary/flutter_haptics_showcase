---
name: flutter-haptics
description: Use when adding, reviewing or designing haptic feedback in a Flutter app that uses the flutter_haptics package (1.0+) — buttons, switches, sliders, pickers, gestures, forms, async results, onboarding, checkout, games — and whenever a new feature or screen is built in such an app, to decide which moments get which haptic. Reads and maintains the app's haptic tune (docs/haptics.md: its character, meanings, moments map and decisions). Covers the three verbs (play / playSystem / perform), HapticArm intents in the per-app AppHaptics file, paced handles from register(), Riverpod wiring for the Haptics setting, UX rules for when to buzz and when to stay silent, fidelity tiers, and testing with FakeHapticsPlatform.
---

# Haptics with flutter_haptics

Use this skill when Flutter UI work involves haptics: a new feature or screen, a component, a code review, or setting up a client app. It targets **flutter_haptics 1.0** (`flutter_haptics: ^1.0.0`). The goal is haptics that **mean something**, **feel native on both platforms**, and **degrade gracefully** on cheap hardware. Every call site should stay one line and platform-blind.

The package's `example/` app is a small working reference: intents on both platforms, a paced handle driving a slider, and an `.ahap` asset.

Read the reference files only when you need them:

| File | Read it when |
|---|---|
| `references/tune.md` | Creating or updating the app's `docs/haptics.md`: the template and the rules for keeping it current. |
| `references/setup.md` | Adding the package to an app: the AppHaptics template, the settings provider, `main()` wiring, helpers and the test harness. |
| `references/recipes.md` | Wiring a specific component: button, switch, slider, picker, pull-to-refresh, swipe, long press, reorder, sheet, OTP, form, async result, hold-to-confirm, games… |
| `references/ux-principles.md` | Deciding *whether* and *how strongly* to buzz, reviewing a screen, or explaining choices to a designer. |
| `references/api.md` | Checking exact API names, constants, Android API levels, patterns, builder methods, AHAP or the testing fake. |

---

## 0. The haptic tune: read it first, update it after

Each app keeps one file, `docs/haptics.md`, that records its haptic design: the **character** (how the app should feel), the **meanings** it uses and why, a **moments map** of every place that buzzes (or deliberately doesn't), the **decisions** taken along the way, and **device notes** from real phones. Code holds the values (`AppHaptics`, `AppPatterns`); the tune holds *where* and *why*. Template and upkeep rules: `references/tune.md`.

**Before any haptic work**, read `docs/haptics.md`. If it is missing, create it from `references/tune.md`, seeding the Meanings table from the app's `AppHaptics` / `AppPatterns` and the Moments map from existing `FlutterHaptics.` call sites.

**Intenting a feature** (a new screen, flow or component, from a spec or from its widgets):

1. List every interaction and state change in the feature: taps, drags, selections, thresholds, limits, async outcomes, errors.
2. Classify each one with the table in §4, **including "silent by design"**. Reuse an existing meaning from the tune whenever its consequence matches; strength follows consequence, not the widget type.
3. Add a new meaning only when none fits. Propose both arms (`native(…)` / `pattern()` / `silent()`), the pattern and the Android API level, and check it against the Character section. A choice that contradicts the Character is a question for the user, not a silent exception.
4. Write the moments into the Moments map. If the user asked for a plan or a proposal, mark them `proposed` and stop there; if they asked for the feature to be built, implement and mark them `live`.
5. After implementing: fill each row's **Where** (`path#symbol`), add new meanings to the Meanings table in the same change as `AppHaptics`, log any judgement call under Decisions with today's date, and update **Last reviewed**.

Never leave the tune and the code disagreeing at the end of a task: a removed haptic becomes a `removed` row with its reason; a moved call updates its Where.

---

## 1. The mental model: three verbs

```dart
FlutterHaptics.play(pattern);        // YOUR waveform, every platform, degrades down the tier ladder
FlutterHaptics.playSystem(constant); // ONE platform's own constant; no fallback, ever
FlutterHaptics.perform(intent);      // a MEANING: what this platform's HapticArm says
```

| You want… | Use |
|---|---|
| A standard UI meaning (press, tick, toggle, success, error, threshold…) | `perform(AppHaptics.x)`. This is the default for ~90% of calls. |
| A meaning one platform has no constant for (e.g. *warning*: Android has none) | Still an intent: `HapticArm.pattern()` on that platform. `perform(AppHaptics.caution)`. |
| A brand moment (payment done, like, shutter) | `play(AppPatterns.x)`, the same waveform on both platforms |
| A texture, rhythm, physics or curve: anything continuous, layered or expressive | `play(pattern)`, built with `HapticPattern`, `HapticPatternBuilder` or an `.ahap` asset |
| The exact platform constant, on that platform only (rare; platform-specific screens) | `playSystem(AndroidHaptic.x)` / `playSystem(IOSHaptic.x)` |
| Something fired many times a second (picker, scrubber, dial, game loop) | `final _tick = FlutterHaptics.register(pattern)` as a field, then `_tick.play()`. The handle is synchronous and **paces itself** to the device. Add a `HapticPacer` only for intents, or for several handles sharing one budget. |

How intents work. Each platform's arm is one of three statements, and both arms are required:

| Arm | What `perform` does | Route |
|---|---|---|
| `HapticArm.native(IOSHaptic.x)` | asks for the platform's constant; **recovers** with the pattern if it can't be delivered | `system`, else `pattern` |
| `HapticArm.pattern()` | plays the pattern **by choice**, without asking: the platform names nothing for this meaning | `pattern` |
| `HapticArm.silent()` | plays nothing **by choice**; the pattern is not consulted | `none` |

- A native arm's pattern is a **recovery, not a substitute**: it plays when the OS is older than the constant needs, or when the actuator can't render it (`perform` declines system constants on rhythm-tier motors).
- Reach for `pattern()` when a platform lacks the meaning but the user still needs to feel it. Reach for `silent()` only when the meaning truly doesn't exist there (iOS has no toggle feedback, for example). Never borrow an unrelated constant to fill a gap.
- The arms are typed: `ios:` takes only `IOSHaptic`, `android:` only `AndroidHaptic`.

Every verb returns a `HapticRoute` (`system` / `pattern` / `none`) and **never throws** by default. Fire and forget; `await` only if you need the route. A handle call that was paced out also returns `none`.

---

## 2. Non-negotiables

1. **Meanings live in one file.** Each app has one `app_haptics.dart` (intents) and optionally `app_patterns.dart` (waveforms). Find the project's existing haptics folder first; create `lib/src/core/haptics/` only when there is none, adapted to the project's layout. Call sites name a meaning: `FlutterHaptics.perform(AppHaptics.success)`. Never inline `HapticIntent(...)` or raw constants at a call site.
2. **No platform checks around haptics.** No `Platform.isIOS` or `defaultTargetPlatform` switches. Intents carry the platform pairing; `HapticPattern.forPlatform(ios:, android:)` handles per-platform tuning; `await FlutterHaptics.support` handles hardware differences.
3. **No preference guards at call sites.** The user's Haptics setting drives `FlutterHaptics.enabled` from one Riverpod notifier. Every verb becomes a no-op while it's false.
4. **Haptics are presentation.** Fire them in widget callbacks or in `ref.listen` on state transitions. Never in Notifiers, repositories, use cases or services: domain code stays platform-free and testable.
5. **Felt and seen on the same frame.** Fire the haptic in the same callback that starts the visual change (scale, shake, check mark, ring). Never after an `await` on unrelated work.
6. **Fire on the outcome, not the attempt.** Copy plays its `tap` *after* the clipboard write succeeds. A save plays success or failure when the request *finishes*, not when it is tapped (an optional light `press` on tap is fine).
7. **High-frequency means registered.** Pickers, drags, dials and loops hold a `HapticHandle` from `FlutterHaptics.register(pattern)` as a plain `final` field (not `late final`: that delays registration to the first play), and dispose it in `dispose()`. The handle paces itself to the device (25 ms on full fidelity, 60 ms on a rotary motor). Opt out with `minInterval: Duration.zero` only when the timing *is* the content (a metronome beat, a puzzle's one important click). Use a `HapticPacer` for intents, which can't be registered yet, and to give several handles one shared budget.
8. **Fire once per crossing, not per frame.** Track state (`_armed`, `_atLimit`, `_band`, `_lastIndex`) and fire only when it changes.
9. **Stop what you start.** A long or continuous pattern interrupted by the user (released early, cancelled, page disposed) gets `FlutterHaptics.stop()`.
10. **Design for the rhythm tier.** Budget phones with rotary (ERM) motors keep only timing. A pattern must be recognisable by its spacing alone (≥ 80 ms between tap starts, 100 ms is safer: taps are widened to 50 ms there); intensity and sharpness are polish.
11. **Silence is a decision.** Navigation, scrolling, typing in system text fields, loading spinners, disabled controls, and incoming content the user is already looking at all stay quiet. See §4.

---

## 3. Setting up a client app (checklist)

Full code is in `references/setup.md`. The wiring below is for a Riverpod app (the default in our projects); with another state manager keep the same shape — one owner of the setting that mirrors it into `FlutterHaptics.enabled`. In short:

1. **Dependency** in `pubspec.yaml`: `flutter_haptics: ^1.0.0` (requires Flutter 3.44+). A `git:` or `path:` dependency only while working against an unreleased build. Add `clock` too if the app uses `HapticPacer`.
2. **`core/haptics/app_haptics.dart`**: start from the standard meanings in §5 and delete the ones the app doesn't use.
3. **`core/haptics/app_patterns.dart`**: only if the app needs its own waveforms or brand moments.
4. **`core/haptics/haptics_settings.dart`**: a `Notifier<bool>` that reads `SharedPreferences`, sets `FlutterHaptics.enabled`, and persists changes.
5. **`main()`**: load prefs and set `FlutterHaptics.enabled` *before* `runApp`; call `FlutterHaptics.prepare()` once to warm the iOS engine. Watch the settings provider in the root widget so it stays alive.
6. **Settings screen**: a "Haptics" switch. Play `switchOff` *before* disabling and `switchOn` *after* enabling, so the switch confirms itself.
7. **Hide the switch where nothing can play**: `ref.watch(hapticSupportProvider)` → `isSupported`.
8. **Helper**: `HapticPacer`, only when the app paces intents or groups of handles. It reads time through `package:clock`, like the package's handles, so widget tests can advance it.
9. **Tests**: a `FakeHapticsPlatform` harness (see §7).
10. **`docs/haptics.md`**: the haptic tune (§0), from `references/tune.md`, with Character filled in and the Meanings table matching `AppHaptics`.

---

## 4. When to buzz (and when not to)

| Moment | Feel | Meaning |
|---|---|---|
| Primary button commits an action | medium tap | `press` |
| Icon button, chip action, copy | light tap | `tap` |
| Custom keypad key (PIN / OTP / calculator) | light, crisp | `key` |
| Picker, segmented control, tab, radio, page snap, chip select | selection tick | `tick` |
| Slider notch, sheet snap point | crisp tick | `detent` / `fineDetent` (close spacing) |
| Hard limit (stepper max, slider end stop, char limit) | thud, once | `limit` |
| Switch on / off | bright / dull: the direction is felt | `switchOn` / `switchOff` |
| Gesture crosses commit threshold / falls back | firm / soft | `armed` / `disarmed` |
| Drag lift / drop | rigid / light | `lift` / `drop` |
| Long press opens a menu | heavy | `longPress` |
| Action accepted / refused | success / error notification | `success` / `failure` |
| Caution (destructive confirm, risky state) | warning | `caution` |
| Once-per-session moment (payment done, goal reached) | rich, ≤ ~600 ms | `play(AppPatterns.celebrate)` |

**Stay silent for:**
- navigation and route changes
- list taps that just open a page
- scrolling
- typing in system text fields (the keyboard owns that)
- loading or waiting
- disabled controls
- re-selecting the already-selected value
- background or incoming events the user is already looking at
- animations the user didn't cause
- every frame of a continuous gesture

**Budget:** about one haptic per user action. Batch actions (select all, delete 12 items) get **one** summarising haptic, never N. Errors in a form get **one** `failure` plus a shake on the first invalid field. Long or strong patterns are for moments that happen once.

**Hierarchy (a design goal):** strength should track consequence: tick < tap < press < longPress / limit < outcome. Platform constants collapse some levels (on iOS `tick`/`detent` are all `selection` and `press`/`armed`/`lift` are all `impactMedium`), so keep the *ordering* intact and never invert it. A delete must never feel lighter than a filter chip. Positive actions may feel richer than their reversal (like = `pop`, unlike = `unpop`).

---

## 5. The standard meanings (template)

Every row is `HapticArm.native(...)` on both platforms unless it says otherwise.

| Meaning | iOS | Android (min API) | Pattern |
|---|---|---|---|
| `press` | `impactMedium` | `contextClick` (23) | `HapticPatterns.mediumTap` |
| `tap` | `impactLight` | `virtualKey` (5) | `HapticPatterns.lightTap` |
| `key` | `impactLight` | `keyboardTap` (8) | crisp light tap |
| `longPress` | `impactHeavy` | `longPress` (3) | `HapticPatterns.heavyTap` |
| `tick` | `selection` | `clockTick` (21) | `HapticPatterns.selection` |
| `detent` | `selection` | `segmentTick` (34) | crisp tap 0.55 / 0.9 |
| `fineDetent` | `selection` | `segmentFrequentTick` (34) | light crisp tap 0.32 / 0.95 |
| `limit` | `impactRigid` | `contextClick` (23) | thud + rebound |
| `switchOn` | `impactLight` | `toggleOn` (34) | bright tap 0.7 / 0.9 |
| `switchOff` | `impactSoft` | `toggleOff` (34) | dull tap 0.5 / 0.2 |
| `armed` | `impactMedium` | `gestureThresholdActivate` (34) | `HapticPatterns.mediumTap` |
| `disarmed` | `impactSoft` | `gestureThresholdDeactivate` (34) | `HapticPatterns.soft` |
| `lift` | `impactMedium` | `dragStart` (34) | `HapticPatterns.rigid` |
| `drop` | `impactLight` | `gestureEnd` (30) | `HapticPatterns.lightTap` |
| `success` | `notificationSuccess` | `confirm` (30) | `HapticPatterns.success` |
| `failure` | `notificationError` | `reject` (30) | `HapticPatterns.error` |
| `caution` | `notificationWarning` | `HapticArm.pattern()`: Android has no warning | `HapticPatterns.warning` |

With `minSdk` 24, anything marked 30 or 34 recovers with its pattern on older Android. That is expected and is why the pattern exists. iOS has no toggle feedback either; this template still pairs `switchOn`/`switchOff` with light/soft impacts so the direction is felt. Use `HapticArm.silent()` on iOS instead if the app wants switches quiet there.

---

## 6. Riverpod patterns

```dart
// Async outcome → haptic, in the widget. The notifier never imports flutter_haptics.
ref.listen(saveProfileProvider, (previous, next) {
  if (previous?.isLoading != true || next.isLoading) return; // only on loading → done
  FlutterHaptics.perform(next.hasError ? AppHaptics.failure : AppHaptics.success);
});
```

- Use `ref.listen`, not `ref.watch`, for haptics: they belong to *transitions*, not states. A rebuild must never replay a haptic.
- Gate on the transition you mean. Don't buzz on the initial load or on a refresh the user didn't start.
- Setting changes go through `hapticsSettingsProvider.notifier`; never write `FlutterHaptics.enabled` from a widget.

---

## 7. Testing

```dart
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics/testing.dart';

late FakeHapticsPlatform haptics;
setUp(() {
  haptics = FakeHapticsPlatform();
  FlutterHapticsPlatform.instance = haptics;
  FlutterHaptics.debugResetSupportCache();
  FlutterHaptics.debugResetFailureLog(); // failures are reported once per run
});
tearDown(FlutterHapticsPlatform.reset);

testWidgets('saving confirms', (tester) async {
  // ... pump, tap Save, pump past the request
  expect(haptics.systemHaptics, [AndroidHaptic.contextClick, AndroidHaptic.confirm]);
}, variant: TargetPlatformVariant.only(TargetPlatform.android));
```

- Use `TargetPlatformVariant.only(...)` in `testWidgets`. Setting `debugDefaultTargetPlatformOverride` by hand fails the post-test invariant check unless you reset it inside the test body.
- The fake behaves like the device its `support` describes. `support: HapticSupport(fidelity: HapticFidelity.rhythm, supportsContinuous: true)` is the cheap phone: `perform` recovers with the pattern, `playSystem` still plays. `HapticSupport.unsupported` makes every pattern fail. `playsSystemHaptics: false` stands in for an OS too old for the constant. `canRegister: false` tests handles that can't prepare; `debugLoseRegistrations()` tests one whose registration was lost.
- Assert on the meaning as well as the outcome: `haptics.intents` records every intent passed to `perform`, before its arm is resolved (even while haptics are off).
- `played` records every pattern *asked for*, including ones the fake refused, so `lastPlayed` is "what was requested". Check the returned route when it matters.
- **Handles and `HapticPacer` pace on the test clock** (`package:clock`). `testWidgets` advances it only when you pump a duration. Two taps separated by a bare `await tester.pump()` are 0 ms apart, so the second play is dropped. Pump a realistic gap (`tester.pump(const Duration(milliseconds: 100))`), or register with `minInterval: Duration.zero` in the code under test only if that is the real behaviour. A pacer built on `Stopwatch` or `DateTime.now()` ignores pumps and drops haptics in tests however long the gap: replace it with the one in `references/setup.md`.
- A platform wrapper (a tracer, a logger) must forward `noteIntent` to the platform it wraps, or `haptics.intents` stays empty without any error.
- Compare patterns by value: `expect(haptics.lastPlayed, AppHaptics.success.pattern)`.

---

## 8. Review checklist (use when reviewing a PR or screen)

- [ ] Every haptic answers "what just happened?" Decorative haptics are cut.
- [ ] Meanings come from `AppHaptics` / `AppPatterns`; there are no inline intents or raw constants.
- [ ] No `Platform.is*` and no preference checks around haptic calls.
- [ ] No haptics in notifiers, repositories or services; async outcomes use `ref.listen`.
- [ ] Fired on the same frame as the visual change, and on the outcome rather than the attempt.
- [ ] Threshold, limit and crossing haptics fire once per crossing, with state tracked.
- [ ] High-frequency haptics use a registered handle (a plain `final` field, disposed in `dispose()`); intents and shared budgets use a `HapticPacer`.
- [ ] Each intent's arms say what they mean: `pattern()` where a platform lacks the meaning, `silent()` only where it truly doesn't apply, never a borrowed unrelated constant.
- [ ] Long or continuous patterns are stopped on cancel and dispose; timer-driven haptics stop offstage and when the app is hidden.
- [ ] Silent cases stay silent: nav, scroll, typing, loading, disabled, re-select.
- [ ] Batch actions play one haptic; a form error plays one `failure` plus a shake on the first invalid field.
- [ ] Custom patterns still read on the rhythm tier: taps ≥ 80–100 ms apart, meaning in the timing, nothing important below 0.15 intensity.
- [ ] Haptics never carry information alone; there's a visual and a semantics equivalent. Hold and slide commits have a semantics action.
- [ ] A test with `FakeHapticsPlatform` covers each new meaning.
- [ ] `docs/haptics.md` matches the change: new moments in the Moments map with their Where, new meanings in the Meanings table, judgement calls under Decisions.

---

## 9. Pitfalls

- **Double haptics from Flutter built-ins.** Several Flutter widgets already emit feedback:
  - Material `InkWell`, `ListTile` and other widgets with `enableFeedback` call `Feedback.forLongPress` (a vibration on Android) on long press.
  - `CupertinoPicker` plays a selection click on iOS.
  - `CupertinoSwitch` plays a light impact on iOS.
  - `CupertinoContextMenu(enableHapticFeedback: true)` plays a heavy impact when it opens.
  - The Material time picker dial vibrates on Android as it snaps.

  When you add your own haptic for the same moment, use a `GestureDetector`, set `enableFeedback: false`, or skip yours on that widget, so the user never feels two.
- **`HapticArm.silent()` where you meant `HapticArm.pattern()`.** Silent plays nothing; if the user should still feel the meaning on that platform, the arm is `pattern()`.
- **`late final` handles.** A lazy field registers on first use, so the first tick pays the round trip `register` exists to save, and `dispose()` on a never-used handle creates it just to release it. Use a plain `final` field.
- **One handle paces only itself.** Five handles picked at random by a texture can still fire five times inside the floor. Gate them with one shared `HapticPacer`.
- **A paced handle drops, it doesn't delay.** The last tick of a very fast fling can be the one dropped. That's the intended trade; don't add a "catch-up" tick. The one exception is a drag that *ends* on a value whose tick was paced out: play that value on release, since it's the one the user commits to.
- **`ContinuousEvent(...)` is not const.** In `const` patterns use `ContinuousEvent.curved(intensity: ConstantParam(x), ...)`.
- **Failures are logged once.** In debug, `onFailure` logs each distinct failure once per run, so a haptic that failed silently the second time already failed earlier in the log. Set `FlutterHaptics.onFailureReport` to send failures to your own logger or crash reporter in release; it replaces the console and never throws.
- **`then` and `repeat`** count a closing tap as 25 ms wide (`HapticEvent.transientWidth`); use `overlay` / `|` for simultaneity.
- **`perform` on rhythm-tier Android hardware** (no amplitude control or primitives, and every Android 7 device) declines *every* system constant, `longPress` included, and plays the pattern. That's by design; make the patterns good.
- **`playSystem` never falls back.** On the wrong platform or an old OS it returns `HapticRoute.none` and logs in debug. Don't use it for cross-platform meanings.
- **`FlutterHaptics.support` is cached** for the app's lifetime; tests must call `FlutterHaptics.debugResetSupportCache()`.
- **iPads have no Taptic Engine**: every verb returns `HapticRoute.none` there (and is reported through `onFailure`; with `throwIt` it throws). Low Power Mode and System Haptics off suppress playback silently. Never rely on a haptic as the only signal.
- **Rumbles on iPhone 7** (UIKit fallback) are dropped. Check `support.supportsContinuous` before designing a flow around a sustained rumble.
- **AHAP:** `Ahap.loadAsset` drops audio events; `Ahap.encode` throws `StateError` on curves longer than 16 control points (playback has no such limit). AHAP curves are pattern-wide, so in an exported file a curved rumble also shapes any tap that overlaps it: keep taps clear of curved rumbles in patterns you export.
- **A `Timer` is not a ticker.** A tab shell keeps offstage pages alive with their animations muted, but a `Timer` driving haptics (metronome, countdown, game loop) keeps firing out of sight, and after the app is hidden. Stop it when `TickerMode` turns off and in `AppLifecycleListener(onHide: …)`.
- **A release tap after `stop()` can land on the next press.** `stop()` is async; if the user presses again before it completes, a "let go" tap plays over the new hold's rumble. Check the gesture is still released before playing it.
