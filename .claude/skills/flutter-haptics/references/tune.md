# The haptic tune: `docs/haptics.md`

One file per app that records its haptic design, so every feature starts from what the app already does instead of from zero. Code stays the source of truth for **values** (`AppHaptics`, `AppPatterns`); the tune is the source of truth for **where** and **why**.

## Upkeep rules

- **Read it before** any haptic work. **Update it in the same change** as the code it describes, never in a later one.
- **One row per moment**, not per call site. A moment is something the user does or sees happen ("quantity hits max"), named in the user's words.
- **Where** is `path#symbol` (`lib/src/features/cart/quantity_stepper.dart#_increment`). Line numbers drift; a symbol survives edits.
- **Silent moments get rows too** when someone might reasonably expect a haptic (a list tap that opens a page, a refresh). That is what stops the next feature from adding one.
- **Never delete a row** for a removed haptic: mark it `removed` and say why in Decisions, so the reason survives.
- **Decisions are dated** (`YYYY-MM-DD`) and one line each. Anything that departs from the skill's defaults belongs here.
- **Meanings mirror `AppHaptics` / `AppPatterns` exactly.** A meaning in code but not in the table, or the reverse, is drift.
- Keep it scannable: tables, no essays. If a section grows past one screen, the app probably has too many meanings.

Status values for the Moments map: `live` · `proposed` · `silent by design` · `removed`.

## Template

Copy from here into `docs/haptics.md` and fill it in. Rows below are examples; replace them.

```markdown
# Haptics — <App name>

The app's haptic design. Read before adding or changing a haptic; update in
the same change. Values live in `app_haptics.dart` and `app_patterns.dart`;
this file says where each one is used and why.

Last reviewed: YYYY-MM-DD · flutter_haptics ^1.0.0

## Character

- **Feel:** crisp and light. Taps over rumbles; nothing heavier than `press` for routine actions.
- **Strength ceiling:** `longPress`, `limit` and outcomes may be heavy; everything else stays at or below `press`.
- **Brand moments:** `AppPatterns.celebrate` after a completed payment, at most once per session. No other long patterns.
- **iOS switches:** light / soft impacts so the direction is felt (alternative: silent).
- **Cheap phones:** every custom pattern must read by its timing alone (taps ≥ 80 ms apart).

## Meanings

| Meaning | iOS arm | Android arm (min API) | Pattern | Why it exists |
| --- | --- | --- | --- | --- |
| `press` | native `impactMedium` | native `contextClick` (23) | `HapticPatterns.mediumTap` | Primary button commits an action |
| `tick` | native `selection` | native `clockTick` (21) | `HapticPatterns.selection` | A value changes by one step |
| `limit` | native `impactRigid` | native `contextClick` (23) | `AppPatterns.bump` | A hard bound is reached |
| `success` | native `notificationSuccess` | native `confirm` (30) | `HapticPatterns.success` | An action the user started succeeded |
| `caution` | native `notificationWarning` | `pattern()` — Android has no warning | `HapticPatterns.warning` | Destructive or risky confirm |

## Moments map

| Feature | Screen / widget | Moment | Meaning | Where | Status |
| --- | --- | --- | --- | --- | --- |
| Cart | QuantityStepper | + / − changes the count | `tick` | `lib/src/features/cart/presentation/widgets/quantity_stepper.dart#_step` | live |
| Cart | QuantityStepper | count hits max | `limit` | `…/quantity_stepper.dart#_step` | live |
| Cart | Cart row | tap opens product | — | — | silent by design |
| Checkout | Pay button | payment confirmed | `play(AppPatterns.celebrate)` | `lib/src/features/checkout/presentation/pages/checkout_page.dart#_onPaid` | proposed |

## Decisions

| Date | Decision | Why |
| --- | --- | --- |
| YYYY-MM-DD | Switches use light/soft impacts on iOS | Direction should be felt on both platforms |
| YYYY-MM-DD | No haptic on pull-to-refresh release | The spinner already confirms; refresh is not a commit |

## Device notes

| Date | Device (tier) | What was felt | Action |
| --- | --- | --- | --- |
| YYYY-MM-DD | Galaxy A11 (rhythm) | `fineDetent` ticks smeared on fast drags | Pacer raised to 60 ms on rhythm tier |
```

## When the audit runs

`/haptics-audit` compares the code against this file and reports drift:

- a call site with no Moments map row;
- a `live` row whose Where no longer exists or no longer plays that meaning;
- a meaning in `AppHaptics` / `AppPatterns` missing from the Meanings table, or the reverse;
- a meaning that no `live` row uses.

After the user approves fixes, the audit writes its moments map into this file and updates **Last reviewed**.
