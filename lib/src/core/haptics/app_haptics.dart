import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_patterns.dart';

/// Every meaning this app gives a haptic, and the only file in it that knows
/// iOS and Android exist.
///
/// Call sites name a meaning and stay platform-blind:
///
/// ```dart
/// onPressed: () {
///   FlutterHaptics.perform(AppHaptics.press);
///   submit();
/// }
/// ```
///
/// Each intent says what each platform does, with a [HapticArm]:
///
/// - `native(…)` plays the platform's own constant, and recovers with the
///   pattern where it cannot be delivered (an OS older than the constant, or
///   an actuator that cannot render it).
/// - `pattern()` plays the pattern on purpose, because the platform has no
///   constant for this meaning.
/// - `silent()` plays nothing on purpose.
///
/// Android API levels are noted where a constant needs more than this app's
/// minSdk of 24, because that is exactly where the pattern takes over.
abstract final class AppHaptics {
  // ─── Acknowledge ───────────────────────────────────────────────────

  /// A primary button committing its action.
  static const press = HapticIntent(
    ios: HapticArm.native(IOSHaptic.impactMedium),
    android: HapticArm.native(AndroidHaptic.contextClick),
    pattern: HapticPatterns.mediumTap,
  );

  /// A low-stakes tap: icon buttons, chips that act, copy-to-clipboard.
  static const tap = HapticIntent(
    ios: HapticArm.native(IOSHaptic.impactLight),
    android: HapticArm.native(AndroidHaptic.virtualKey),
    pattern: HapticPatterns.lightTap,
  );

  /// A key on a custom keypad: PIN, OTP, calculator.
  static const key = HapticIntent(
    ios: HapticArm.native(IOSHaptic.impactLight),
    android: HapticArm.native(AndroidHaptic.keyboardTap),
    pattern: AppPatterns.keyClick,
  );

  /// A long press completing: the moment a context menu opens.
  static const longPress = HapticIntent(
    ios: HapticArm.native(IOSHaptic.impactHeavy),
    android: HapticArm.native(AndroidHaptic.longPress),
    pattern: HapticPatterns.heavyTap,
  );

  // ─── Select ────────────────────────────────────────────────────────

  /// A value stepping by one: pickers, segmented controls, tabs, radios.
  static const tick = HapticIntent(
    ios: HapticArm.native(IOSHaptic.selection),
    android: HapticArm.native(AndroidHaptic.clockTick),
    pattern: HapticPatterns.selection,
  );

  /// Crossing a notch on a slider or a snap point on a sheet.
  static const detent = HapticIntent(
    ios: HapticArm.native(IOSHaptic.selection),
    android: HapticArm.native(AndroidHaptic.segmentTick), // API 34
    pattern: AppPatterns.detent,
  );

  /// Notches packed close together, where [detent] would be too much.
  static const fineDetent = HapticIntent(
    ios: HapticArm.native(IOSHaptic.selection),
    android: HapticArm.native(AndroidHaptic.segmentFrequentTick), // API 34
    pattern: AppPatterns.fineDetent,
  );

  /// Running into a hard limit: a stepper at max, a slider at its end stop.
  static const limit = HapticIntent(
    ios: HapticArm.native(IOSHaptic.impactRigid),
    android: HapticArm.native(AndroidHaptic.contextClick),
    pattern: AppPatterns.bump,
  );

  // ─── Toggle ────────────────────────────────────────────────────────

  /// A switch moving to on.
  ///
  /// iOS has no toggle constant. Rather than going silent there, this app
  /// pairs on/off with a light and a soft impact, so the two directions
  /// never feel the same.
  static const switchOn = HapticIntent(
    ios: HapticArm.native(IOSHaptic.impactLight),
    android: HapticArm.native(AndroidHaptic.toggleOn), // API 34
    pattern: AppPatterns.switchOn,
  );

  /// A switch moving to off.
  static const switchOff = HapticIntent(
    ios: HapticArm.native(IOSHaptic.impactSoft),
    android: HapticArm.native(AndroidHaptic.toggleOff), // API 34
    pattern: AppPatterns.switchOff,
  );

  // ─── Gestures ──────────────────────────────────────────────────────

  /// A gesture passing its point of commitment: pull-to-refresh armed,
  /// swipe-to-delete past its threshold.
  static const armed = HapticIntent(
    ios: HapticArm.native(IOSHaptic.impactMedium),
    android: HapticArm.native(AndroidHaptic.gestureThresholdActivate), // API 34
    pattern: HapticPatterns.mediumTap,
  );

  /// The same gesture pulled back below it. Softer than [armed], so the
  /// user can feel which side of the line they are on without looking.
  static const disarmed = HapticIntent(
    ios: HapticArm.native(IOSHaptic.impactSoft),
    android:
        HapticArm.native(AndroidHaptic.gestureThresholdDeactivate), // API 34
    pattern: HapticPatterns.soft,
  );

  /// Something picked up to be dragged.
  static const lift = HapticIntent(
    ios: HapticArm.native(IOSHaptic.impactMedium),
    android: HapticArm.native(AndroidHaptic.dragStart), // API 34
    pattern: HapticPatterns.rigid,
  );

  /// Something set down.
  static const drop = HapticIntent(
    ios: HapticArm.native(IOSHaptic.impactLight),
    android: HapticArm.native(AndroidHaptic.gestureEnd), // API 30
    pattern: HapticPatterns.lightTap,
  );

  // ─── Outcomes ──────────────────────────────────────────────────────

  /// Something the user did was accepted.
  static const success = HapticIntent(
    ios: HapticArm.native(IOSHaptic.notificationSuccess),
    android: HapticArm.native(AndroidHaptic.confirm), // API 30
    pattern: HapticPatterns.success,
  );

  /// Something the user did was refused.
  static const failure = HapticIntent(
    ios: HapticArm.native(IOSHaptic.notificationError),
    android: HapticArm.native(AndroidHaptic.reject), // API 30
    pattern: HapticPatterns.error,
  );

  /// Something needs a second look before the user goes on.
  ///
  /// Android names no warning constant, and borrowing an unrelated one would
  /// say the wrong thing. So Android plays the pattern by choice: the same
  /// warning on every Android device, rather than a recovery from a constant
  /// that was never there.
  static const caution = HapticIntent(
    ios: HapticArm.native(IOSHaptic.notificationWarning),
    android: HapticArm.pattern(),
    pattern: HapticPatterns.warning,
  );
}
