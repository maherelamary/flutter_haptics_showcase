import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/haptic_registry.dart';

/// Writes intents and patterns back out as the Dart that would declare them,
/// so a snippet's definitions are generated from the live values.
abstract final class HapticSource {
  /// Below this, a constant is available on every device the app supports.
  static const minSdk = 24;

  static final _presets = <HapticParam, String>{
    HapticParam.fadeIn: 'HapticParam.fadeIn',
    HapticParam.fadeOut: 'HapticParam.fadeOut',
    HapticParam.rampUp: 'HapticParam.rampUp',
    HapticParam.rampDown: 'HapticParam.rampDown',
    HapticParam.pulse: 'HapticParam.pulse',
    HapticParam.spike: 'HapticParam.spike',
  };

  /// The declarations for [references], plus any app pattern an intent falls
  /// back to, each written once.
  static String declarations(List<HapticReference> references) {
    final intents = <String, String>{};
    final patterns = <String, String>{};
    final builtIns = <String, String>{};

    void addPattern(String name, HapticPattern pattern) {
      if (name.startsWith('HapticPatterns.')) {
        builtIns.putIfAbsent(name, () => _builtIn(name, pattern));
      } else {
        patterns.putIfAbsent(name, () => _pattern(name, pattern));
      }
    }

    for (final reference in references) {
      final intent = reference.intent;
      final pattern = reference.pattern;
      if (intent != null) {
        intents.putIfAbsent(
          reference.name,
          () => _intent(reference.member, intent),
        );
        final fallback = HapticRegistry.nameOf(intent.pattern);
        if (fallback != null) addPattern(fallback, intent.pattern);
      } else if (pattern != null) {
        addPattern(reference.name, pattern);
      }
    }

    final sections = <String>[
      if (intents.isNotEmpty)
        '// app_haptics.dart\n${intents.values.join('\n\n')}',
      if (patterns.isNotEmpty)
        '// app_patterns.dart\n${patterns.values.join('\n\n')}',
      if (builtIns.isNotEmpty)
        '// built into flutter_haptics\n${builtIns.values.join('\n')}',
    ];
    return sections.join('\n\n');
  }

  static String _intent(String member, HapticIntent intent) {
    final fallback =
        HapticRegistry.nameOf(intent.pattern) ?? 'HapticPattern(/* … */)';
    final android = intent.android;
    final api = android is NativeArm<AndroidHaptic> &&
            android.haptic.minimumVersion > minSdk
        ? ' // API ${android.haptic.minimumVersion}'
        : '';
    return 'static const $member = HapticIntent(\n'
        '  ios: ${arm(intent.ios, 'IOSHaptic')},\n'
        '  android: ${arm(android, 'AndroidHaptic')},$api\n'
        '  pattern: $fallback,\n'
        ');';
  }

  /// One arm as it is written: `HapticArm.native(IOSHaptic.selection)`.
  static String arm(HapticArm<SystemHaptic> arm, String vocabulary) =>
      switch (arm) {
        NativeArm(:final haptic) =>
          'HapticArm.native($vocabulary.${haptic.name})',
        PatternArm() => 'HapticArm.pattern()',
        SilentArm() => 'HapticArm.silent()',
      };

  static String _pattern(String name, HapticPattern pattern) {
    final member = name.substring(name.indexOf('.') + 1);
    final events = pattern.events.map((e) => '  ${event(e)},').join('\n');
    return 'static const $member = HapticPattern([\n$events\n]);';
  }

  static String _builtIn(String name, HapticPattern pattern) {
    final events = pattern.events.map(event).join(', ');
    return '// $name = [$events]';
  }

  /// One event as a constructor call.
  static String event(HapticEvent event) => switch (event) {
        TransientEvent() => 'TransientEvent(intensity: ${number(event.intensity)}, '
            'sharpness: ${number(event.sharpness)}${_delay(event.delay)})',
        ContinuousEvent() => 'ContinuousEvent.curved('
            'intensity: ${param(event.intensity)}, '
            'sharpness: ${param(event.sharpness)}, '
            'duration: Duration(milliseconds: ${event.duration.inMilliseconds})'
            '${_delay(event.delay)})',
      };

  static String param(HapticParam param) =>
      _presets[param] ??
      switch (param) {
        ConstantParam(:final value) => 'ConstantParam(${number(value)})',
        LinearParam(:final from, :final to) =>
          'LinearParam(from: ${number(from)}, to: ${number(to)})',
        CurveParam(:final points) => 'CurveParam(['
            '${points.map((p) => '(${number(p.$1)}, ${number(p.$2)})').join(', ')}'
            '])',
      };

  static String _delay(Duration delay) => delay == Duration.zero
      ? ''
      : ', delay: Duration(milliseconds: ${delay.inMilliseconds})';

  /// `1.0`, `0.25`, `0.3` — never `0.30000000000000004`.
  static String number(double value) {
    final rounded = (value * 1000).round() / 1000;
    final text = rounded.toString();
    return text.contains('.') ? text : '$text.0';
  }

  /// A short human summary: `3 taps · 1 rumble · 620 ms`.
  static String summary(HapticPattern pattern) {
    final taps = pattern.events.whereType<TransientEvent>().length;
    final rumbles = pattern.events.whereType<ContinuousEvent>().length;
    return [
      if (taps > 0) '$taps ${taps == 1 ? 'tap' : 'taps'}',
      if (rumbles > 0) '$rumbles ${rumbles == 1 ? 'rumble' : 'rumbles'}',
      '${pattern.duration.inMilliseconds} ms',
    ].join(' · ');
  }
}
