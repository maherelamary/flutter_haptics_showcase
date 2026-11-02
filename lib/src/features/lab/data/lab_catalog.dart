import 'package:flutter/material.dart';
import 'package:flutter_haptics_showcase/src/core/showcase/showcase_entry.dart';
import 'package:flutter_haptics_showcase/src/features/lab/presentation/demos/bouncing_balls_demo.dart';
import 'package:flutter_haptics_showcase/src/features/lab/presentation/demos/breathing_coach_demo.dart';
import 'package:flutter_haptics_showcase/src/features/lab/presentation/demos/dice_roll_demo.dart';
import 'package:flutter_haptics_showcase/src/features/lab/presentation/demos/hold_to_confirm_demo.dart';
import 'package:flutter_haptics_showcase/src/features/lab/presentation/demos/metronome_demo.dart';
import 'package:flutter_haptics_showcase/src/features/lab/presentation/demos/morse_code_demo.dart';
import 'package:flutter_haptics_showcase/src/features/lab/presentation/demos/safe_dial_demo.dart';
import 'package:flutter_haptics_showcase/src/features/lab/presentation/demos/slide_to_confirm_demo.dart';
import 'package:flutter_haptics_showcase/src/features/lab/presentation/demos/texture_pad_demo.dart';

/// Every experiment in the Lab, in display order.
abstract final class LabCatalog {
  /// Category order on the Lab page.
  static const categories = <String>[
    'Commit gestures',
    'Materials',
    'Physics & play',
    'Rhythm',
  ];

  static final List<ShowcaseEntry> entries = [
    // ─── Commit gestures ───────────────────────────────────────────────
    ShowcaseEntry(
      id: 'slide-to-confirm',
      title: 'Slide to confirm',
      category: 'Commit gestures',
      summary:
          'Ticks tighten and strengthen as the knob travels, then one '
          'heavy lock at the end.',
      rationale:
          'There is no API to modulate a rumble in real time while a '
          'finger moves, so tension is built from discrete ticks instead: '
          'their spacing follows n·p^1.8, so they crowd together near the end, '
          'and they climb a ladder of five prepared strengths. The approach '
          'to the point of no return becomes something you feel without '
          'looking. The commit itself gets exactly one strong moment — a lock '
          '— because doubling it with a success notification would blur the '
          'payoff. Letting go early deflates with a soft tap as the knob '
          'springs home, so abandoning the gesture is acknowledged too.',
      moments: const [
        HapticMoment(
          'Drag the knob',
          'handle ladder (0.25 → 0.9)',
          note:
              'Closer together as you near the end; one 28 ms pacer for '
              'all five.',
        ),
        HapticMoment('Reach the end', 'AppPatterns.lock'),
        HapticMoment('Let go early', 'HapticPatterns.soft'),
      ],
      code: r'''
// Five strengths, registered once — this fires many times a second.
final _ladder = [
  for (var i = 0; i < 5; i++)
    FlutterHaptics.register(HapticPattern([
      TransientEvent(intensity: 0.25 + 0.1625 * i, sharpness: 0.4 + 0.14 * i),
    ])),
];
// Each handle paces only itself; the ladder shares one budget.
final _pacer = HapticPacer(minInterval: const Duration(milliseconds: 28));

// Spacing shrinks as progress grows: density rises with tension.
int tickAt(double p) => (16 * math.pow(p, 1.8)).floor();

void onDragUpdate(DragUpdateDetails d) {
  if (confirmed) return; // the lock plays once, not on every frame after
  final next = (progress + d.delta.dx / travel).clamp(0.0, 1.0);
  if (tickAt(next) > tickAt(progress) && _pacer.ready()) {
    _ladder[(next * 5).floor().clamp(0, 4)].play();
  }
  setState(() => progress = next);
  if (next >= 0.985) {
    FlutterHaptics.play(AppPatterns.lock); // one strong moment
    confirm(); // sets confirmed
  }
}

void onDragEnd(DragEndDetails _) {
  if (confirmed || progress == 0) return; // nothing to deflate
  FlutterHaptics.play(HapticPatterns.soft); // deflate
  springBack();
}''',
      builder: (context) => const SlideToConfirmDemo(),
      icon: Icons.swipe_right_alt_rounded,
      immersive: true,
      tags: const ['register()', 'HapticPacer', 'tension'],
    ),
    ShowcaseEntry(
      id: 'hold-to-confirm',
      title: 'Hold to confirm',
      category: 'Commit gestures',
      summary:
          'One rising curve plays for exactly as long as the ring fills; '
          'let go and stop() cuts it dead.',
      rationale:
          'For an irreversible action, a deliberate gesture is the '
          'safeguard, and the haptic makes the commitment physical: '
          'chargeUp is an 800 ms curve, matched to the ring, so the whole hold '
          'is a single call rather than a timer firing taps. The important '
          'part is releasing early — FlutterHaptics.stop() silences the curve '
          'mid-rise, and a soft tap confirms the abort; without stop() the '
          'rumble would keep building after the user changed their mind. '
          'Devices that cannot sustain a rumble (iPhone 7, iPads) are '
          'detected through support.supportsContinuous and climb in seven '
          'taps instead.',
      moments: const [
        HapticMoment(
          'Press and hold',
          'HapticPatterns.chargeUp',
          note: 'Taps climbing every 100 ms where rumbles cannot sustain.',
        ),
        HapticMoment('Release early', 'FlutterHaptics.stop() → soft'),
        HapticMoment('Ring completes', 'AppPatterns.lock'),
      ],
      code: r'''
void onPointerDown(PointerDownEvent _) async {
  ring.forward(from: ring.value);
  final support = await FlutterHaptics.support;
  if (support.supportsContinuous) {
    FlutterHaptics.play(HapticPatterns.chargeUp); // 800 ms = the ring
  } else {
    startRisingTaps(); // no sustained rumble on this device
  }
}

void onPointerUp(PointerEvent _) {
  if (ring.isCompleted) return;
  // Cut the curve mid-rise, then acknowledge the abort.
  FlutterHaptics.stop().then((_) => FlutterHaptics.play(HapticPatterns.soft));
  ring.animateBack(0);
}

void onRingCompleted() {
  FlutterHaptics.play(AppPatterns.lock);
}

@override
void dispose() {
  if (holding) FlutterHaptics.stop(); // never leave a curve running
  super.dispose();
}''',
      builder: (context) => const HoldToConfirmDemo(),
      icon: Icons.radio_button_checked_rounded,
      immersive: true,
      tags: const ['stop()', 'chargeUp', 'supportsContinuous'],
    ),

    // ─── Materials ─────────────────────────────────────────────────────
    ShowcaseEntry(
      id: 'safe-dial',
      title: 'Safe dial',
      category: 'Materials',
      summary:
          'Crack a combination by feel: every number clicks, the right '
          'one clicks heavier.',
      rationale:
          'Here the haptic is the information, not an echo of it. Two '
          'prepared clicks differ in exactly the two dimensions the hardware '
          'offers — the right number is stronger and duller — so a '
          'careful user can find it with their eyes closed. The ordinary '
          'click\'s handle is paced at 25 ms so a fast spin never smears '
          'into a buzz; the tumbler\'s handle opts out with Duration.zero, '
          'because missing it would break the puzzle. On a rhythm-tier motor intensity and sharpness '
          'vanish and the two clicks feel identical — a reminder that '
          'information carried by texture alone does not reach every phone.',
      moments: const [
        HapticMoment(
          'Turn past a number',
          'tap(0.35, sharpness 0.9)',
          note: 'Paced at 25 ms.',
        ),
        HapticMoment(
          'Pass the right number',
          'tap(0.8, sharpness 0.3)',
          note: 'minInterval: Duration.zero.',
        ),
        HapticMoment('Rest on it for 450 ms', 'AppPatterns.coin'),
        HapticMoment('Third number set', 'AppPatterns.lock'),
      ],
      code: r'''
final _click = FlutterHaptics.register(
  const HapticPattern([
    TransientEvent(intensity: 0.35, sharpness: 0.9), // ordinary: fine, crisp
  ]),
  minInterval: const Duration(milliseconds: 25),
);
final _tumbler = FlutterHaptics.register(
  const HapticPattern([
    TransientEvent(intensity: 0.8, sharpness: 0.3), // the one: heavy, dull
  ]),
  minInterval: Duration.zero, // never paced: it is the whole point
);

void onNumber(int number) {
  if (number == combination[step]) {
    _tumbler.play();
    _dwell = Timer(const Duration(milliseconds: 450), lockIn);
  } else {
    _click.play(); // dropped if it lands inside 25 ms
  }
}''',
      builder: (context) => const SafeDialDemo(),
      icon: Icons.lock_clock_rounded,
      immersive: true,
      tags: const ['register()', 'minInterval', 'sharpness'],
    ),
    ShowcaseEntry(
      id: 'texture-pad',
      title: 'Texture pad',
      category: 'Materials',
      summary:
          'Drag across glass, sand, gravel, corduroy and bubble wrap — '
          'texture made of timing, strength and crispness.',
      rationale:
          'A texture is a rule that turns distance into taps. Sand is '
          'many tiny soft grains; gravel randomises both spacing and weight; '
          'glass is almost silent, which is what makes it feel smooth. '
          'Corduroy only counts sideways travel, so sliding down the ridges is '
          'silent — a directional texture you can only discover by touch. '
          'Bubble wrap is state, not distance: each bubble pops exactly once. '
          'Every variation is a registered handle chosen at random, so the '
          'per-tap cost stays low. Each handle paces only itself, so one 30 '
          'ms pacer shared by all of them keeps fast strokes from fusing '
          'into a buzz.',
      moments: const [
        HapticMoment('Glass, every 120 px', 'tap(0.15, 0.95)'),
        HapticMoment(
          'Sand, every 6 px',
          'random of 3 · 0.15–0.25, sharpness 0.2',
        ),
        HapticMoment(
          'Gravel, every 10–30 px',
          'random of 5 · 0.3–0.9, sharpness 0.6',
        ),
        HapticMoment(
          'Corduroy, every 14 px sideways',
          'tap(0.6, 1.0)',
          note: 'Vertical motion is silent.',
        ),
        HapticMoment(
          'Bubble entered',
          'tap(0.95, 1.0)',
          note: 'Once per bubble.',
        ),
      ],
      code: r'''
final _gravel = [
  for (final i in [0.3, 0.45, 0.6, 0.75, 0.9])
    FlutterHaptics.register(
      HapticPattern([TransientEvent(intensity: i, sharpness: 0.6)]),
    ),
];
// Shared by every handle: each one paces only itself.
final _pacer = HapticPacer(minInterval: const Duration(milliseconds: 30));
double _travel = 0, _nextAt = 12;

void onPanUpdate(DragUpdateDetails d) {
  // Corduroy counts only sideways travel: a directional texture.
  _travel += surface == Surface.corduroy ? d.delta.dx.abs() : d.delta.distance;
  if (_travel < _nextAt) return;
  _travel = 0;
  _nextAt = surface.spacing(); // gravel: 10–30 px at random
  if (_pacer.ready()) surface.pickHandle().play();
}''',
      builder: (context) => const TexturePadDemo(),
      icon: Icons.texture_rounded,
      immersive: true,
      tags: const ['register()', 'HapticPacer', 'texture'],
    ),

    // ─── Physics & play ────────────────────────────────────────────────
    ShowcaseEntry(
      id: 'bouncing-balls',
      title: 'Bouncing balls',
      category: 'Physics & play',
      summary:
          'Every impact is felt at a strength proportional to its speed; '
          'steel clinks, rubber thuds.',
      rationale:
          'In a physical simulation the haptic is a property of the '
          'world, not a notification, so it must scale with what happened: '
          'impact speed maps to intensity, material maps to sharpness. Two '
          'rules keep it pleasant. Bounces below a speed threshold are '
          'silent, so a ball settling on the floor does not buzz itself to '
          'rest. And one global pacer limits the whole world to a tap every '
          '35 ms — a pile of eight balls colliding would otherwise become a '
          'continuous vibration that means nothing.',
      moments: const [
        HapticMoment('Fast impact', 'ladder[speed] · rubber 0.2 / steel 0.95'),
        HapticMoment(
          'Slow bounce',
          'nothing',
          note: 'Below 140 px/s is silent.',
        ),
        HapticMoment('Many at once', 'at most one per 35 ms'),
      ],
      code: r'''
static const silentBelow = 140.0, fullAt = 2200.0;
// One budget for every handle in the world: each handle paces only itself.
final _pacer = HapticPacer(minInterval: const Duration(milliseconds: 35));

void onImpact(double speed, BallMaterial m) {
  if (speed < silentBelow || !_pacer.ready()) return;
  final strength =
      ((speed - silentBelow) / (fullAt - silentBelow)).clamp(0.1, 1.0);
  // Quantised onto 5 prepared strengths per material for low latency.
  _impacts[m]![(strength * 4).round()].play();
}

// Floor bounce
if (ball.y > floor) {
  final speed = ball.vy.abs();
  ball.vy = -ball.vy * ball.material.restitution;
  onImpact(speed, ball.material);
}''',
      builder: (context) => const BouncingBallsDemo(),
      icon: Icons.sports_baseball_rounded,
      immersive: true,
      tags: const ['Ticker', 'register()', 'HapticPacer'],
    ),
    ShowcaseEntry(
      id: 'dice-roll',
      title: 'Dice roll',
      category: 'Physics & play',
      summary:
          'A rattle generated fresh for every throw, then a thud; '
          'doubles earn a coin.',
      rationale:
          'Repeating the same recorded rattle makes a game feel '
          'canned within three throws. Building it per roll with '
          'HapticPatternBuilder — gaps growing 18% each time like a die losing '
          'energy, random strength and crispness per tap — keeps it alive. '
          'The rattle and the landing thud are one pattern played with one '
          'call, so they cannot drift apart, and the faces on screen change on '
          'the same timeline the taps use. Hold the button to shake the dice '
          'in your hand first; the celebration for doubles comes 150 ms after '
          'landing, so it reads as a reaction rather than part of the throw.',
      moments: const [
        HapticMoment('Hold Roll', 'random taps every 55–100 ms'),
        HapticMoment(
          'Throw',
          'generated rattle + AppPatterns.thud',
          note: 'One play() call.',
        ),
        HapticMoment(
          'Doubles',
          'AppPatterns.coin',
          note: '150 ms after landing.',
        ),
      ],
      code: r'''
HapticPattern rattle() {
  final b = HapticPatternBuilder();
  var t = 0.0, gap = 35.0;
  while (t < 650) {
    b.tap(
      intensity: 0.35 + random.nextDouble() * 0.4,
      sharpness: 0.7 + random.nextDouble() * 0.3,
    );
    b.waitMs((gap - 25).round()); // tap() already advanced 25 ms
    t += gap;
    gap *= 1.18; // losing energy
  }
  return b.build();
}

void roll() {
  final throwPattern = rattle().then(AppPatterns.thud);
  FlutterHaptics.play(throwPattern); // one timeline: no drift
  dice.animate(duration: throwPattern.duration);
}''',
      builder: (context) => const DiceRollDemo(),
      icon: Icons.casino_rounded,
      immersive: true,
      tags: const ['HapticPatternBuilder', 'then()', 'generated'],
    ),

    // ─── Rhythm ────────────────────────────────────────────────────────
    ShowcaseEntry(
      id: 'breathing-coach',
      title: 'Breathing coach',
      category: 'Rhythm',
      summary:
          'Box breathing you can follow with your eyes closed: a slow '
          'swell in, an ebb out, stillness to hold.',
      rationale:
          'Guidance haptics should be the quietest in an app: the swell '
          'peaks at 0.35 intensity with low sharpness, because the point is to '
          'calm, not alert. Holding is pure silence — the absence of feedback '
          'is the instruction. Four-second continuous events are fine on Core '
          'Haptics and Android envelope hardware, but on a rotary motor the '
          'whole curve degrades to four seconds of full-strength buzz. So the '
          'coach checks support (and the simulated tier) and counts the '
          'seconds with soft taps there instead.',
      moments: const [
        HapticMoment('Breathe in (4 s)', 'ContinuousEvent 0.05 → 0.35'),
        HapticMoment('Hold (4 s)', 'nothing'),
        HapticMoment('Breathe out (4 s)', 'ContinuousEvent 0.35 → 0.05'),
        HapticMoment('Rhythm-tier device', 'one soft tap per second'),
      ],
      code: r'''
static const inhale = HapticPattern([
  ContinuousEvent.curved(
    intensity: LinearParam(from: 0.05, to: 0.35), // faint on purpose
    sharpness: ConstantParam(0.12),
    duration: Duration(seconds: 4),
  ),
]);

Future<void> enterInhale() async {
  final support = await FlutterHaptics.support;
  final rumbleOk = support.supportsContinuous &&
      support.fidelity != HapticFidelity.rhythm;
  if (rumbleOk) {
    FlutterHaptics.play(inhale);
  } else {
    countSecondsWithTaps(); // 4 s of on/off buzz would be an alarm
  }
}

void stopSession() {
  cycle.stop();
  FlutterHaptics.stop(); // cut a swell mid-way
}''',
      builder: (context) => const BreathingCoachDemo(),
      icon: Icons.air_rounded,
      immersive: true,
      tags: const ['ContinuousEvent', 'stop()', 'fidelity'],
    ),
    ShowcaseEntry(
      id: 'metronome',
      title: 'Metronome',
      category: 'Rhythm',
      summary:
          'Feel the downbeat: beat one strong and crisp, the rest light. '
          'Prepared handles keep it tight.',
      rationale:
          'Rhythm is the one channel every device keeps, so a '
          'metronome is a natural haptic. Accent and beat are two registered '
          'handles: nothing is serialised or rebuilt per beat, which keeps '
          'latency low and even. Both opt out of pacing with Duration.zero — '
          'the beats are already scheduled, and a metronome that drops one is '
          'broken. Every beat is scheduled from a fixed anchor '
          'on a Stopwatch rather than from the previous timer, so a late '
          'callback never accumulates into drift. On a rhythm-tier motor the '
          'accent loses its extra strength, so the visual dot carries it '
          'there; the timing still lands.',
      moments: const [
        HapticMoment('Beat one', 'tap(1.0, sharpness 0.9)'),
        HapticMoment('Other beats', 'tap(0.45, sharpness 0.6)'),
        HapticMoment('6/8, beat four', 'tap(0.7, sharpness 0.75)'),
        HapticMoment('BPM ± / slider', 'AppHaptics.tick · fineDetent · limit'),
      ],
      code: r'''
// Opted out of pacing: the clock decides when a beat lands, not the handle.
final _accent = FlutterHaptics.register(
  const HapticPattern([TransientEvent(intensity: 1.0, sharpness: 0.9)]),
  minInterval: Duration.zero,
);
final _beat = FlutterHaptics.register(
  const HapticPattern([TransientEvent(intensity: 0.45, sharpness: 0.6)]),
  minInterval: Duration.zero,
);
final _clock = Stopwatch()..start();

// Scheduled from the anchor, never from the last timer: no drift.
void schedule() {
  final due = anchor + interval * n;
  timer = Timer(due - _clock.elapsed, fire);
}

void fire() {
  (beats % meter.beats == 0 ? _accent : _beat).play();
  beats++;
  n++;
  schedule();
}''',
      builder: (context) => const MetronomeDemo(),
      icon: Icons.av_timer_rounded,
      immersive: true,
      tags: const ['register()', 'timing', 'Stopwatch'],
    ),
    ShowcaseEntry(
      id: 'morse-code',
      title: 'Morse code',
      category: 'Rhythm',
      summary:
          'Type a message and feel it — information carried by timing '
          'alone.',
      rationale:
          'Morse is the purest test of the fidelity ladder: dots and '
          'dashes differ only in duration, so the message survives even an '
          'on/off motor where intensity and sharpness are gone. That makes it '
          'a useful design check for any pattern — if its meaning could be '
          'tapped out in Morse, it will read on every phone. The whole message '
          'is one pattern built with HapticPatternBuilder and played with one '
          'call, so the screen can follow it from pattern.duration, and Stop '
          'cancels it with FlutterHaptics.stop().',
      moments: const [
        HapticMoment('Dot', 'tap(0.8, 0.8) · one 90 ms unit'),
        HapticMoment('Dash', 'rumble 270 ms (3 units) at 0.8'),
        HapticMoment('Gaps', '1 unit · 3 between letters · 7 between words'),
        HapticMoment('Stop', 'FlutterHaptics.stop()'),
      ],
      code: r'''
HapticPattern encode(String text) {
  final b = HapticPatternBuilder();
  for (final word in text.split(' ')) {
    for (final letter in word.split('')) {
      for (final symbol in morse[letter]!.split('')) {
        if (symbol == '.') {
          b.tap(intensity: 0.8, sharpness: 0.8).waitMs(90 - 25);
        } else {
          b.rumble(duration: const Duration(milliseconds: 270), intensity: 0.8);
        }
        b.waitMs(90); // inside a letter
      }
      b.waitMs(180); // 3 units between letters
    }
    b.waitMs(360); // 7 units between words
  }
  return b.build();
}''',
      builder: (context) => const MorseCodeDemo(),
      icon: Icons.more_horiz_rounded,
      immersive: true,
      tags: const ['HapticPatternBuilder', 'rhythm tier', 'stop()'],
    ),
  ];

  static ShowcaseEntry? byId(String id) {
    for (final entry in entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }
}
