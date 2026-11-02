import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_haptics.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_patterns.dart';

/// One name a snippet refers to — `AppHaptics.limit`, `AppPatterns.pop`,
/// `HapticPatterns.selection` — resolved to the value behind it.
class HapticReference {
  const HapticReference.intent(this.name, HapticIntent this.intent)
    : pattern = null;

  const HapticReference.pattern(this.name, HapticPattern this.pattern)
    : intent = null;

  /// Fully qualified, as written in code.
  final String name;
  final HapticIntent? intent;
  final HapticPattern? pattern;

  /// The member name alone: `limit` for `AppHaptics.limit`.
  String get member => name.substring(name.indexOf('.') + 1);

  /// The class the member lives on: `AppHaptics`.
  String get owner => name.substring(0, name.indexOf('.'));
}

/// Every intent and pattern a showcase snippet can name, so the detail page
/// can show what each one actually resolves to — read from the real values,
/// never retyped.
abstract final class HapticRegistry {
  static const intents = <String, HapticIntent>{
    'press': AppHaptics.press,
    'tap': AppHaptics.tap,
    'key': AppHaptics.key,
    'longPress': AppHaptics.longPress,
    'tick': AppHaptics.tick,
    'detent': AppHaptics.detent,
    'fineDetent': AppHaptics.fineDetent,
    'limit': AppHaptics.limit,
    'switchOn': AppHaptics.switchOn,
    'switchOff': AppHaptics.switchOff,
    'armed': AppHaptics.armed,
    'disarmed': AppHaptics.disarmed,
    'lift': AppHaptics.lift,
    'drop': AppHaptics.drop,
    'success': AppHaptics.success,
    'failure': AppHaptics.failure,
    'caution': AppHaptics.caution,
  };

  static const appPatterns = <String, HapticPattern>{
    'keyClick': AppPatterns.keyClick,
    'detent': AppPatterns.detent,
    'fineDetent': AppPatterns.fineDetent,
    'bump': AppPatterns.bump,
    'switchOn': AppPatterns.switchOn,
    'switchOff': AppPatterns.switchOff,
    'pop': AppPatterns.pop,
    'unpop': AppPatterns.unpop,
    'whoosh': AppPatterns.whoosh,
    'rewind': AppPatterns.rewind,
    'shutter': AppPatterns.shutter,
    'thud': AppPatterns.thud,
    'lock': AppPatterns.lock,
    'coin': AppPatterns.coin,
    'celebrate': AppPatterns.celebrate,
  };

  // `const`: every library pattern is, buzz and longBuzz included.
  static const libraryPatterns = <String, HapticPattern>{
    'lightTap': HapticPatterns.lightTap,
    'mediumTap': HapticPatterns.mediumTap,
    'heavyTap': HapticPatterns.heavyTap,
    'soft': HapticPatterns.soft,
    'rigid': HapticPatterns.rigid,
    'selection': HapticPatterns.selection,
    'doubleClick': HapticPatterns.doubleClick,
    'tripleClick': HapticPatterns.tripleClick,
    'success': HapticPatterns.success,
    'warning': HapticPatterns.warning,
    'error': HapticPatterns.error,
    'heartbeat': HapticPatterns.heartbeat,
    'buzz': HapticPatterns.buzz,
    'longBuzz': HapticPatterns.longBuzz,
    'explosion': HapticPatterns.explosion,
    'engineRev': HapticPatterns.engineRev,
    'pulseWave': HapticPatterns.pulseWave,
    'impactDecay': HapticPatterns.impactDecay,
    'chargeUp': HapticPatterns.chargeUp,
  };

  static final RegExp _name = RegExp(
    r'\b(AppHaptics|AppPatterns|HapticPatterns)\.([a-zA-Z]\w*)',
  );

  /// Resolves `Owner.member`, or null if it isn't a known intent or pattern.
  static HapticReference? lookup(String owner, String member) {
    final name = '$owner.$member';
    switch (owner) {
      case 'AppHaptics':
        final intent = intents[member];
        if (intent != null) return HapticReference.intent(name, intent);
      case 'AppPatterns':
        final pattern = appPatterns[member];
        if (pattern != null) return HapticReference.pattern(name, pattern);
      case 'HapticPatterns':
        final pattern = libraryPatterns[member];
        if (pattern != null) return HapticReference.pattern(name, pattern);
    }
    return null;
  }

  /// Every known name mentioned in [text], in order of first appearance.
  static List<HapticReference> scan(String text) {
    final seen = <String>{};
    final found = <HapticReference>[];
    for (final match in _name.allMatches(text)) {
      final reference = lookup(match[1]!, match[2]!);
      if (reference != null && seen.add(reference.name)) found.add(reference);
    }
    return found;
  }

  /// Every named pattern, library first then the app's, keyed by member
  /// name — for pickers.
  static Map<String, HapticPattern> get allPatterns => {
    ...libraryPatterns,
    ...appPatterns,
  };

  static final Map<HapticPattern, String> _labels = {
    for (final entry in allPatterns.entries) entry.value: entry.key,
  };

  /// A short label for [pattern]: its member name (`success`, `keyClick`)
  /// when it is a named one, otherwise its shape (`3 events · 160ms`).
  ///
  /// Patterns compare by value, so a pattern equal to a named one is
  /// recognised wherever it was built.
  static String labelOf(HapticPattern pattern) =>
      _labels[pattern] ??
      '${pattern.events.length} '
          '${pattern.events.length == 1 ? 'event' : 'events'} · '
          '${pattern.duration.inMilliseconds}ms';

  /// The qualified name a pattern is known by, preferring the app's own.
  static String? nameOf(HapticPattern pattern) {
    for (final entry in appPatterns.entries) {
      if (entry.value == pattern) return 'AppPatterns.${entry.key}';
    }
    for (final entry in libraryPatterns.entries) {
      if (entry.value == pattern) return 'HapticPatterns.${entry.key}';
    }
    return null;
  }
}
