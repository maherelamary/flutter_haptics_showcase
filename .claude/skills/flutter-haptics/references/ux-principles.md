# Haptic UX principles

These are the rules behind the choices in SKILL.md, so you can make a good call in situations no recipe covers, and explain it to a designer.

## 1. Meaning, not decoration

A haptic is a sentence the device says in the user's hand. Every one should answer **"what just happened?"**:

| Answer | Example | Meaning |
|---|---|---|
| "I did it" | button committed, item saved | `press` → `success` |
| "No" | wrong PIN, invalid form, refused | `failure` |
| "Careful" | about to delete, risky setting | `caution` |
| "You moved one step" | picker, tab, segment, page | `tick` |
| "You crossed a line" | refresh armed, swipe committed, notch | `armed`, `detent` |
| "You're back on the safe side" | pulled back under the threshold | `disarmed` |
| "That's the end" | stepper max, slider end, char limit | `limit` |
| "It's in your hand" / "It's down" | drag lift / drop | `lift` / `drop` |
| "Something important happened" | payment done, unlocked | brand pattern |

If you can't fill in the sentence, cut the haptic. Haptics that decorate (every tap, every scroll) train users to ignore them, and then the meaningful ones stop working.

## 2. Felt and seen together

- The haptic and the visual change start **on the same frame**. Call `perform` or `play` in the same callback that calls `setState`, starts the controller or triggers the shake.
- A haptic that lags its animation by more than ~50 ms reads as a glitch. A haptic with no visual counterpart reads as a phantom.
- Pair them deliberately:

  | Haptic | Visual |
  |---|---|
  | `failure` | shake |
  | `success` | check mark or colour change |
  | `armed` | indicator turns active |
  | `limit` | bump animation |
  | `lift` | scale-up and shadow |
  | `pop` | burst |

- Motion duration and pattern duration should agree. A 400 ms rumble under a 150 ms animation feels broken.

## 3. Strength follows consequence

Order strength by how much the action matters. This is a design goal; native constants collapse some neighbouring levels, which is fine as long as the order never inverts:

```
fineDetent < tick < tap/key < detent < press < lift/armed < limit/longPress < failure/success < brand moments
```

- A destructive confirmation never feels lighter than a filter chip.
- Asymmetry is good: positive actions can feel richer than their reversal (like = bright `pop`, unlike = soft `unpop`; on = crisp, off = dull). Users learn direction by feel.
- Don't escalate repeated errors (third wrong PIN ≠ stronger buzz). Escalation reads as punishment.

## 4. Budget and rhythm

- About **one haptic per user action**. Continuous gestures are the exception: one per crossing, paced at ≥ 30–40 ms.
- **Batch actions get one haptic.** "Select all" plays one `doubleClick`, not 20 ticks. "Delete 12 emails" plays one `press`.
- **Forms get one error.** Submit with three invalid fields → one `failure` + shake and focus the *first* invalid field.
- **Long patterns (> 300 ms) are rare.** Save them for once-per-session moments: payment done, level complete, vault unlocked.
- **Sequences need gaps.** A key click followed by the PIN verdict needs ~150 ms between them, or the two blur into one buzz.
- In a journey (checkout, onboarding), check the rhythm: a recap of every haptic should read like punctuation, not noise. A debug-only wrapper around `FlutterHapticsPlatform` that logs each call gives you that recap.

## 5. Silence is a design decision

Stay silent for:

- **Navigation**: push/pop, list rows that open a page, back. The destination is the feedback.
- **Scrolling** and flinging. Only *snaps* (page changes, picker items, sheet snap points) tick.
- **Typing in system text fields.** The keyboard owns that feedback. Custom keypads are different: they *are* the keyboard.
- **Waiting.** Spinners, progress without milestones, "processing". The outcome gets the haptic, not the wait.
- **Disabled controls.** Don't buzz "no" on a disabled button. Fix the affordance instead: explain why it's disabled.
- **Re-selecting the current value**: tapping the active tab, the already-selected chip or the same segment.
- **Incoming content the user is looking at**: a chat reply in the open thread. Use a light `tap` only if the user has scrolled away and needs to know.
- **Animations the user didn't cause**: auto-advancing carousels, background refreshes.
- **Cancel paths.** Dismissing a dialog or releasing a long-press outside the menu is silent. The user already knows they let go.

## 6. Fire on the outcome

- Copy: `tap` *after* `Clipboard.setData` succeeds.
- Network actions: optional light `press` on tap, then `success` or `failure` when the request completes, via `ref.listen` on the loading → done transition.
- Pull-to-refresh: `armed` when crossing the threshold, nothing while loading, `success` when new content lands.
- Never play `success` optimistically and then `failure`. If you update the UI optimistically, defer the haptic to the confirmed result or skip it.

## 7. Thresholds and limits: once per crossing

- Keep a boolean (`_armed`, `_atLimit`) or an index (`_band`, `_lastNotch`) and fire only when it changes.
- Crossing back gets its own, softer haptic (`disarmed`), so the user can feel which side of the line they're on without looking.
- A limit fires when it's *reached*, not on every attempt to go further while pinned. It re-arms once the value leaves the limit.
- Exception: tapping "+" at max *is* a new attempt, so `limit` plus a shake is right each time.

## 8. Platform conventions

**iOS (UIKit vocabulary):**
- `selection` for pickers and segmented controls.
- `impact*` for physical collisions and button-like presses (light / medium / heavy / rigid / soft).
- `notification*` for task outcomes.
- iOS users expect fewer haptics than Android users. System controls are mostly silent except pickers, switches in some contexts, and long-press menus.

**Android (`HapticFeedbackConstants`):**
- `CLOCK_TICK` / `SEGMENT_TICK` for steps, `CONFIRM` / `REJECT` for outcomes, `TOGGLE_ON` / `TOGGLE_OFF`, `GESTURE_THRESHOLD_*`, `DRAG_START`, `LONG_PRESS`, `KEYBOARD_TAP`.
- Many need API 30 or 34. Below that, the intent's pattern plays. That is what the pattern is for.

The two vocabularies don't map one-to-one. iOS has no toggle, threshold, drag or keyboard-release concept; Android has no warning. Decide per meaning in `AppHaptics` and document the choice there.

## 9. Design for the cheap phone (fidelity tiers)

| Tier | Where | What survives |
|---|---|---|
| `full` | iPhone 8+ (Core Haptics), Android 16 envelope hardware | intensity, sharpness, curves |
| `intensity` | iPhone 7 (UIKit generators), Android 11+ composition primitives, Android 8+ amplitude control | strength and rhythm; sharpness only coarse (generator style / primitive choice); Android curves stepped; iPhone 7 drops rumbles and curves entirely |
| `rhythm` | rotary (ERM) motors, including new budget phones, and every Android 7 (API 24–25) device | timing only; every tap widened to ~50 ms at full strength (taps below 0.15 intensity are silent) |
| `none` | iPad, no vibrator, web/desktop | nothing (calls return `none` and don't throw by default) |

Rules:

- **The meaning must be in the timing.** `doubleClick` and `tripleClick` read on every tier; `lightTap` versus `heavyTap` don't.
- Space taps ≥ 80 ms apart (100 ms is safer) if they must stay distinct on rhythm hardware: each tap is widened to 50 ms there, so 60 ms spacing leaves a 10 ms gap a rotary motor can't render.
- Keep important taps at intensity ≥ 0.15; quieter ones are dropped on the on/off path.
- Avoid long, faint rumbles on the rhythm tier: a 4 s whisper becomes a 4 s alarm. Check `support.fidelity` / `supportsContinuous` and switch to sparse taps.
- On rhythm hardware, `perform` deliberately declines system constants (they're too short to be felt there) and plays the pattern. Make the patterns good.
- Test on a cheap phone. Short of one, a debug-only `FlutterHapticsPlatform` wrapper that strips sharpness and intensity and widens taps to 50 ms before passing patterns on gets a flagship close to the rhythm tier.

## 10. Accessibility

- **Never convey information by haptics alone.** Pair every haptic with a visual change and, where it matters, a semantics announcement. Nothing plays on iPads, in Low Power Mode, with system haptics off, or with the app's own switch off.
- Offer the app-wide **Haptics** switch (via `FlutterHaptics.enabled`). Some users find vibration distracting or painful.
- Haptics help in eyes-busy moments: confirming a payment, finding a dial position, breathing exercises. Those are good places to invest.
- Don't use intense or long patterns for routine actions. Users with sensory sensitivities notice.

## 11. Async and background events

- Haptics belong to *transitions the user caused or is waiting on*. Listen for loading → data and loading → error, never the initial load.
- Background syncs, websocket updates and timers stay silent unless they're a direct reply to the user's action, or the app's core purpose (an alarm, a turn-based game: "your turn").
- If an outcome arrives after the user navigated away, skip the haptic: check `mounted` / `context.mounted` in widgets (`ref.mounted` exists only on a notifier's `Ref`). The haptic would be unattributable.

## 12. Brand moments

One or two signature patterns per app, used **only** at its emotional peaks: purchase complete, goal reached, unlock. Rules:

- ≤ ~600 ms.
- Built from the success rhythm, so it reads on every tier.
- Played once per occurrence, never looped.
- Defined in `AppPatterns` with a doc comment saying where it's allowed.
