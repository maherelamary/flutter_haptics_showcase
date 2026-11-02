import 'package:flutter/foundation.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/haptic_registry.dart';

/// One platform constant, described for people.
class SystemEntry {
  const SystemEntry(
    this.haptic, {
    required this.native,
    required this.meaning,
    required this.group,
    this.note,
  });

  final SystemHaptic haptic;

  /// What the OS calls it: `UIImpactFeedbackGenerator(.light)`,
  /// `HapticFeedbackConstants.CONFIRM`.
  final String native;

  /// What it says, in one line.
  final String meaning;

  /// Section on the page.
  final String group;

  /// The asymmetry worth knowing, if any.
  final String? note;

  /// `iOS 13+` or `API 34+`.
  String get availability => haptic.platform == TargetPlatform.iOS
      ? 'iOS ${haptic.minimumVersion}+'
      : 'API ${haptic.minimumVersion}+';

  /// The `AppHaptics` meanings whose native arm names this constant.
  List<String> get usedBy => [
        for (final entry in HapticRegistry.intents.entries)
          if (_names(entry.value.ios) || _names(entry.value.android))
            'AppHaptics.${entry.key}',
      ];

  bool _names(HapticArm<SystemHaptic> arm) =>
      arm is NativeArm<SystemHaptic> && arm.haptic == haptic;
}

/// The two vocabularies, unflattened: what each OS defines and what each
/// constant means. Read straight from `IOSHaptic` and `AndroidHaptic`.
abstract final class SystemCatalog {
  static const ios = <SystemEntry>[
    SystemEntry(
      IOSHaptic.impactLight,
      native: 'UIImpactFeedbackGenerator(.light)',
      meaning: 'A light collision.',
      group: 'Impact',
    ),
    SystemEntry(
      IOSHaptic.impactMedium,
      native: 'UIImpactFeedbackGenerator(.medium)',
      meaning: 'A moderate collision.',
      group: 'Impact',
    ),
    SystemEntry(
      IOSHaptic.impactHeavy,
      native: 'UIImpactFeedbackGenerator(.heavy)',
      meaning: 'A forceful collision.',
      group: 'Impact',
    ),
    SystemEntry(
      IOSHaptic.impactRigid,
      native: 'UIImpactFeedbackGenerator(.rigid)',
      meaning: 'Crisp and mechanical.',
      group: 'Impact',
    ),
    SystemEntry(
      IOSHaptic.impactSoft,
      native: 'UIImpactFeedbackGenerator(.soft)',
      meaning: 'Dull and cushioned.',
      group: 'Impact',
    ),
    SystemEntry(
      IOSHaptic.notificationSuccess,
      native: 'UINotificationFeedbackGenerator(.success)',
      meaning: 'An action succeeded.',
      group: 'Notification',
    ),
    SystemEntry(
      IOSHaptic.notificationWarning,
      native: 'UINotificationFeedbackGenerator(.warning)',
      meaning: 'Caution.',
      group: 'Notification',
      note: 'Android defines nothing like this — which is why '
          'AppHaptics.caution uses HapticArm.pattern() on Android.',
    ),
    SystemEntry(
      IOSHaptic.notificationError,
      native: 'UINotificationFeedbackGenerator(.error)',
      meaning: 'An action failed.',
      group: 'Notification',
    ),
    SystemEntry(
      IOSHaptic.selection,
      native: 'UISelectionFeedbackGenerator',
      meaning: 'A picker stepping by one.',
      group: 'Selection',
    ),
  ];

  static const android = <SystemEntry>[
    SystemEntry(
      AndroidHaptic.longPress,
      native: 'LONG_PRESS',
      meaning: 'A long press completing. The heaviest tap Android defines.',
      group: 'Every supported device',
    ),
    SystemEntry(
      AndroidHaptic.virtualKey,
      native: 'VIRTUAL_KEY',
      meaning: 'An on-screen key going down.',
      group: 'Every supported device',
    ),
    SystemEntry(
      AndroidHaptic.keyboardTap,
      native: 'KEYBOARD_TAP',
      meaning: 'A keyboard key.',
      group: 'Every supported device',
      note: 'The same effect as KEYBOARD_PRESS under another name.',
    ),
    SystemEntry(
      AndroidHaptic.clockTick,
      native: 'CLOCK_TICK',
      meaning: 'A picker stepping by one.',
      group: 'Every supported device',
    ),
    SystemEntry(
      AndroidHaptic.contextClick,
      native: 'CONTEXT_CLICK',
      meaning: 'A firm confirmation press.',
      group: 'Every supported device',
    ),
    SystemEntry(
      AndroidHaptic.keyboardPress,
      native: 'KEYBOARD_PRESS',
      meaning: 'A key going down, as distinct from coming up.',
      group: 'Android 8.1 · API 27',
    ),
    SystemEntry(
      AndroidHaptic.keyboardRelease,
      native: 'KEYBOARD_RELEASE',
      meaning: 'A key coming up.',
      group: 'Android 8.1 · API 27',
      note: 'iOS has no release event at all.',
    ),
    SystemEntry(
      AndroidHaptic.virtualKeyRelease,
      native: 'VIRTUAL_KEY_RELEASE',
      meaning: 'An on-screen key coming up.',
      group: 'Android 8.1 · API 27',
    ),
    SystemEntry(
      AndroidHaptic.textHandleMove,
      native: 'TEXT_HANDLE_MOVE',
      meaning: 'Dragging a text selection handle.',
      group: 'Android 8.1 · API 27',
    ),
    SystemEntry(
      AndroidHaptic.confirm,
      native: 'CONFIRM',
      meaning: 'An action succeeded.',
      group: 'Android 11 · API 30',
    ),
    SystemEntry(
      AndroidHaptic.reject,
      native: 'REJECT',
      meaning: 'An action was refused.',
      group: 'Android 11 · API 30',
    ),
    SystemEntry(
      AndroidHaptic.gestureStart,
      native: 'GESTURE_START',
      meaning: 'A gesture beginning.',
      group: 'Android 11 · API 30',
    ),
    SystemEntry(
      AndroidHaptic.gestureEnd,
      native: 'GESTURE_END',
      meaning: 'A gesture completing.',
      group: 'Android 11 · API 30',
    ),
    SystemEntry(
      AndroidHaptic.dragStart,
      native: 'DRAG_START',
      meaning: 'A drag picking something up.',
      group: 'Android 14 · API 34',
      note: 'iOS has no drag constant.',
    ),
    SystemEntry(
      AndroidHaptic.gestureThresholdActivate,
      native: 'GESTURE_THRESHOLD_ACTIVATE',
      meaning: 'A gesture passing the point of commitment.',
      group: 'Android 14 · API 34',
      note: 'iOS has no threshold constants.',
    ),
    SystemEntry(
      AndroidHaptic.gestureThresholdDeactivate,
      native: 'GESTURE_THRESHOLD_DEACTIVATE',
      meaning: 'A gesture falling back below that point.',
      group: 'Android 14 · API 34',
    ),
    SystemEntry(
      AndroidHaptic.segmentTick,
      native: 'SEGMENT_TICK',
      meaning: 'Crossing a segment boundary, such as a slider notch.',
      group: 'Android 14 · API 34',
    ),
    SystemEntry(
      AndroidHaptic.segmentFrequentTick,
      native: 'SEGMENT_FREQUENT_TICK',
      meaning: 'A lighter segment boundary, for close spacing.',
      group: 'Android 14 · API 34',
    ),
    SystemEntry(
      AndroidHaptic.toggleOn,
      native: 'TOGGLE_ON',
      meaning: 'A switch moving to on.',
      group: 'Android 14 · API 34',
      note: 'iOS has no toggle feedback.',
    ),
    SystemEntry(
      AndroidHaptic.toggleOff,
      native: 'TOGGLE_OFF',
      meaning: 'A switch moving to off.',
      group: 'Android 14 · API 34',
    ),
  ];
}
