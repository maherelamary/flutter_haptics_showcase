import 'package:flutter/material.dart';
import 'package:flutter_haptics_showcase/src/core/showcase/showcase_entry.dart';
import 'package:flutter_haptics_showcase/src/features/gallery/presentation/demos/controls/button_family_demo.dart';
import 'package:flutter_haptics_showcase/src/features/gallery/presentation/demos/controls/camera_shutter_demo.dart';
import 'package:flutter_haptics_showcase/src/features/gallery/presentation/demos/controls/chapter_scrubber_demo.dart';
import 'package:flutter_haptics_showcase/src/features/gallery/presentation/demos/controls/checkbox_list_demo.dart';
import 'package:flutter_haptics_showcase/src/features/gallery/presentation/demos/controls/copy_link_demo.dart';
import 'package:flutter_haptics_showcase/src/features/gallery/presentation/demos/controls/detent_slider_demo.dart';
import 'package:flutter_haptics_showcase/src/features/gallery/presentation/demos/controls/filter_chips_demo.dart';
import 'package:flutter_haptics_showcase/src/features/gallery/presentation/demos/controls/like_button_demo.dart';
import 'package:flutter_haptics_showcase/src/features/gallery/presentation/demos/controls/quantity_stepper_demo.dart';
import 'package:flutter_haptics_showcase/src/features/gallery/presentation/demos/controls/segmented_control_demo.dart';
import 'package:flutter_haptics_showcase/src/features/gallery/presentation/demos/controls/star_rating_demo.dart';
import 'package:flutter_haptics_showcase/src/features/gallery/presentation/demos/controls/switch_demo.dart';
import 'package:flutter_haptics_showcase/src/features/gallery/presentation/demos/controls/wheel_picker_demo.dart';

/// Gallery entries for buttons, selection controls, sliders and pickers.
final List<ShowcaseEntry> galleryControlsEntries = [
  // ─── Buttons ───────────────────────────────────────────────────────
  ShowcaseEntry(
    id: 'button-family',
    title: 'Button family',
    category: 'Buttons',
    summary:
        'Primary, secondary, destructive and disabled — four buttons, four '
        'levels of feedback, one of them none.',
    rationale:
        'Feedback strength follows the weight of the action. A primary '
        'commit gets a medium impact; a secondary, low-stakes tap gets a '
        'light one. The destructive button warns as its confirmation '
        'appears — the moment the user needs to pay attention — and '
        'confirming plays an ordinary press, because the dialog has already '
        'done the warning. Cancelling is silent: nothing happened. A '
        'disabled button stays silent too; buzzing "no" at a control that '
        'already looks unavailable punishes exploration and teaches users '
        'to distrust the feedback.',
    moments: const [
      HapticMoment('Tap Save changes', 'perform(AppHaptics.press)'),
      HapticMoment('Tap Preview', 'perform(AppHaptics.tap)'),
      HapticMoment(
        'Tap Delete account',
        'perform(AppHaptics.caution)',
        note: 'notificationWarning on iOS; the pattern, by choice, on Android.',
      ),
      HapticMoment('Confirm delete', 'perform(AppHaptics.press)'),
      HapticMoment('Cancel, or tap a disabled button', 'nothing'),
    ],
    code: r'''
FilledButton(
  onPressed: () {
    FlutterHaptics.perform(AppHaptics.press);
    save();
  },
  child: const Text('Save changes'),
);

Future<void> confirmDelete() async {
  FlutterHaptics.perform(AppHaptics.caution); // as the question appears
  final ok = await showDialog<bool>(/* … */);
  if (ok == true) {
    FlutterHaptics.perform(AppHaptics.press);
    deleteAccount();
  } // cancelling is silent
}

// Disabled: onPressed: null — no haptic, by design.''',
    builder: (context) => const ButtonFamilyDemo(),
    icon: Icons.smart_button_rounded,
    tags: const ['perform', 'play', 'restraint'],
  ),
  ShowcaseEntry(
    id: 'like-button',
    title: 'Like button',
    category: 'Buttons',
    summary:
        'A bright pop when you like, a barely-there tap when you take it '
        'back — and the same pop for a double-tap on the photo.',
    rationale:
        'Positive actions earn richer feedback than their reversal. The '
        'pop is short, crisp and fully sharp so it reads as delight; '
        'unliking is a soft, dull tap that acknowledges without '
        'celebrating. Both are custom patterns rather than system '
        'constants because they are brand moments, not platform semantics. '
        'The scale burst and the echo ring fire on the same frame as the '
        'haptic, so hand and eye agree. On a rhythm-tier motor the two '
        'patterns feel alike — the animation carries the difference there.',
    moments: const [
      HapticMoment('Like', 'play(AppPatterns.pop)'),
      HapticMoment('Unlike', 'play(AppPatterns.unpop)'),
      HapticMoment(
        'Double-tap the photo',
        'play(AppPatterns.pop)',
        note: 'Even when already liked: reaffirming is never an error.',
      ),
    ],
    code: r'''
void toggleLike() {
  final liked = !state.liked;
  FlutterHaptics.play(liked ? AppPatterns.pop : AppPatterns.unpop);
  burst.forward(from: 0); // same frame as the haptic
  setState(() => state = state.copyWith(liked: liked));
}
''',
    builder: (context) => const LikeButtonDemo(),
    icon: Icons.favorite_rounded,
    tags: const ['play', 'brand pattern', 'asymmetry'],
  ),
  ShowcaseEntry(
    id: 'copy-to-clipboard',
    title: 'Copy to clipboard',
    category: 'Buttons',
    summary:
        'One light tap when the link lands on the clipboard; silence if you '
        'tap again while the check mark is still showing.',
    rationale:
        'Copying is invisible — nothing on screen moves except the icon — so '
        'a light tap is the confirmation that it worked. A second tap within '
        'the confirmation window changes nothing, so it says nothing: a '
        'haptic should report an event, not echo every touch. The haptic '
        'fires only after Clipboard.setData resolves, so it never claims '
        'success before the copy actually happened.',
    moments: const [
      HapticMoment('Tap Copy', 'perform(AppHaptics.tap)'),
      HapticMoment('Tap again within 1.5 s', 'nothing'),
    ],
    code: r'''
Future<void> copy() async {
  if (_copied) return; // already on the clipboard — stay quiet
  await Clipboard.setData(ClipboardData(text: link));
  FlutterHaptics.perform(AppHaptics.tap); // only once it worked
  setState(() => _copied = true);
  _reset = Timer(const Duration(milliseconds: 1500), () {
    if (mounted) setState(() => _copied = false);
  });
}''',
    builder: (context) => const CopyLinkDemo(),
    icon: Icons.copy_rounded,
    tags: const ['perform', 'restraint'],
  ),
  ShowcaseEntry(
    id: 'camera-shutter',
    title: 'Camera shutter',
    category: 'Buttons',
    summary:
        'Tap for a two-stage mechanical shutter; hold for a burst of crisp '
        'single ticks that stop the instant you let go.',
    rationale:
        'A real shutter has two parts — mirror up, mirror down — and the '
        'pattern keeps that rhythm, which is why it still reads on a '
        'rhythm-tier motor. Burst mode fires about eight frames a second, '
        'so each frame is a single sharp tap from a registered handle: no '
        'per-call serialisation, and the handle\'s own pacing floor (25–60 '
        'ms, from the device) sits well under the 120 ms frame, so every '
        'frame lands and none fuse. Releasing is silent; the ticks stopping '
        'is the feedback. The white flash lands on the same frame as every '
        'tick.',
    moments: const [
      HapticMoment('Tap the shutter', 'play(AppPatterns.shutter)'),
      HapticMoment(
        'Hold',
        'handle.play() every 120 ms',
        note: 'FlutterHaptics.register: one handle, paced by the device.',
      ),
      HapticMoment('Release', 'nothing'),
    ],
    code: r'''
final _frame = FlutterHaptics.register(const HapticPattern([
  TransientEvent(intensity: 0.6, sharpness: 1.0),
]));

void onTap() => FlutterHaptics.play(AppPatterns.shutter);

void onLongPressStart(_) {
  _burst = Timer.periodic(const Duration(milliseconds: 120), (_) {
    _frame.play(); // 120 ms apart: above any device's pacing floor
    capture();
  });
}

void onLongPressEnd(_) => _burst?.cancel(); // silent

@override
void dispose() {
  _burst?.cancel(); // leaving mid-burst must not keep capturing
  _frame.dispose();
  super.dispose();
}''',
    builder: (context) => const CameraShutterDemo(),
    icon: Icons.camera_rounded,
    tags: const ['play', 'register()'],
  ),

  // ─── Selection ─────────────────────────────────────────────────────
  ShowcaseEntry(
    id: 'switch',
    title: 'Switch',
    category: 'Selection',
    summary:
        'On feels bright and crisp, off feels soft and dull — the direction '
        'of a switch you can feel without looking.',
    rationale:
        'A switch has two outcomes, so it should have two feels. On is a '
        'light impact (crisp pattern), off a soft one (dull pattern). '
        'Android has dedicated toggleOn and toggleOff constants from API '
        '34; below that, the intent recovers with the matching pattern. '
        'iOS has no toggle constant at all, so AppHaptics pairs light and '
        'soft impacts — a choice made once in AppHaptics, never at a call '
        'site. The switch thumb moves on the same frame.',
    moments: const [
      HapticMoment(
        'Switch on',
        'perform(AppHaptics.switchOn)',
        note: 'Android toggleOn needs API 34; pattern below.',
      ),
      HapticMoment(
        'Switch off',
        'perform(AppHaptics.switchOff)',
        note: 'Android toggleOff needs API 34; pattern below.',
      ),
    ],
    code: r'''
Switch(
  value: notifications,
  onChanged: (on) {
    FlutterHaptics.perform(
      on ? AppHaptics.switchOn : AppHaptics.switchOff,
    );
    ref.read(settingsProvider.notifier).setNotifications(on);
  },
);
''',
    builder: (context) => const SwitchDemo(),
    icon: Icons.toggle_on_rounded,
    tags: const ['perform', 'API 34'],
  ),
  ShowcaseEntry(
    id: 'checkbox-list',
    title: 'Checkbox list',
    category: 'Selection',
    summary:
        'Each item ticks; Select all plays one double-click for the whole '
        'batch instead of a tick per row.',
    rationale:
        'One action, one haptic. Ticking an item is a single selection '
        'change, so it gets the selection tick. Select all changes five '
        'rows at once, but the user did one thing — firing five ticks would '
        'turn a confident gesture into a rattle. A double-click summarises '
        'the batch; clearing everything gets a single soft tap, the quieter '
        'reversal. Strikethrough and checkbox fill animate on the same '
        'frame.',
    moments: const [
      HapticMoment('Tick an item', 'perform(AppHaptics.tick)'),
      HapticMoment('Select all', 'play(HapticPatterns.doubleClick)'),
      HapticMoment('Clear all', 'play(HapticPatterns.soft)'),
    ],
    code: r'''
void toggle(int i) {
  FlutterHaptics.perform(AppHaptics.tick);
  setState(() => checked.contains(i) ? checked.remove(i) : checked.add(i));
}

void toggleAll() {
  final selectAll = checked.length != items.length;
  // One summarising haptic for the batch — never one per row.
  FlutterHaptics.play(
    selectAll ? HapticPatterns.doubleClick : HapticPatterns.soft,
  );
  setState(() => selectAll ? checked.addAll(allIds) : checked.clear());
}''',
    builder: (context) => const CheckboxListDemo(),
    icon: Icons.checklist_rounded,
    tags: const ['perform', 'play', 'batch'],
  ),
  ShowcaseEntry(
    id: 'segmented-control',
    title: 'Segmented control',
    category: 'Selection',
    summary:
        'A period switcher that ticks when the value changes — and only '
        'then.',
    rationale:
        'A segmented control is a picker laid flat, so it uses the same '
        'selection tick as a wheel: iOS selection, Android clockTick. The '
        'haptic is tied to the value changing, not to the touch, so '
        're-tapping the current segment stays quiet. The chart below '
        'reshapes on the same frame, which is what makes the tick feel like '
        'the data clicking into place.',
    moments: const [
      HapticMoment('Pick a different period', 'perform(AppHaptics.tick)'),
      HapticMoment('Tap the current period', 'nothing'),
    ],
    code: r'''
SegmentedButton<Period>(
  segments: [/* Day, Week, Month, Year */],
  selected: {period},
  onSelectionChanged: (selection) {
    if (selection.first == period) return; // no change, no tick
    FlutterHaptics.perform(AppHaptics.tick);
    ref.read(periodProvider.notifier).select(selection.first);
  },
);''',
    builder: (context) => const SegmentedControlDemo(),
    icon: Icons.view_week_rounded,
    tags: const ['perform'],
  ),
  ShowcaseEntry(
    id: 'filter-chips',
    title: 'Filter chips',
    category: 'Selection',
    summary:
        'Filter chips (any number) and choice chips (exactly one) tick on '
        'every real change; re-picking the current choice is silent.',
    rationale:
        'Toggling a filter changes what the user will see, so it ticks. A '
        'choice chip that is already selected changes nothing when tapped '
        'again, so it stays quiet — the rule everywhere in this app is that '
        'haptics report state changes, not touches. Chips that run an '
        'action rather than filter (share, open) would use AppHaptics.tap '
        'instead of tick.',
    moments: const [
      HapticMoment('Toggle a filter chip', 'perform(AppHaptics.tick)'),
      HapticMoment('Pick a new distance', 'perform(AppHaptics.tick)'),
      HapticMoment('Tap the selected distance', 'nothing'),
    ],
    code: r'''
FilterChip(
  label: Text(filter),
  selected: active.contains(filter),
  onSelected: (on) {
    FlutterHaptics.perform(AppHaptics.tick);
    setState(() => on ? active.add(filter) : active.remove(filter));
  },
);

ChoiceChip(
  label: Text(d),
  selected: d == distance,
  onSelected: (_) {
    if (d == distance) return; // already chosen — silent
    FlutterHaptics.perform(AppHaptics.tick);
    setState(() => distance = d);
  },
);''',
    builder: (context) => const FilterChipsDemo(),
    icon: Icons.filter_alt_rounded,
    tags: const ['perform'],
  ),
  ShowcaseEntry(
    id: 'star-rating',
    title: 'Star rating',
    category: 'Selection',
    summary:
        'Each star is a little stronger and crisper than the last, so the '
        'rating is something you feel; five stars pops.',
    rationale:
        'Rising intensity maps the scale onto the hand: one star is soft '
        'and dull, four is firm and bright, and five gets the brand pop '
        'with a sparkle. Dragging across the row replays five registered '
        'handles, paced so a quick swipe stays a ripple rather than a buzz; '
        'only a five-star commit adds the extra pop at the end. On '
        'intensity-tier Android the sharpness steps flatten but the '
        'strength still climbs; on a rhythm-tier motor every star feels '
        'the same and the animation carries the scale.',
    moments: const [
      HapticMoment(
        'Tap star n (1–4)',
        'play(TransientEvent(0.35 + 0.15·(n−1)))',
      ),
      HapticMoment('Tap star 5', 'play(AppPatterns.pop)'),
      HapticMoment(
        'Drag across stars',
        'handle[n].play() per star crossed',
        note: 'Five handles sharing one 40 ms HapticPacer.',
      ),
      HapticMoment('Finish a drag on 5', 'play(AppPatterns.pop)'),
    ],
    code: r'''
static HapticPattern patternFor(int stars) => HapticPattern([
  TransientEvent(
    intensity: 0.35 + 0.15 * (stars - 1),
    sharpness: 0.3 + 0.15 * (stars - 1),
  ),
]);

final _steps = [
  for (var n = 1; n <= 5; n++) FlutterHaptics.register(patternFor(n)),
];
// Each handle paces only itself; five of them need one shared budget.
final _pacer = HapticPacer();

void onTap(int stars) => FlutterHaptics.play(
  stars == 5 ? AppPatterns.pop : patternFor(stars),
);

void onDrag(int stars) {
  if (stars != rating && _pacer.ready()) _steps[stars - 1].play();
}''',
    builder: (context) => const StarRatingDemo(),
    icon: Icons.star_rounded,
    tags: const ['play', 'register()', 'intensity'],
  ),

  // ─── Sliders & pickers ─────────────────────────────────────────────
  ShowcaseEntry(
    id: 'detent-slider',
    title: 'Detent slider',
    category: 'Sliders & pickers',
    summary:
        'Notches you feel every 10%, a magnetic centre that snaps and '
        'thuds, and end stops that say "no further" exactly once.',
    rationale:
        'Detents let the hand count: you can set 70% with your eyes closed. '
        'Each notch is a crisp registered tap; the handle paces itself to '
        'the device, so a fast drag never turns into a continuous buzz. The 50% notch is magnetic — the thumb '
        'snaps within ±3 and lands with a heavier, duller tap that reads as '
        '"home". The ends play AppHaptics.limit once per arrival; staying '
        'pinned against a limit is silent, because repeating "no" while the '
        'user holds still is noise. The notch under the finger pulses on '
        'the same frame.',
    moments: const [
      HapticMoment(
        'Cross a notch',
        'handle(AppPatterns.detent).play()',
        note: 'Paced by the handle: 25–60 ms, from the device.',
      ),
      HapticMoment('Snap to 50', 'handle(magnet).play()'),
      HapticMoment(
        'Arrive at 0 or 100',
        'perform(AppHaptics.limit)',
        note: 'Once per arrival, not while pinned.',
      ),
    ],
    code: r'''
final _detent = FlutterHaptics.register(AppPatterns.detent); // paces itself
bool _atLimit = false;

void onDrag(double next) {
  if (crossedNotch(value, next)) _detent.play();

  final atLimit = next <= 0 || next >= 100;
  if (atLimit && !_atLimit) FlutterHaptics.perform(AppHaptics.limit);
  _atLimit = atLimit; // say "no further" once, not every frame

  setState(() => value = next);
}

@override
void dispose() {
  _detent.dispose();
  super.dispose();
}''',
    builder: (context) => const DetentSliderDemo(),
    icon: Icons.linear_scale_rounded,
    tags: const ['register()', 'perform'],
  ),
  ShowcaseEntry(
    id: 'wheel-picker',
    title: 'Wheel picker',
    category: 'Sliders & pickers',
    summary:
        'A time picker whose wheels click past every value, like a physical '
        'dial — even mid-fling.',
    rationale:
        'A wheel is the textbook case for a registered handle: a single '
        'fling passes dozens of values a second, and play() would rebuild '
        'and re-send the pattern every time. The handle is prepared once, '
        'and paces itself to the device\'s floor, keeping ticks distinct when '
        'values fly by faster than the actuator can separate them — the '
        'counter shows how many were paced out, and the floor in force. The tick fires on selected-item change, the same '
        'moment the value highlights. The physics matter too: a looping wheel '
        'with stock iOS momentum can spin for seconds, and every item it '
        'passes ticks — so the fling is capped and never stacks.',
    moments: const [
      HapticMoment(
        'Each value passing the centre',
        'handle(HapticPatterns.selection).play()',
        note: 'Paced by the handle: 25–60 ms, from the device.',
      ),
      HapticMoment(
        'Flick hard, then again',
        'ticks stop as the wheel settles',
        note: 'WheelPhysics: capped fling, no carried momentum, fast decay.',
      ),
    ],
    code: r'''
// Synchronous, and paced to the device: 25 ms on Core Haptics or an
// envelope-capable Android, 60 ms on a rotary motor.
final _tick = FlutterHaptics.register(HapticPatterns.selection);

ListWheelScrollView.useDelegate(
  itemExtent: 40,
  physics: const WheelPhysics(), // capped fling, no stacked momentum
  onSelectedItemChanged: (i) {
    _tick.play(); // returns HapticRoute.none when paced out
    setState(() => hour = i % 12 + 1);
  },
  childDelegate: ListWheelChildLoopingListDelegate(children: hours),
);

@override
void dispose() {
  _tick.dispose();
  super.dispose();
}''',
    builder: (context) => const WheelPickerDemo(),
    icon: Icons.schedule_rounded,
    tags: const ['register()', 'minInterval'],
  ),
  ShowcaseEntry(
    id: 'quantity-stepper',
    title: 'Quantity stepper',
    category: 'Sliders & pickers',
    summary:
        'Tick per step, a bump and shake at the limits, and a long-press '
        'repeat that speeds up as you hold.',
    rationale:
        'Each tap is a selection change, so it ticks. At 0 or 10 the '
        'buttons stay tappable on purpose: the limit bump plus a shake '
        'explains why nothing changed, which a greyed-out silent button '
        'cannot. Holding auto-repeats with an accelerating rhythm; each '
        'repeat ticks through a registered handle, which paces itself (an '
        'intent cannot be registered yet), and running into a limit while '
        'repeating stops the repeat with a single bump.',
    moments: const [
      HapticMoment('Tap − or +', 'perform(AppHaptics.tick)'),
      HapticMoment(
        'Tap at 0 or 10',
        'perform(AppHaptics.limit)',
        note: 'Paired with a shake.',
      ),
      HapticMoment(
        'Hold − or +',
        'handle(selection).play() per step',
        note: 'Repeat accelerates from 220 ms to 60 ms.',
      ),
    ],
    code: r'''
void step(int delta) {
  final next = qty + delta;
  if (next < 0 || next > 10) {
    FlutterHaptics.perform(AppHaptics.limit);
    shake.shake(); // felt and seen together
    return;
  }
  FlutterHaptics.perform(AppHaptics.tick);
  setState(() => qty = next);
}

// Auto-repeat: an intent can't be registered yet, so use a pattern handle.
// It paces itself, so the fastest repeats never fuse.
final _repeatTick = FlutterHaptics.register(HapticPatterns.selection);

void repeatStep(int delta) {
  _repeatTick.play();
  setState(() => qty += delta);
}''',
    builder: (context) => const QuantityStepperDemo(),
    icon: Icons.exposure_rounded,
    tags: const ['perform', 'register()', 'Shaker'],
  ),
  ShowcaseEntry(
    id: 'chapter-scrubber',
    title: 'Chapter scrubber',
    category: 'Sliders & pickers',
    summary:
        'A media scrubber that is silent while you scrub and ticks only as '
        'you cross a chapter boundary.',
    rationale:
        'Ticking every second of a four-minute track would be a buzz with '
        'no information in it. Ticking only at chapter boundaries turns the '
        'haptic into structure: you can feel where one section ends and the '
        'next begins without watching the bar. The tick is the lightest one '
        'in the app — fineDetent — because scrubbing is continuous and '
        'chapters can be close together. Letting go is silent: the new '
        'position is the result, and it is already on screen.',
    moments: const [
      HapticMoment(
        'Cross a chapter boundary',
        'handle(AppPatterns.fineDetent).play()',
        note: 'Paced by the handle: 25–60 ms, from the device.',
      ),
      HapticMoment('Scrub within a chapter', 'nothing'),
      HapticMoment('Release', 'nothing'),
    ],
    code: r'''
final _boundary = FlutterHaptics.register(AppPatterns.fineDetent);

void onScrub(double next) {
  // One tick per boundary crossed — never one per second.
  if (chapterAt(next) != chapterAt(position)) _boundary.play();
  setState(() => position = next);
}

// onHorizontalDragEnd: nothing — the position is the feedback.''',
    builder: (context) => const ChapterScrubberDemo(),
    icon: Icons.slideshow_rounded,
    tags: const ['register()', 'restraint'],
  ),
];
