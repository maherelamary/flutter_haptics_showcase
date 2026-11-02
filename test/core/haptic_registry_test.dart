import 'dart:io';

import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_haptics.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_patterns.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/haptic_registry.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/haptic_source.dart';
import 'package:flutter_test/flutter_test.dart';

Iterable<String> _members(String path) => RegExp(r'static const (\w+)')
    .allMatches(File(path).readAsStringSync())
    .map((m) => m[1]!);

void main() {
  test('every AppHaptics member is registered', () {
    for (final member in _members('lib/src/core/haptics/app_haptics.dart')) {
      expect(
        HapticRegistry.lookup('AppHaptics', member),
        isNotNull,
        reason: 'Add AppHaptics.$member to HapticRegistry',
      );
    }
  });

  test('every AppPatterns member is registered', () {
    for (final member in _members('lib/src/core/haptics/app_patterns.dart')) {
      expect(
        HapticRegistry.lookup('AppPatterns', member),
        isNotNull,
        reason: 'Add AppPatterns.$member to HapticRegistry',
      );
    }
  });

  test('scan finds each name once, in order', () {
    final refs = HapticRegistry.scan(
      'perform(AppHaptics.limit); play(AppPatterns.pop); '
      'perform(AppHaptics.limit); HapticPatterns.selection; AppHaptics.nope',
    );
    expect(refs.map((r) => r.name), [
      'AppHaptics.limit',
      'AppPatterns.pop',
      'HapticPatterns.selection',
    ]);
  });

  test('declarations are generated from the live values', () {
    final source = HapticSource.declarations(
      HapticRegistry.scan('AppHaptics.switchOn AppHaptics.caution'),
    );
    expect(source, contains('static const switchOn = HapticIntent('));
    expect(source, contains('ios: HapticArm.native(IOSHaptic.impactLight),'));
    expect(
      source,
      contains('android: HapticArm.native(AndroidHaptic.toggleOn), // API 34'),
    );
    expect(source, contains('pattern: AppPatterns.switchOn,'));
    expect(source, contains('static const caution = HapticIntent('));
    expect(source, contains('android: HapticArm.pattern(),\n'));
    expect(source, contains('pattern: HapticPatterns.warning,'));
    expect(
      source,
      contains('TransientEvent(intensity: 0.7, sharpness: 0.9)'),
    );
  });

  test('numbers print without float noise', () {
    expect(HapticSource.number(0.1 + 0.2), '0.3');
    expect(HapticSource.number(1), '1.0');
    expect(
      HapticSource.param(HapticParam.fadeOut),
      'HapticParam.fadeOut',
    );
  });

  test('labels name every registered pattern, and describe the rest', () {
    expect(HapticRegistry.labelOf(HapticPatterns.success), 'success');
    expect(HapticRegistry.labelOf(AppPatterns.keyClick), 'keyClick');
    expect(
      HapticRegistry.labelOf(
        const HapticPattern([TransientEvent(intensity: 0.42)]),
      ),
      '1 event · 25ms',
    );
    expect(
      HapticRegistry.allPatterns.keys,
      [
        ...HapticRegistry.libraryPatterns.keys,
        ...HapticRegistry.appPatterns.keys,
      ],
      reason: 'every name is unique across the library and the app',
    );
  });

  test('arms are written the way they are declared', () {
    expect(
      HapticSource.arm(AppHaptics.caution.android, 'AndroidHaptic'),
      'HapticArm.pattern()',
    );
    expect(
      HapticSource.arm(AppHaptics.caution.ios, 'IOSHaptic'),
      'HapticArm.native(IOSHaptic.notificationWarning)',
    );
    expect(
      HapticSource.arm(const HapticArm<IOSHaptic>.silent(), 'IOSHaptic'),
      'HapticArm.silent()',
    );
  });
}
