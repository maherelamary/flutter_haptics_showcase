import 'package:flutter/material.dart';
import 'package:flutter_haptics_showcase/src/core/showcase/showcase_entry.dart';
import 'package:flutter_haptics_showcase/src/features/gallery/presentation/demos/interactions/async_save_demo.dart';
import 'package:flutter_haptics_showcase/src/features/gallery/presentation/demos/interactions/character_limit_demo.dart';
import 'package:flutter_haptics_showcase/src/features/gallery/presentation/demos/interactions/form_validation_demo.dart';
import 'package:flutter_haptics_showcase/src/features/gallery/presentation/demos/interactions/long_press_menu_demo.dart';
import 'package:flutter_haptics_showcase/src/features/gallery/presentation/demos/interactions/notification_trio_demo.dart';
import 'package:flutter_haptics_showcase/src/features/gallery/presentation/demos/interactions/page_carousel_demo.dart';
import 'package:flutter_haptics_showcase/src/features/gallery/presentation/demos/interactions/pin_pad_demo.dart';
import 'package:flutter_haptics_showcase/src/features/gallery/presentation/demos/interactions/progress_milestones_demo.dart';
import 'package:flutter_haptics_showcase/src/features/gallery/presentation/demos/interactions/pull_to_refresh_demo.dart';
import 'package:flutter_haptics_showcase/src/features/gallery/presentation/demos/interactions/reorder_list_demo.dart';
import 'package:flutter_haptics_showcase/src/features/gallery/presentation/demos/interactions/snap_sheet_demo.dart';
import 'package:flutter_haptics_showcase/src/features/gallery/presentation/demos/interactions/swipe_actions_demo.dart';
import 'package:flutter_haptics_showcase/src/features/gallery/presentation/demos/interactions/undo_snackbar_demo.dart';

/// Gallery entries for gestures, input and feedback.
final List<ShowcaseEntry> galleryInteractionsEntries = [
  // ─── Gestures ──────────────────────────────────────────────────────
  ShowcaseEntry(
    id: 'pull-to-refresh',
    title: 'Pull to refresh',
    category: 'Gestures',
    summary: 'Feel the moment a pull arms, the moment it backs off, and the '
        'moment new content lands.',
    rationale: 'Pull-to-refresh is a threshold gesture: mid-drag, the only '
        'thing the user needs to know is which side of the line they are '
        'on. Arming gives a firm tap and pulling back a softer one, so the '
        'decision is felt without watching the spinner. Nothing plays while '
        'loading — waiting is not an event. The success at the end marks the '
        'one moment worth feeling: new content has arrived.',
    moments: const [
      HapticMoment(
        'Pull past 80 px',
        'AppHaptics.armed',
        note: 'API 34 constant on Android; pattern below that',
      ),
      HapticMoment('Pull back under it', 'AppHaptics.disarmed'),
      HapticMoment('Release while armed, then loading', 'nothing'),
      HapticMoment('New content lands', 'AppHaptics.success'),
    ],
    code: r'''
bool _onScroll(ScrollNotification n) {
  final pull = n.metrics.minScrollExtent - n.metrics.pixels;
  if (n is ScrollUpdateNotification && n.dragDetails == null) {
    // Finger lifted: commit if armed.
    if (_armed) _refresh();
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
  await repository.fetchLatest(); // no haptics while waiting
  if (mounted) FlutterHaptics.perform(AppHaptics.success);
}''',
    builder: (context) => const PullToRefreshDemo(),
    icon: Icons.refresh_rounded,
    tags: const ['ScrollNotification', 'threshold', 'API 34'],
  ),
  ShowcaseEntry(
    id: 'swipe-actions',
    title: 'Swipe actions',
    category: 'Gestures',
    summary: 'Swipe right to archive, left to delete — with a threshold you '
        'can feel and back out of.',
    rationale: 'The threshold crossing is the decision, so it gets the '
        'clearest haptic, and backing out gets a softer one: the user can '
        'cancel by feel. Release plays a second, different haptic that says '
        'which outcome happened — success for archive, a plain press for '
        'delete. Delete is undoable, so it stays neutral rather than '
        'alarming, and undo plays the rewind pattern so reversing feels like '
        'the action running backwards.',
    moments: const [
      HapticMoment(
        'Swipe past the threshold',
        'AppHaptics.armed',
        note: 'DismissUpdateDetails.reached flips to true',
      ),
      HapticMoment('Swipe back under it', 'AppHaptics.disarmed'),
      HapticMoment('Release to archive', 'AppHaptics.success'),
      HapticMoment('Release to delete', 'AppHaptics.press'),
      HapticMoment('Tap Undo', 'AppPatterns.rewind'),
    ],
    code: r'''
Dismissible(
  key: ValueKey(mail.id),
  onUpdate: (d) {
    if (d.reached && !d.previousReached) {
      FlutterHaptics.perform(AppHaptics.armed);
    } else if (!d.reached && d.previousReached) {
      FlutterHaptics.perform(AppHaptics.disarmed);
    }
  },
  onDismissed: (direction) {
    if (direction == DismissDirection.startToEnd) {
      archive(mail);
      FlutterHaptics.perform(AppHaptics.success);
    } else {
      delete(mail);
      FlutterHaptics.perform(AppHaptics.press);
      showUndo(onUndo: () {
        FlutterHaptics.play(AppPatterns.rewind);
        restore(mail);
      });
    }
  },
  background: archiveBackground,
  secondaryBackground: deleteBackground,
  child: MailRow(mail),
)''',
    builder: (context) => const SwipeActionsDemo(),
    icon: Icons.swipe_rounded,
    tags: const ['Dismissible.onUpdate', 'threshold', 'undo'],
  ),
  ShowcaseEntry(
    id: 'long-press-menu',
    title: 'Long-press menu',
    category: 'Gestures',
    summary: 'Hold, slide to an action, release — a context menu used in one '
        'continuous gesture.',
    rationale: 'The heavy impact marks the exact moment a press becomes a '
        'menu, so the user can stop pressing and start sliding. While the '
        'finger stays down, each item it crosses ticks like a picker, which '
        'makes the menu usable without looking. Choosing confirms with a '
        'light tap; letting go elsewhere dismisses silently, because '
        'cancelling is not an event. Release without sliding and the menu '
        'stays open for an ordinary tap.',
    moments: const [
      HapticMoment('Hold for 450 ms', 'AppHaptics.longPress'),
      HapticMoment('Slide onto a menu item', 'AppHaptics.tick'),
      HapticMoment('Release on an item, or tap one', 'AppHaptics.tap'),
      HapticMoment('Release away from the menu', 'nothing'),
    ],
    code: r'''
RawGestureDetector(
  gestures: {
    LongPressGestureRecognizer:
        GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
      () => LongPressGestureRecognizer(
        duration: const Duration(milliseconds: 450),
      ),
      (r) => r
        ..onLongPressStart = (_) {
          FlutterHaptics.perform(AppHaptics.longPress);
          openMenu();
        }
        ..onLongPressMoveUpdate = (d) {
          final item = itemAt(d.globalPosition);
          if (item == _hovered) return;
          _hovered = item;
          if (item != null) FlutterHaptics.perform(AppHaptics.tick);
        }
        ..onLongPressEnd = (d) {
          final item = itemAt(d.globalPosition);
          if (item != null) FlutterHaptics.perform(AppHaptics.tap);
          item?.run();
          closeMenu(); // silently
        },
    ),
  },
  child: card,
)''',
    builder: (context) => const LongPressMenuDemo(),
    icon: Icons.pan_tool_alt_rounded,
    tags: const ['LongPressGestureRecognizer', 'slide-to-select'],
  ),
  ShowcaseEntry(
    id: 'reorder-list',
    title: 'Drag to reorder',
    category: 'Gestures',
    summary: 'Lift a row, move it, set it down: the two physical moments of a '
        'drag, felt.',
    rationale: 'Picking a row up and setting it down are the two physical '
        'moments of a drag, so each gets a haptic and nothing plays in '
        'between — the moving row already shows where it is. Android 14 and '
        'later use the platform\'s own drag-start constant; iOS uses a medium '
        'impact, like a UIKit lift. Ticking on every slot crossed is '
        'tempting, but it turns a long drag into a buzz.',
    moments: const [
      HapticMoment(
        'Long-press to lift a row',
        'AppHaptics.lift',
        note: 'Android dragStart needs API 34; pattern below',
      ),
      HapticMoment('Move it', 'nothing'),
      HapticMoment('Drop it', 'AppHaptics.drop'),
    ],
    code: r'''
ReorderableListView(
  onReorderItem: (from, to) => setState(() {
    items.insert(to, items.removeAt(from));
  }),
  // Lift on pick-up, settle on drop. Nothing in between:
  // the moving row is feedback enough.
  onReorderStart: (_) => FlutterHaptics.perform(AppHaptics.lift),
  onReorderEnd: (_) => FlutterHaptics.perform(AppHaptics.drop),
  children: [
    for (final item in items)
      TaskRow(key: ValueKey(item.id), item: item),
  ],
)''',
    builder: (context) => const ReorderListDemo(),
    icon: Icons.reorder_rounded,
    tags: const ['ReorderableListView', 'API 34'],
  ),
  ShowcaseEntry(
    id: 'snap-sheet',
    title: 'Snapping sheet',
    category: 'Gestures',
    summary: 'A bottom sheet whose snap points click like notches as you drag '
        'between them.',
    rationale: 'Snap points are detents: the sheet has a few places it wants '
        'to rest, and crossing one should feel like a notch. Tracking which '
        'band the sheet is in, rather than its exact size, means each '
        'crossing plays exactly once — including the moment it seats after '
        'a fling. Between snap points the drag stays silent, and opening the '
        'sheet is silent too: its motion is the feedback.',
    moments: const [
      HapticMoment('Open the sheet', 'nothing'),
      HapticMoment(
        'Cross Peek, Half or Full',
        'AppHaptics.detent',
        note: 'Android segmentTick needs API 34; pattern below',
      ),
      HapticMoment('Drag between snap points', 'nothing'),
    ],
    code: r'''
static const _points = [0.35, 0.6, 0.9];
int _band = 1;

NotificationListener<DraggableScrollableNotification>(
  onNotification: (n) {
    final band = _points.where((p) => n.extent >= p - 0.01).length;
    if (band != _band) {
      _band = band;
      FlutterHaptics.perform(AppHaptics.detent);
    }
    return false;
  },
  child: DraggableScrollableSheet(
    expand: false,
    snap: true,
    snapSizes: const [0.35, 0.6],
    initialChildSize: 0.35,
    minChildSize: 0.2,
    maxChildSize: 0.9,
    builder: (context, controller) =>
        ListView(controller: controller, children: content),
  ),
)''',
    builder: (context) => const SnapSheetDemo(),
    icon: Icons.vertical_align_top_rounded,
    tags: const ['DraggableScrollableSheet', 'detents'],
  ),
  ShowcaseEntry(
    id: 'page-carousel',
    title: 'Page carousel',
    category: 'Gestures',
    summary: 'Swipe between cards; each new page ticks like a picker.',
    rationale: 'A carousel page change is a selection, so it uses the same '
        'tick as a picker or a segmented control. It fires when the selected '
        'page changes mid-swipe rather than when the animation settles, so '
        'it lands with the dot indicator moving. The scroll itself stays '
        'quiet, like every scroll in the app.',
    moments: const [
      HapticMoment('Swipe past the halfway point', 'AppHaptics.tick'),
      HapticMoment('Scrolling between pages', 'nothing'),
    ],
    code: r'''
PageView.builder(
  controller: _controller, // viewportFraction: 0.85
  itemCount: cards.length,
  // A page change is a selection. The swipe itself stays quiet.
  onPageChanged: (index) {
    FlutterHaptics.perform(AppHaptics.tick);
    setState(() => _page = index);
  },
  itemBuilder: (context, i) => CardView(cards[i]),
)''',
    builder: (context) => const PageCarouselDemo(),
    icon: Icons.view_carousel_rounded,
    tags: const ['PageView', 'selection'],
  ),

  // ─── Input ─────────────────────────────────────────────────────────
  ShowcaseEntry(
    id: 'pin-pad',
    title: 'PIN pad',
    category: 'Input',
    summary: 'A keypad that clicks on touch-down and gives its verdict on its '
        'own beat.',
    rationale: 'Keys act on touch-down, like a hardware keyboard, so the '
        'click and the dot appear the instant the finger lands. The fourth '
        'digit waits 160 ms before the verdict, so the key click and the '
        'outcome never blur into one buzz. A wrong PIN gets the error haptic '
        'and the shake on the same frame; the right one gets success as the '
        'dots turn lime.',
    moments: const [
      HapticMoment(
        'Press a digit',
        'AppHaptics.key',
        note: 'on touch-down, not release',
      ),
      HapticMoment('Backspace', 'AppHaptics.tap'),
      HapticMoment('Wrong PIN', 'AppHaptics.failure', note: '+ shake'),
      HapticMoment('2580', 'AppHaptics.success'),
    ],
    code: r'''
// Keys act on touch-down, like a hardware key.
GestureDetector(
  onTapDown: (_) => _digit('5'),
  child: const KeyCap('5'),
)

void _digit(String d) {
  if (_pin.length == 4) return;
  FlutterHaptics.perform(AppHaptics.key);
  setState(() => _pin += d);
  if (_pin.length == 4) {
    Timer(const Duration(milliseconds: 160), _check);
  }
}

void _check() {
  if (_pin == secret) {
    FlutterHaptics.perform(AppHaptics.success);
    unlock();
  } else {
    FlutterHaptics.perform(AppHaptics.failure);
    _shake.shake(); // same frame as the haptic
    clearAfterFlash();
  }
}''',
    builder: (context) => const PinPadDemo(),
    icon: Icons.pin_rounded,
    tags: const ['touch-down', 'Shaker'],
  ),
  ShowcaseEntry(
    id: 'form-validation',
    title: 'Form validation',
    category: 'Input',
    summary: 'One verdict per submit, and one shake pointing at the first '
        'problem.',
    rationale: 'Typing stays silent: the keyboard owns keystroke feedback, '
        'and a second layer would compete with it. On submit, the whole form '
        'gets one verdict — a single error haptic however many fields are '
        'wrong — and only the first invalid field shakes and takes focus, so '
        'the user knows exactly where to go. Errors then update live as they '
        'type, silently: fixing a mistake is its own reward.',
    moments: const [
      HapticMoment('Typing', 'nothing', note: 'the keyboard owns it'),
      HapticMoment(
        'Submit with errors',
        'AppHaptics.failure',
        note: 'once, + shake the first invalid field',
      ),
      HapticMoment('Submit a valid form', 'AppHaptics.success'),
    ],
    code: r'''
void _submit() {
  final emailError = validateEmail(_email.text);
  final passwordError = validatePassword(_password.text);
  setState(() {
    _emailError = emailError;
    _passwordError = passwordError;
  });

  // One haptic for the whole form, one shake for the first problem.
  if (emailError != null) {
    FlutterHaptics.perform(AppHaptics.failure);
    _emailShake.shake();
    _emailFocus.requestFocus();
  } else if (passwordError != null) {
    FlutterHaptics.perform(AppHaptics.failure);
    _passwordShake.shake();
    _passwordFocus.requestFocus();
  } else {
    FlutterHaptics.perform(AppHaptics.success);
    signIn();
  }
}''',
    builder: (context) => const FormValidationDemo(),
    icon: Icons.fact_check_rounded,
    tags: const ['Shaker', 'focus'],
  ),
  ShowcaseEntry(
    id: 'character-limit',
    title: 'Character limit',
    category: 'Input',
    summary: 'Hit a text limit and feel the wall once — not on every extra '
        'keystroke.',
    rationale: 'A hard limit is a wall, and a wall only needs to be felt '
        'once. The limit haptic plays on the keystroke that reaches 40; '
        'further keystrokes are blocked by the field and stay silent, and '
        'the haptic re-arms only once there is room again. The counter '
        'turning amber at 35 does the warning visually, so the haptic never '
        'has to nag.',
    moments: const [
      HapticMoment('Reach 40 characters', 'AppHaptics.limit'),
      HapticMoment('Keep typing at the limit', 'nothing'),
      HapticMoment('Delete below 40, reach it again', 'AppHaptics.limit'),
    ],
    code: r'''
TextField(
  maxLength: 40,
  decoration: const InputDecoration(counterText: ''),
  onChanged: (text) {
    final length = text.characters.length;
    if (length >= 40 && !_atLimit) {
      _atLimit = true; // feel the wall once
      FlutterHaptics.perform(AppHaptics.limit);
    } else if (length < 40) {
      _atLimit = false; // re-arm once there is room again
    }
    setState(() => _length = length);
  },
)''',
    builder: (context) => const CharacterLimitDemo(),
    icon: Icons.short_text_rounded,
    tags: const ['once', 'limit'],
  ),

  // ─── Feedback ──────────────────────────────────────────────────────
  ShowcaseEntry(
    id: 'notification-trio',
    title: 'Success · warning · error',
    category: 'Feedback',
    summary: 'Three outcomes you can tell apart with your eyes closed.',
    rationale: 'Success and error map cleanly onto native constants on both '
        'platforms, so they feel like the rest of the OS. Warning is the odd '
        'one: iOS has a warning constant and Android has none. Borrowing an '
        'unrelated Android constant would say the wrong thing, so caution\'s '
        'Android arm plays the pattern by choice — a deliberate answer, not a '
        'recovery. The three differ in rhythm, so they still read on a '
        'rotary motor.',
    moments: const [
      HapticMoment(
        'Success',
        'AppHaptics.success',
        note: 'notificationSuccess / CONFIRM (API 30)',
      ),
      HapticMoment(
        'Warning',
        'AppHaptics.caution',
        note: 'notificationWarning / the pattern, by choice',
      ),
      HapticMoment(
        'Error',
        'AppHaptics.failure',
        note: 'notificationError / REJECT (API 30)',
      ),
    ],
    code: r'''
// Success and error have a native constant on both platforms.
FlutterHaptics.perform(AppHaptics.success); // notificationSuccess / CONFIRM
FlutterHaptics.perform(AppHaptics.failure); // notificationError / REJECT

// Native on iOS. Android names no warning, so caution's Android arm is
// HapticArm.pattern(): the pattern plays there on purpose.
FlutterHaptics.perform(AppHaptics.caution);
''',
    builder: (context) => const NotificationTrioDemo(),
    icon: Icons.notifications_active_rounded,
    tags: const ['perform()', 'HapticArm.pattern', 'intents'],
  ),
  ShowcaseEntry(
    id: 'undo-snackbar',
    title: 'Delete with undo',
    category: 'Feedback',
    summary: 'Delete gets a plain press; undo plays the delete backwards.',
    rationale: 'Delete gets a plain press rather than an error or a success: '
        'it is a normal action, and the undo bar makes it safe. The snackbar '
        'appearing is silent — the delete already spoke a frame earlier, '
        'and two haptics for one action is noise. Undo plays the rewind '
        'pattern, three taps falling away, so reversing an action feels like '
        'that action played backwards.',
    moments: const [
      HapticMoment('Tap delete', 'AppHaptics.press'),
      HapticMoment('Snackbar appears', 'nothing'),
      HapticMoment('Tap Undo', 'AppPatterns.rewind'),
    ],
    code: r'''
void _delete(Mail mail) {
  FlutterHaptics.perform(AppHaptics.press);
  setState(() => _inbox.remove(mail));

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('Deleted "${mail.subject}"'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            // Undo feels like the action running backwards.
            FlutterHaptics.play(AppPatterns.rewind);
            setState(() => _inbox.add(mail));
          },
        ),
      ),
    );
}''',
    builder: (context) => const UndoSnackbarDemo(),
    icon: Icons.undo_rounded,
    tags: const ['SnackBar', 'AppPatterns.rewind'],
  ),
  ShowcaseEntry(
    id: 'progress-milestones',
    title: 'Progress milestones',
    category: 'Feedback',
    summary: 'A download that ticks lightly at each quarter and lands with a '
        'success.',
    rationale: 'Never buzz while the user is waiting with no news: a haptic '
        'during a spinner claims something happened when nothing has. '
        'Milestones are justified only when the user is watching a '
        'determinate bar, so they use the lightest feedback the app has, '
        'and the success at 100% is the one that matters. Turn milestones '
        'off to compare — for background work, completion alone is right.',
    moments: const [
      HapticMoment('Tap Download', 'AppHaptics.press'),
      HapticMoment(
        'Pass 25, 50, 75%',
        'AppHaptics.fineDetent',
        note: 'only with Milestones on',
      ),
      HapticMoment('Reach 100%', 'AppHaptics.success'),
    ],
    code: r'''
late final _progress = AnimationController(vsync: this, duration: d)
  ..addListener(() {
    final passed = [0.25, 0.5, 0.75]
        .where((m) => _progress.value >= m)
        .length;
    if (passed > _passed) {
      _passed = passed;
      // Light, and only because the user is watching the bar.
      FlutterHaptics.perform(AppHaptics.fineDetent);
    }
  })
  ..addStatusListener((status) {
    if (status == AnimationStatus.completed) {
      FlutterHaptics.perform(AppHaptics.success);
    }
  });''',
    builder: (context) => const ProgressMilestonesDemo(),
    icon: Icons.downloading_rounded,
    tags: const ['determinate', 'restraint'],
  ),
  ShowcaseEntry(
    id: 'async-save',
    title: 'Async save (Riverpod)',
    category: 'Feedback',
    summary: 'The Riverpod recipe: the notifier saves, the widget decides '
        'what the outcome feels like.',
    rationale: 'Haptics are presentation, so the notifier never touches '
        'them: it saves, fails, and stays platform-free and testable. The '
        'widget listens for the loading-to-done transition with ref.listen '
        'and decides how each outcome feels, on the same frame as the '
        '"Saved" label or the shake. Widget tests assert the haptic with '
        'FakeHapticsPlatform; the notifier\'s tests never mention haptics.',
    moments: const [
      HapticMoment('Tap Save', 'AppHaptics.press'),
      HapticMoment('While saving', 'nothing'),
      HapticMoment('Save succeeds', 'AppHaptics.success'),
      HapticMoment('Save fails', 'AppHaptics.failure', note: '+ shake'),
    ],
    code: r'''
// Domain: saves, fails, knows nothing about haptics.
class SaveProfile extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> save(Profile p) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() => repository.save(p));
    if (ref.mounted) state = result; // Riverpod 3: never write a disposed ref
  }
}

// Presentation: decides what each outcome feels like.
@override
Widget build(BuildContext context, WidgetRef ref) {
  ref.listen(saveProfileProvider, (previous, next) {
    if (previous?.isLoading != true || next.isLoading) return;
    if (next.hasError) {
      FlutterHaptics.perform(AppHaptics.failure);
    } else {
      FlutterHaptics.perform(AppHaptics.success);
    }
  });
  // ...
}''',
    builder: (context) => const AsyncSaveDemo(),
    icon: Icons.cloud_upload_rounded,
    tags: const ['Riverpod', 'ref.listen', 'AsyncNotifier'],
  ),
];
