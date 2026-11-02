import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/features/studio/domain/studio_draft.dart';
import 'package:flutter_haptics_showcase/src/features/studio/domain/studio_event.dart';

/// The result of an AHAP export: the file, or why it could not be written.
typedef AhapExport = ({String? json, String? error});

/// Turns a Studio draft into something a client app can ship.
abstract final class StudioCodegen {
  /// A `HapticPatternBuilder` chain that rebuilds the draft exactly.
  static String dart(StudioDraft draft) {
    final name = identifier(draft.name);
    final pattern = draft.toPattern();
    final out = StringBuffer()
      ..writeln(
        '// Flutter Haptics Tactile Studio · ${draft.name} · '
        '${draft.events.length} '
        '${draft.events.length == 1 ? 'event' : 'events'} · '
        '${pattern.duration.inMilliseconds}ms',
      );

    if (draft.events.isEmpty) {
      out
        ..writeln('const $name = HapticPattern.empty;')
        ..writeln()
        ..write('await FlutterHaptics.play($name);');
      return out.toString();
    }

    out.writeln('final $name = HapticPatternBuilder()');
    for (final event in draft.events) {
      if (event.gapMs > 0) out.writeln('    .waitMs(${event.gapMs})');
      switch (event.kind) {
        case StudioEventKind.tap:
          out.writeln(
            '    .tap(intensity: ${number(event.intensity)}, '
            'sharpness: ${number(event.sharpness)})',
          );
        case StudioEventKind.rumble:
          if (event.curve == StudioCurve.flat) {
            out
              ..writeln('    .rumble(')
              ..writeln(
                '      duration: '
                'const Duration(milliseconds: ${event.durationMs}),',
              )
              ..writeln('      intensity: ${number(event.intensity)},')
              ..writeln('      sharpness: ${number(event.sharpness)},')
              ..writeln('    )');
          } else {
            out
              ..writeln('    .rumbleCurved(')
              ..writeln(
                '      duration: '
                'const Duration(milliseconds: ${event.durationMs}),',
              )
              ..writeln(
                '      intensity: '
                '${param(event.curve.toParam(event.intensity))},',
              )
              ..writeln(
                '      sharpness: const HapticParam.constant('
                '${number(event.sharpness)}),',
              )
              ..writeln('    )');
          }
      }
    }
    out
      ..writeln('    .build();')
      ..writeln()
      ..write('await FlutterHaptics.play($name);');
    return out.toString();
  }

  /// The draft as an `.ahap` file, with Flutter Haptics Tactile metadata.
  static AhapExport ahap(StudioDraft draft) {
    try {
      final json = Ahap.encode(
        draft.toPattern(),
        metadata: {
          'Project': 'Flutter Haptics Tactile Studio',
          'Created': DateTime.now().toIso8601String(),
          'Description': draft.name,
        },
      );
      return (json: json, error: null);
    } on StateError catch (error) {
      return (json: null, error: error.message);
    }
  }

  /// A parameter as the const expression a developer would write.
  static String param(HapticParam param) => switch (param) {
        ConstantParam(:final value) =>
          'const HapticParam.constant(${number(value)})',
        LinearParam(:final from, :final to) =>
          'const HapticParam.linear(from: ${number(from)}, to: ${number(to)})',
        CurveParam(:final points) => 'const HapticParam.curve(['
            '${points.map((p) => '(${number(p.$1)}, ${number(p.$2)})').join(', ')}'
            '])',
      };

  /// `0.7`, `1.0`, `0.225` — never `0.7000000001`.
  ///
  /// Four places, not two: a ramp starts at 0.3 of its peak, so a peak of
  /// 0.75 plays 0.225, and two places would print a different pattern.
  static String number(double value) {
    var text = value.toStringAsFixed(4);
    while (text.endsWith('0') && !text.endsWith('.0')) {
      text = text.substring(0, text.length - 1);
    }
    return text;
  }

  /// Words that cannot name a variable: Dart's reserved words, plus `await`
  /// and `yield`, since the snippet ends in an `await` and so runs inside an
  /// async function.
  static const _reserved = {
    'assert', 'await', 'break', 'case', 'catch', 'class', 'const',
    'continue', 'default', 'do', 'else', 'enum', 'extends', 'false',
    'final', 'finally', 'for', 'if', 'in', 'is', 'new', 'null', 'rethrow',
    'return', 'super', 'switch', 'this', 'throw', 'true', 'try', 'var',
    'void', 'while', 'with', 'yield',
  };

  /// A lowerCamelCase Dart identifier from a free-text name. Names that
  /// would not compile — empty, starting with a digit, or a reserved word —
  /// get a `pattern` prefix.
  static String identifier(String name) {
    final words = name
        .split(RegExp('[^A-Za-z0-9]+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return 'pattern';
    final buffer = StringBuffer(
      words.first[0].toLowerCase() + words.first.substring(1),
    );
    for (final word in words.skip(1)) {
      buffer.write(word[0].toUpperCase() + word.substring(1));
    }
    final result = buffer.toString();
    if (RegExp('^[0-9]').hasMatch(result)) return 'pattern$result';
    if (_reserved.contains(result)) {
      return 'pattern${result[0].toUpperCase()}${result.substring(1)}';
    }
    return result;
  }
}
