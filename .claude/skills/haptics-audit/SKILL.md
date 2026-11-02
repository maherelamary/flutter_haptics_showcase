---
name: haptics-audit
description: Audit a Flutter screen, feature or whole app for haptic feedback quality with flutter_haptics — finds missing, excessive, misplaced or wrong-meaning haptics, platform checks, haptics in notifiers, unpaced high-frequency calls, missing setup and drift from the app's haptic tune (docs/haptics.md), then proposes concrete edits and refreshes the tune. Invoke as /haptics-audit [path or feature].
disable-model-invocation: true
---

# /haptics-audit

Audit haptic feedback in a Flutter app that uses (or should use) `flutter_haptics`, against the `flutter-haptics` skill's rules. Produce a prioritized report, then offer to apply the fixes.

**Scope:** `$ARGUMENTS`: a file, folder or feature name. If empty, audit `lib/` and say so.

Load the `flutter-haptics` skill first (SKILL.md; read `references/ux-principles.md`, `references/recipes.md` and `references/tune.md` as needed). Every finding must cite one of its rules. Read the app's `docs/haptics.md` before Step 2: its Character and Decisions are the app's own rules, and a choice they record is not a finding.

## Step 1: Setup health (whole app, quick)

Check each item and record ✅ / ❌ / ➖ (not applicable):

1. `flutter_haptics: ^1.0.0` is in `pubspec.yaml` (a `git:` or `path:` dependency only while working against an unreleased build), the Flutter SDK is 3.44+, and no other haptics package (`haptic_feedback`, `vibration`, …) is used alongside it.
2. **Direct `HapticFeedback.*` calls** (from `package:flutter/services.dart`). List each one. These bypass the app switch and the intent vocabulary, so each should migrate to `FlutterHaptics.perform(AppHaptics.x)`.
3. An `AppHaptics` file exists (wherever the project keeps it; `lib/src/core/haptics/app_haptics.dart` by default) and is the only place that names `IOSHaptic` / `AndroidHaptic`.
   ```
   grep -rn "IOSHaptic\.\|AndroidHaptic\.\|HapticIntent(" lib/ | grep -v app_haptics
   ```
4. A settings notifier sets `FlutterHaptics.enabled` from persisted prefs, and `main()` sets it before `runApp`.
5. `FlutterHaptics.prepare()` is called once at startup.
6. A "Haptics" switch exists in settings, hidden when `support.isSupported` is false.
7. Tests install `FakeHapticsPlatform`, reset with `FlutterHapticsPlatform.reset`, and call `FlutterHaptics.debugResetFailureLog()`.
8. Any platform wrapper (a tracer or logger extending `FlutterHapticsPlatform`) forwards `noteIntent` and returns `playRegistered`'s result.
9. Any `HapticPacer` reads time through `package:clock`, not `Stopwatch` or `DateTime.now()` (those ignore `testWidgets` pumps and drop haptics in tests).
10. `docs/haptics.md` exists, with Character filled in.

If 3–6 are missing, the first recommendation is the setup from `references/setup.md`. If 10 is missing, offer to create the tune from `references/tune.md`. Offer to create the files.

## Step 2: Inventory interaction points (in scope)

Search the scope for places a user acts or a state changes:

```
grep -rnE "onPressed|onTap|onLongPress|onChanged|onSelected|onSelectionChanged|onDestinationSelected|onPageChanged|onSelectedItemChanged|onReorder|onDismissed|onUpdate|onRefresh|onSubmitted|onEditingComplete|showDialog|showModalBottomSheet|ScaffoldMessenger|ref\.listen|AsyncValue\.guard|Dismissible|RefreshIndicator|ReorderableListView|DraggableScrollableSheet|PageView|ListWheelScrollView|CupertinoPicker|Slider|Switch|Checkbox|Radio|SegmentedButton|FilterChip|ChoiceChip|TextFormField|Form\(" <scope>
```

Also find every existing haptic call:

```
grep -rnE "FlutterHaptics\.|HapticFeedback\.|HapticPacer|HapticHandle|register\(" <scope>
```

For each interaction point, classify the moment using the table in SKILL.md §4: press, tap, tick, detent, limit, toggle, threshold, lift/drop, long press, outcome, caution, brand, or **silent by design**. Where the tune's Moments map already has a row for the moment, start from that row.

## Step 3: Find issues

Check each point and each existing call against the rules. Severity:

- 🔴 **Bug**: wrong behaviour for users.
- 🟠 **UX**: a haptic that's wrong, missing or excessive.
- 🟡 **Hygiene**: works, but breaks a convention.

| # | Smell | Severity | Rule |
|---|---|---|---|
| A | Haptic inside a Notifier / repository / use case / service | 🟠 | Haptics are presentation. Move to `ref.listen` in the widget. |
| B | `Platform.isIOS` / `defaultTargetPlatform` branching around haptics | 🟡 | Use an intent, `HapticPattern.forPlatform` or `support`. |
| C | A preference checked at the call site (`if (settings.haptics)`) | 🟡 | `FlutterHaptics.enabled` gates every verb. |
| D | Inline `HapticIntent(...)` or a raw constant at a call site | 🟡 | Meanings live in `AppHaptics`. |
| E | An intent arm that says the wrong thing: `HapticArm.silent()` where users still need to feel the meaning (should be `pattern()`), or a borrowed unrelated constant filling a platform's gap (e.g. `gestureEnd` standing in for a warning) | 🔴 | `pattern()` when the platform lacks the meaning; `silent()` only when it truly doesn't apply. |
| F | `playSystem` used for a cross-platform meaning | 🔴 | It plays nothing on the other platform. Use `perform`. |
| G | Haptic in `build()` or on `ref.watch`, so it replays on rebuild | 🔴 | Use `ref.listen` or a callback. |
| H | High-frequency haptic (drag, scroll, picker, ticker) on `play()` or an unpaced `perform()` | 🟠 | A pattern: `FlutterHaptics.register` (paces itself). An intent: a `HapticPacer`. |
| H3 | Several handles fired from one gesture with no shared `HapticPacer` (textures, ladders, physics) | 🟠 | Each handle paces only itself; gate the group with one pacer. |
| H4 | `minInterval: Duration.zero` on a handle fired from a gesture, or a handle declared `late final` | 🟡 | Opt out of pacing only for scheduled timing (a metronome); declare handles as plain `final` fields. |
| H5 | A drag that ends on a value whose tick was paced out, so the committed value is never felt | 🟡 | Play that value on release; don't add catch-up ticks mid-gesture. |
| H2 | Ticking wheel or scroller whose fling can run for seconds (looping `ListWheelScrollView`, stacked iOS momentum) | 🟠 | Capped physics: `maxFlingVelocity`, no `carriedMomentum`, fast deceleration. |
| I | Threshold or limit fired every frame, not once per crossing | 🟠 | Track `_armed` / `_atLimit` / index. |
| J | Long or continuous pattern not stopped on cancel or dispose | 🔴 | `FlutterHaptics.stop()`. |
| J2 | A release tap after `await stop()` with no check that the gesture is still released | 🟠 | A quick re-press gets the tap over its new rumble. Check before playing. |
| J3 | Timer-driven haptics (metronome, countdown, game loop) that keep firing offstage or after the app is hidden | 🔴 | A `Timer` is not a ticker: stop it when `TickerMode` turns off and in `AppLifecycleListener(onHide:)`. |
| K | `HapticHandle` not disposed | 🟡 | Dispose in `dispose()`. |
| L | Missing haptic on a meaningful moment (commit, outcome, threshold, limit, selection change, toggle) | 🟠 | Add the matching meaning. |
| M | Haptic on a silent-by-design moment (navigation, scroll, typing in system fields, loading, disabled, re-selecting the same value, incoming content on screen) | 🟠 | Remove it. |
| N | Batch action plays N haptics, or a form plays one per invalid field | 🟠 | One summarising haptic; one `failure` plus a shake on the first invalid field. |
| O | Haptic fired on the attempt, not the outcome (before an await that can fail, optimistic success) | 🟠 | Fire on the result. |
| P | Strength doesn't match consequence (delete lighter than a chip; heavy taps on routine actions) | 🟠 | Follow the hierarchy. |
| Q | Haptic without a visual counterpart, or fired after an unrelated await so it lags the motion | 🟠 | Same frame as the visual. |
| R | Double haptics: our call plus a built-in one (`InkWell` / `ListTile` long press on Android, `CupertinoPicker`, `CupertinoSwitch`, `CupertinoContextMenu(enableHapticFeedback: true)`, Material time picker on Android) | 🟠 | Use `GestureDetector`, set `enableFeedback: false`, or drop ours. |
| S | Custom pattern unreadable on the rhythm tier (taps < 80 ms apart, key taps below 0.15 intensity, meaning carried by intensity or sharpness only) | 🟡 | Respace it; carry the meaning in timing. |
| T | Direct `HapticFeedback.*` from `flutter/services` | 🟡 | Migrate to `FlutterHaptics.perform(AppHaptics.x)`. |
| U | Information conveyed by haptic alone | 🟠 | Add a visual and semantics equivalent. |
| U2 | A hold or slide commit with no semantics action | 🟠 | A screen reader's double tap aborts a hold and can't drag: `Semantics(onTap: confirm)`. |
| V | A new meaning without a test | 🟡 | Add a `FakeHapticsPlatform` test. |
| W | A widget test that taps a handle-backed control twice with bare `tester.pump()` between, expecting two haptics | 🟡 | Handles pace on the test clock; pump a realistic gap. |
| W2 | A `HapticPacer` built on `Stopwatch` or `DateTime.now()` | 🟡 | Widget-test pumps don't move it, so tests drop haptics. Use the `clock` version in `references/setup.md`. |
| X | Tune drift: a call site with no Moments map row, a `live` row whose Where is gone or plays another meaning, a meaning missing from the Meanings table (or listed but not in code), a meaning no `live` row uses | 🟡 | The tune and the code must agree (`references/tune.md`). |
| Y | A haptic that contradicts the tune's Character (heavier than its ceiling, a long pattern outside a brand moment) without a Decisions entry | 🟠 | Follow the Character, or record the exception under Decisions. |

Read surrounding code before flagging. A moment that looks missing may be handled by a parent widget or a `ref.listen` elsewhere. Don't report those.

## Step 4: Report

Output the report in this shape. Keep it scannable, and cite `file:line` for every finding.

```
## Haptics audit — <scope>

**Setup:** ✅ dependency · ❌ AppHaptics · ✅ enabled switch · ❌ prepare() · ➖ tests · ❌ docs/haptics.md

**Summary:** 3 bugs · 7 UX · 4 hygiene · haptic coverage 12/19 meaningful moments

### 🔴 Bugs
1. `lib/src/features/cart/cart_notifier.dart:48` — G/A: `perform(success)` inside `checkout()`, replays on retry and runs in tests.
   → Move to `ref.listen(checkoutProvider, …)` in `CartPage` (loading → data: `success`, → error: `failure`).

### 🟠 UX
…

### 🟡 Hygiene
…

### Moments map
| Screen | Moment | Now | Proposed |
|---|---|---|---|
| Cart | quantity + / − | none | `tick`; `limit` + shake at bounds |
| Cart | swipe to remove | none | `armed`/`disarmed` on threshold; `press` on commit; `rewind` on undo |
| Cart | tap row → product | `tap` | silent (navigation) |

### Tune drift
- `lib/src/features/cart/cart_page.dart#_onRemove` plays `press` but has no Moments map row.
- `AppHaptics.drop` is in the Meanings table but nothing plays it.
```

Then:

- List any **new meanings** the fixes need in `AppHaptics` or `AppPatterns`, with the proposed arms (`native(…)` / `pattern()` / `silent()`) for iOS and Android, the pattern, and API levels.
- Ask: **"Apply all, apply 🔴 + 🟠 only, or pick by number?"** Don't edit anything before the user answers.

## Step 5: Apply (after the user confirms)

- Make the edits with the smallest diff. Reuse the recipes in `references/recipes.md`.
- Add new meanings to `AppHaptics` / `AppPatterns`, each with a doc comment. Never inline them at call sites.
- Add or extend a `FakeHapticsPlatform` test for each new meaning or fixed bug, using `TargetPlatformVariant.only(TargetPlatform.android)` and `intents` / `systemHaptics` / `played` assertions.
- Update `docs/haptics.md` in the same change (create it from `references/tune.md` if it doesn't exist): write the moments map into the Moments map (`live` for what you implemented, `silent by design` for moments you confirmed should stay quiet, `removed` with a Decisions line for haptics you took out), add new meanings to the Meanings table, fix the drift you reported, and set **Last reviewed** to today.
- Run `flutter analyze` (and `flutter test` if available). Fix anything you introduced.
- Finish with a short list of what changed. Remind the user to feel it on a real device, ideally including a cheap Android phone (rhythm tier), and to add what they felt to the tune's Device notes.
