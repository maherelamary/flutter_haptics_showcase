import 'package:clock/clock.dart';

/// Keeps continuous gestures from flooding the actuator, where a
/// `HapticHandle` cannot.
///
/// A handle from `FlutterHaptics.register` paces itself to the device's
/// floor, so a single pattern fired from a drag needs nothing more. A pacer
/// is still the tool for the two cases a handle does not cover:
///
/// - **Intents and system constants.** `register` takes only patterns, so a
///   slider that performs `AppHaptics.fineDetent` per notch has to pace
///   itself.
/// - **Several handles that share one budget.** Each handle paces only
///   itself; a texture that picks one of five handles per grain could still
///   fire five times inside the floor.
///
/// ```dart
/// final _pacer = HapticPacer();
///
/// void _onDragUpdate(DragUpdateDetails d) {
///   if (crossedANotch && _pacer.ready()) {
///     FlutterHaptics.perform(AppHaptics.fineDetent);
///   }
/// }
/// ```
///
/// 40 ms is about the fastest rate at which separate taps still read as
/// separate on most hardware; below that they fuse.
///
/// Time is read through `package:clock`, as the package's own handles read
/// it, so `testWidgets` pumps advance it. A `Stopwatch` measures real time,
/// which a pump does not move, and would drop haptics in widget tests.
class HapticPacer {
  HapticPacer({this.minInterval = const Duration(milliseconds: 40)});

  /// The shortest gap allowed between two haptics.
  final Duration minInterval;

  DateTime? _last;

  /// Whether enough time has passed. Records the moment when it returns true.
  bool ready() {
    final now = clock.now();
    final last = _last;
    if (last != null) {
      final since = now.difference(last);
      // A clock moved backwards (NTP, a manual change) plays rather than
      // muting the pacer until it catches up.
      if (!since.isNegative && since < minInterval) return false;
    }
    _last = now;
    return true;
  }

  /// Forgets the last haptic, so the next [ready] is always true.
  void reset() => _last = null;
}
