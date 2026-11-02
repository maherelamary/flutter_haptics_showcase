# Component recipes

Each recipe is the essential wiring for one component, with the reasoning kept to a line or two. Names like `AppHaptics.x`, `AppPatterns.x` and `HapticPacer` refer to `references/setup.md`. Handles come from `FlutterHaptics.register(pattern)` (flutter_haptics 1.0): synchronous, held as a plain `final` field, paced to the device, disposed in `dispose()`.

Contents:

1. Buttons
2. Selection controls
3. Sliders, pickers, steppers
4. Gestures
5. Input
6. Feedback and async results
7. Commit gestures
8. Expressive and continuous haptics
9. Patterns from designers (AHAP) and per-platform tuning

---

## 1. Buttons

```dart
// Primary action
FilledButton(
  onPressed: () {
    FlutterHaptics.perform(AppHaptics.press);
    save();
  },
  child: const Text('Save changes'),
);

// Icon buttons, chips that act, secondary actions
IconButton(onPressed: () { FlutterHaptics.perform(AppHaptics.tap); share(); }, icon: …);

// Destructive: caution as the question appears; confirm = press; cancel = silent
Future<void> confirmDelete() async {
  FlutterHaptics.perform(AppHaptics.caution);
  final ok = await showDialog<bool>(/* … */);
  if (ok == true) {
    FlutterHaptics.perform(AppHaptics.press);
    deleteAccount();
  }
}

// Disabled: onPressed: null — no haptic, ever.
```

**Like / favourite.** The positive action is richer than its reversal:

```dart
void toggleLike() {
  final liked = !this.liked;
  FlutterHaptics.play(liked ? AppPatterns.pop : AppPatterns.unpop);
  burst.forward(from: 0); // same frame
  setState(() => this.liked = liked);
}
```

**Copy to clipboard.** Fire on the outcome, once:

```dart
Future<void> copy() async {
  if (_copied) return;                       // already copied — quiet
  await Clipboard.setData(ClipboardData(text: link));
  FlutterHaptics.perform(AppHaptics.tap);    // only once it worked
  setState(() => _copied = true);
}
```

## 2. Selection controls

```dart
// Switch: direction you can feel
Switch(
  value: on,
  onChanged: (v) {
    FlutterHaptics.perform(v ? AppHaptics.switchOn : AppHaptics.switchOff);
    ref.read(settingsProvider.notifier).setNotifications(v);
  },
);

// Checkbox rows tick; select-all is ONE summarising haptic
void toggle(int i) { FlutterHaptics.perform(AppHaptics.tick); … }
void toggleAll() {
  final selectAll = checked.length != items.length;
  FlutterHaptics.play(selectAll ? HapticPatterns.doubleClick : HapticPatterns.soft);
  …
}

// Segmented control / tabs / radio / choice chip: tick only on change
onSelectionChanged: (s) {
  if (s.first == period) return;
  FlutterHaptics.perform(AppHaptics.tick);
  ref.read(periodProvider.notifier).select(s.first);
},

// Bottom navigation: tick on change; re-tap (pop to root) is silent
onDestinationSelected: (i) {
  if (i != shell.currentIndex) FlutterHaptics.perform(AppHaptics.tick);
  shell.goBranch(i, initialLocation: i == shell.currentIndex);
},
```

**Star rating.** Strength rises with the value:

```dart
static HapticPattern patternFor(int stars) => HapticPattern([
  TransientEvent(intensity: 0.35 + 0.15 * (stars - 1), sharpness: 0.3 + 0.15 * (stars - 1)),
]);
void onTap(int stars) =>
    FlutterHaptics.play(stars == 5 ? AppPatterns.pop : patternFor(stars));
```

## 3. Sliders, pickers, steppers

**Slider with notches and end stops.** Registered (the handle paces itself), once per crossing:

```dart
final _detent = FlutterHaptics.register(AppPatterns.detent);
bool _atLimit = false;

void onChanged(double next) {
  if (notchOf(next) != notchOf(value)) _detent.play(); // `none` if paced out
  final atLimit = next <= min || next >= max;
  if (atLimit && !_atLimit) FlutterHaptics.perform(AppHaptics.limit);
  _atLimit = atLimit;
  setState(() => value = next);
}

@override
void dispose() { _detent.dispose(); super.dispose(); }
```

With the stock `Slider(divisions: n)`, `onChanged` only fires on discrete values, so compare to the previous value and tick on change.

**Wheel picker (`ListWheelScrollView`, `CupertinoPicker`)**

```dart
// Paced to the device: 25 ms on full fidelity, 60 ms on a rotary motor.
final _tick = FlutterHaptics.register(HapticPatterns.selection);

ListWheelScrollView.useDelegate(
  itemExtent: 40,
  physics: const FixedExtentScrollPhysics(),
  onSelectedItemChanged: (i) {
    _tick.play();
    setState(() => hour = i % 12 + 1);
  },
  childDelegate: …,
);
```

The pattern handle is the trade-off for now: `register` can't hold an intent, so a picker that wants iOS's own selection tick has to `perform(AppHaptics.tick)` behind a `HapticPacer` instead.

**Tame the physics, or the ticks become a buzz.** A looping wheel with stock iOS momentum can spin for seconds after a few quick flicks, because momentum stacks across flicks, and every item it passes ticks. Cap the fling:

```dart
class WheelPhysics extends FixedExtentScrollPhysics {
  const WheelPhysics({super.parent = const BouncingScrollPhysics(
      decelerationRate: ScrollDecelerationRate.fast)});
  @override
  WheelPhysics applyTo(ScrollPhysics? ancestor) => WheelPhysics(parent: buildParent(ancestor));
  @override
  double get maxFlingVelocity => 2400;               // ~1 s spin at most
  @override
  double carriedMomentum(double existingVelocity) => 0; // flicks don't stack
}
```

`CupertinoPicker` already plays a selection haptic on iOS. Don't add a second one; on Android add the same `_tick` there.

**Stepper with limits and auto-repeat**

```dart
void step(int delta) {
  final next = qty + delta;
  if (next < min || next > max) {
    FlutterHaptics.perform(AppHaptics.limit);
    shake.shake();                             // felt and seen together
    return;
  }
  FlutterHaptics.perform(AppHaptics.tick);
  setState(() => qty = next);
}
// Long-press auto-repeat: intents can't be registered yet → a pattern handle,
// which paces itself as the repeat speeds up
final _repeat = FlutterHaptics.register(HapticPatterns.selection);
void repeatStep(int d) { _repeat.play(); … }
```

**Media scrubber.** Tick chapter boundaries, never seconds:

```dart
// final _boundary = FlutterHaptics.register(AppPatterns.fineDetent);
if (chapterAt(next) != chapterAt(position)) _boundary.play();
// drag end: silent — the position is the feedback
```

## 4. Gestures

**Pull-to-refresh (custom).** Armed, disarmed, outcome:

```dart
bool _onScroll(ScrollNotification n) {
  final pull = n.metrics.minScrollExtent - n.metrics.pixels;
  if (n is ScrollUpdateNotification && n.dragDetails == null) {
    if (_armed) _refresh();                    // finger lifted while armed
    _armed = false;
  } else if (!_armed && pull >= 80) {
    _armed = true;
    FlutterHaptics.perform(AppHaptics.armed);
  } else if (_armed && pull < 80) {
    _armed = false;
    FlutterHaptics.perform(AppHaptics.disarmed);
  }
  return false;
}
Future<void> _refresh() async {
  await repository.fetchLatest();              // no haptics while waiting
  if (mounted) FlutterHaptics.perform(AppHaptics.success);
}
```

With the stock `RefreshIndicator`, only play `success` in `onRefresh` after the data lands.

**Swipe actions (`Dismissible`)**

```dart
Dismissible(
  key: ValueKey(item.id),
  onUpdate: (d) {
    if (d.reached && !d.previousReached) FlutterHaptics.perform(AppHaptics.armed);
    if (!d.reached && d.previousReached) FlutterHaptics.perform(AppHaptics.disarmed);
  },
  onDismissed: (dir) {
    FlutterHaptics.perform(AppHaptics.press);
    remove(item);
    showUndo(onUndo: () {
      FlutterHaptics.play(AppPatterns.rewind);   // the action running backwards
      restore(item);
    });
  },
  child: Row(…),
)
```

**Long-press context menu.** Open heavy, slide ticks, release selects:

```dart
GestureDetector(
  onLongPressStart: (_) { FlutterHaptics.perform(AppHaptics.longPress); openMenu(); },
  onLongPressMoveUpdate: (d) {
    final item = itemAt(d.globalPosition);
    if (item != _hovered) {
      _hovered = item;
      if (item != null && _pacer.ready()) FlutterHaptics.perform(AppHaptics.tick);
    }
  },
  onLongPressEnd: (d) {
    final item = itemAt(d.globalPosition);
    if (item != null) { FlutterHaptics.perform(AppHaptics.tap); item.run(); }
    closeMenu();                               // releasing outside: silent
  },
  child: card,
)
```

**Reorderable list.** Lift and drop, nothing in between:

```dart
ReorderableListView(
  onReorderItem: (from, to) => …,          // Flutter 3.44+ (3.42 beta); older: onReorder,
                                           // and subtract 1 from newIndex when it's > oldIndex
  onReorderStart: (_) => FlutterHaptics.perform(AppHaptics.lift),
  onReorderEnd: (_) => FlutterHaptics.perform(AppHaptics.drop),
  children: …,
)
```

**Bottom sheet snap points**

```dart
NotificationListener<DraggableScrollableNotification>(
  onNotification: (n) {
    final band = snapPoints.where((p) => n.extent >= p - 0.01).length;
    if (band != _band) { _band = band; FlutterHaptics.perform(AppHaptics.detent); }
    return false;
  },
  child: DraggableScrollableSheet(snap: true, snapSizes: …, builder: …),
)
```

**PageView / carousel.** The page change is the selection, the swipe is silent:

```dart
onPageChanged: (i) { FlutterHaptics.perform(AppHaptics.tick); setState(() => page = i); },
```

**Swipe-to-reply (custom drag threshold).** Same armed/disarmed shape as pull-to-refresh, with the threshold on `dx` (~60 px). Release while armed commits silently, because the reply chip appearing is the feedback.

## 5. Input

**PIN / OTP keypad**

```dart
GestureDetector(onTapDown: (_) => _digit('5'), child: const KeyCap('5')); // act on touch-down

void _digit(String d) {
  if (_pin.length == length) return;
  FlutterHaptics.perform(AppHaptics.key);
  setState(() => _pin += d);
  if (_pin.length == length) Timer(const Duration(milliseconds: 160), _check); // let the click land
}

void _check() {
  if (valid(_pin)) {
    FlutterHaptics.perform(AppHaptics.success);
  } else {
    FlutterHaptics.perform(AppHaptics.failure);
    _shake.shake();
    _clearAfterFlash();
  }
}
```

**Form validation.** One `failure`, shake and focus the first invalid field:

```dart
void submit() {
  final firstInvalid = fields.firstWhereOrNull((f) => f.validate() != null);
  if (firstInvalid != null) {
    FlutterHaptics.perform(AppHaptics.failure);
    firstInvalid.shake();
    firstInvalid.focus.requestFocus();
    return;
  }
  FlutterHaptics.perform(AppHaptics.success);
  send();
}
// Typing in TextFields: silent (the keyboard owns it).
```

**Character limit.** Feel the wall once, re-arm when there's room:

```dart
onChanged: (text) {
  final n = text.characters.length;
  if (n >= max && !_atLimit) { _atLimit = true; FlutterHaptics.perform(AppHaptics.limit); }
  else if (n < max) { _atLimit = false; }
},
```

## 6. Feedback and async results

**Async action with Riverpod.** The canonical pattern:

```dart
// Domain: knows nothing about haptics
class SaveProfile extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> save(Profile p) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() => repository.save(p));
    if (ref.mounted) state = result; // Riverpod 3 throws on a disposed ref
  }
}

// Presentation: decides what each outcome feels like
ref.listen(saveProfileProvider, (previous, next) {
  if (previous?.isLoading != true || next.isLoading) return;
  if (next.hasError) {
    FlutterHaptics.perform(AppHaptics.failure);
    shake.shake();
  } else {
    FlutterHaptics.perform(AppHaptics.success);
  }
});
```

**Inline notifications**

```dart
FlutterHaptics.perform(AppHaptics.success);   // notificationSuccess / CONFIRM
FlutterHaptics.perform(AppHaptics.failure);   // notificationError / REJECT
FlutterHaptics.perform(AppHaptics.caution);   // notificationWarning / the pattern, by choice
```

**Undo snackbar.** Delete = `press`, Undo = `rewind`, the snackbar appearing is silent.

**Progress with milestones.** Only when the user is watching the bar:

```dart
..addListener(() {
  final passed = [0.25, 0.5, 0.75].where((m) => progress.value >= m).length;
  if (passed > _passed) { _passed = passed; FlutterHaptics.perform(AppHaptics.fineDetent); }
})
..addStatusListener((s) {
  if (s == AnimationStatus.completed) FlutterHaptics.perform(AppHaptics.success);
});
```

For background downloads: no milestones, just `success` if the user is on that screen.

**Chat**

- Sending a message: `play(AppPatterns.whoosh)` (a short swell).
- Incoming message while the thread is open and scrolled to the bottom: **silent**.
- Incoming message while the user has scrolled up: show a "New message" pill and play `perform(AppHaptics.tap)`.

## 7. Commit gestures

**Hold-to-confirm.** The curve matches the ring, and early release stops it:

```dart
void onPressStart() async {
  holding = true;
  ring.forward(from: 0); // 800 ms, from empty: chargeUp starts from silence
  final support = await FlutterHaptics.support;
  if (support.supportsContinuous) {
    FlutterHaptics.play(HapticPatterns.chargeUp);   // 800 ms rising curve
  } else {
    startRisingTaps();                               // iPhone 7 / UIKit fallback
  }
}
void onPressEnd() {
  if (ring.isCompleted) return;
  holding = false;
  FlutterHaptics.stop().then((_) {
    // Pressed again while stopping: the soft tap would land on the new rumble.
    if (!holding && mounted) FlutterHaptics.play(HapticPatterns.soft);
  });
  ring.animateBack(0);
}
void onRingCompleted() => FlutterHaptics.play(AppPatterns.lock);
@override
void dispose() { if (holding) FlutterHaptics.stop(); super.dispose(); }
```

A screen reader's double tap is a press and an immediate release, which aborts the hold. Give the control an action of its own, `Semantics(button: true, label: 'Hold to delete', onTap: confirm, child: …)`. The same goes for slide-to-confirm, which a screen reader can't drag.

**Slide-to-confirm.** There's no real-time rumble modulation, so rising discrete ticks carry the tension:

```dart
final _steps = [for (final i in [0.25, 0.4, 0.55, 0.7, 0.9])
  FlutterHaptics.register(HapticPattern([TransientEvent(intensity: i, sharpness: 0.7)]))];
// Five handles, one budget: each handle paces only itself.
final _pacer = HapticPacer(minInterval: const Duration(milliseconds: 28));

void onDrag(double progress) {
  final step = (progress / 0.08).floor();
  if (step != _lastStep && _pacer.ready()) {
    _lastStep = step;
    _steps[(progress * (_steps.length - 1)).round()].play();
  }
}
void onCommit() => FlutterHaptics.play(AppPatterns.lock);
void onRelease() => FlutterHaptics.play(HapticPatterns.soft);   // springs back
```

## 8. Expressive and continuous haptics

**Physics impacts.** Intensity ∝ speed, sharpness = material, slow hits silent, paced:

```dart
void onImpact(double speed, Material m) {
  if (speed < silentBelow || !_pacer.ready()) return;
  final strength = ((speed - silentBelow) / (fullAt - silentBelow)).clamp(0.1, 1.0);
  _impacts[m]![(strength * 4).round()].play();   // 5 prepared strengths per material
}
```

**Textures.** Emit by distance travelled, not by time:

```dart
void onPanUpdate(DragUpdateDetails d) {
  _travel += directional ? d.delta.dx.abs() : d.delta.distance;
  if (_travel < _nextAt) return;
  _travel = 0;
  _nextAt = surface.spacing();          // e.g. gravel: random 10–30 px
  if (_pacer.ready()) surface.pickHandle().play();
}
```

**Rhythm (metronome, timers).** Prepared handles, scheduled from an anchor so they don't drift:

```dart
void schedule() {
  final due = anchor + interval * n;
  timer = Timer(due - clock.elapsed, fire);
}
void fire() { (beat % meter == 0 ? _accent : _beat).play(); beat++; n++; schedule(); }
```

A `Timer` is not a ticker: it keeps firing when its page sits offstage in a tab shell, and after the app is hidden. Stop the beat when `TickerMode` turns off and in `AppLifecycleListener(onHide: …)`.

**Long, gentle guidance (breathing, meditation)**

```dart
static const inhale = HapticPattern([
  ContinuousEvent.curved(
    intensity: LinearParam(from: 0.05, to: 0.35),   // faint on purpose
    sharpness: ConstantParam(0.12),
    duration: Duration(seconds: 4),
  ),
]);
// On rhythm-tier hardware a 4 s rumble is an alarm: fall back to one tap per second.
```

**Information by rhythm (Morse, codes, patterns of taps)**

```dart
// Standard Morse in units: dot 1, dash 3, gap inside a letter 1,
// between letters 3 (words are left out of this sketch). Dots land 180 ms apart: every tier reads it.
const unit = 90; // ms
final b = HapticPatternBuilder();
for (final letter in letters) {        // codes, e.g. ['....', '..'] for "HI"
  for (final symbol in letter.split('')) {
    symbol == '.'
        ? b.tap(intensity: 0.8, sharpness: 0.8)
            .waitMs(unit - HapticEvent.transientWidth.inMilliseconds) // tap() advances 25 ms
        : b.rumble(duration: const Duration(milliseconds: unit * 3), intensity: 0.8);
    b.waitMs(unit);
  }
  b.waitMs(unit * 2); // three units between letters in all
}
FlutterHaptics.play(b.build());
// Stop button: FlutterHaptics.stop()
```

**Game feel**

| Moment | Pattern |
|---|---|
| hit | `HapticPatterns.impactDecay` |
| explosion | `HapticPatterns.explosion` |
| power-up charging | `HapticPatterns.chargeUp` |
| coin | two rising pings |
| landing | `AppPatterns.thud` |

Use `overlay` (`|`) to layer a tap over a rumble.

## 9. Patterns from designers (AHAP) and per-platform tuning

```dart
// pubspec: assets: [assets/haptics/]
final boing = await Ahap.loadAsset('assets/haptics/boing.ahap');
final handle = FlutterHaptics.register(boing);   // if replayed often; dispose it later

// Serialise a pattern for a designer or a backend
final json = Ahap.encode(AppPatterns.celebrate, metadata: {'Project': 'MyApp'});
```

Audio events in an AHAP are dropped. Curves are limited to 16 control points (`encode` throws `StateError` beyond that).

**Per-platform tuning** stays out of call sites:

```dart
static final explosion = HapticPattern.forPlatform(
  ios: HapticPatterns.explosion,
  android: HapticPatternBuilder()
      .rumbleCurved(intensity: HapticParam.spike, duration: const Duration(milliseconds: 400))
      .build(),
);
```

**Choosing by capability rather than platform**

```dart
final support = await FlutterHaptics.support;
FlutterHaptics.play(support.supportsSharpness ? HapticPatterns.chargeUp : HapticPatterns.success);
```
