import 'package:flutter_haptics/flutter_haptics.dart';

/// Waveforms this app composes itself.
///
/// [AppHaptics] says what a haptic *means*; these say how a few of those
/// meanings, and the app's brand moments, *feel* when no platform constant
/// fits. Each one is designed to still read on the `rhythm` tier, where only
/// timing survives: spacing carries the identity, intensity adds polish.
abstract final class AppPatterns {
  // ─── Micro feedback ────────────────────────────────────────────────

  /// A custom keypad key: lighter and crisper than a button.
  static const keyClick = HapticPattern([
    TransientEvent(intensity: 0.45, sharpness: 0.75),
  ]);

  /// A notch on a slider, a snap point on a sheet.
  static const detent = HapticPattern([
    TransientEvent(intensity: 0.55, sharpness: 0.9),
  ]);

  /// Dense notches, for close spacing. Light so a fast drag never buzzes.
  static const fineDetent = HapticPattern([
    TransientEvent(intensity: 0.32, sharpness: 0.95),
  ]);

  /// An end stop: a dull thud and a small rebound. Says "no further".
  static const bump = HapticPattern([
    TransientEvent(intensity: 0.9, sharpness: 0.25),
    TransientEvent(
      intensity: 0.35,
      sharpness: 0.2,
      delay: Duration(milliseconds: 90),
    ),
  ]);

  /// A switch moving to on: bright and crisp.
  static const switchOn = HapticPattern([
    TransientEvent(intensity: 0.7, sharpness: 0.9),
  ]);

  /// A switch moving to off: dull and soft. Direction you can feel.
  static const switchOff = HapticPattern([
    TransientEvent(intensity: 0.5, sharpness: 0.2),
  ]);

  // ─── Social & messaging ────────────────────────────────────────────

  /// A like, a reaction landing: one bright pop.
  static const pop = HapticPattern([
    TransientEvent(intensity: 0.85, sharpness: 1.0),
  ]);

  /// Taking a like back: deliberately smaller than [pop]. Positive actions
  /// earn richer feedback than their reversal.
  static const unpop = HapticPattern([
    TransientEvent(intensity: 0.3, sharpness: 0.2),
  ]);

  /// A message leaving: a short swell that brightens as it goes.
  static const whoosh = HapticPattern([
    ContinuousEvent.curved(
      intensity: CurveParam([(0.0, 0.0), (0.35, 0.45), (1.0, 0.0)]),
      sharpness: LinearParam(from: 0.2, to: 0.8),
      duration: Duration(milliseconds: 180),
    ),
  ]);

  /// Undo: three taps falling away, the reverse of [HapticPatterns.success].
  static const rewind = HapticPattern([
    TransientEvent(intensity: 0.9, sharpness: 0.7),
    TransientEvent(
      intensity: 0.6,
      sharpness: 0.5,
      delay: Duration(milliseconds: 80),
    ),
    TransientEvent(
      intensity: 0.35,
      sharpness: 0.3,
      delay: Duration(milliseconds: 160),
    ),
  ]);

  // ─── Objects ───────────────────────────────────────────────────────

  /// A camera shutter: mirror up, mirror down.
  static const shutter = HapticPattern([
    TransientEvent(intensity: 1.0, sharpness: 1.0),
    TransientEvent(
      intensity: 0.55,
      sharpness: 0.45,
      delay: Duration(milliseconds: 80),
    ),
  ]);

  /// A heavy thing landing: one deep hit with a short tail.
  static const thud = HapticPattern([
    TransientEvent(intensity: 1.0, sharpness: 0.15),
    ContinuousEvent.curved(
      intensity: CurveParam([(0.0, 0.5), (1.0, 0.0)]),
      sharpness: ConstantParam(0.1),
      duration: Duration(milliseconds: 90),
    ),
  ]);

  /// A vault bolt sliding home: rigid click, then a heavy seat.
  static const lock = HapticPattern([
    TransientEvent(intensity: 0.8, sharpness: 1.0),
    TransientEvent(
      intensity: 1.0,
      sharpness: 0.3,
      delay: Duration(milliseconds: 90),
    ),
  ]);

  /// A coin picked up: two bright pings, the second higher.
  static const coin = HapticPattern([
    TransientEvent(intensity: 0.6, sharpness: 0.9),
    TransientEvent(
      intensity: 0.9,
      sharpness: 1.0,
      delay: Duration(milliseconds: 80),
    ),
  ]);

  // ─── Brand moments ─────────────────────────────────────────────────

  /// The payment-complete moment. The only pattern in the app allowed to be
  /// this long, because it happens once per purchase and marks money moving.
  static const celebrate = HapticPattern([
    TransientEvent(intensity: 0.55, sharpness: 0.5),
    TransientEvent(
      intensity: 0.75,
      sharpness: 0.65,
      delay: Duration(milliseconds: 80),
    ),
    TransientEvent(
      intensity: 1.0,
      sharpness: 0.9,
      delay: Duration(milliseconds: 160),
    ),
    ContinuousEvent.curved(
      intensity: CurveParam([(0.0, 0.0), (0.15, 0.5), (1.0, 0.0)]),
      sharpness: LinearParam(from: 0.8, to: 0.3),
      duration: Duration(milliseconds: 420),
      delay: Duration(milliseconds: 200),
    ),
  ]);
}
