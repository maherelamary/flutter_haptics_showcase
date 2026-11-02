import 'package:flutter_haptics_showcase/src/features/studio/domain/studio_codegen.dart';
import 'package:flutter_haptics_showcase/src/features/studio/domain/studio_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StudioCodegen.identifier', () {
    test('turns free text into lowerCamelCase', () {
      expect(StudioCodegen.identifier('Double tap'), 'doubleTap');
      expect(StudioCodegen.identifier('heart-beat v2'), 'heartBeatV2');
      expect(StudioCodegen.identifier('  Unlock  '), 'unlock');
    });

    test('drops characters Dart cannot use', () {
      expect(StudioCodegen.identifier('pay \$5 now!'), 'pay5Now');
      expect(StudioCodegen.identifier('café'), 'caf');
    });

    test('falls back to pattern when nothing usable is left', () {
      expect(StudioCodegen.identifier(''), 'pattern');
      expect(StudioCodegen.identifier('!!!'), 'pattern');
      expect(StudioCodegen.identifier('نبض'), 'pattern');
    });

    test('prefixes names that start with a digit', () {
      expect(StudioCodegen.identifier('2 fast'), 'pattern2Fast');
      expect(StudioCodegen.identifier('3d touch'), 'pattern3dTouch');
    });

    test('prefixes reserved words', () {
      expect(StudioCodegen.identifier('class'), 'patternClass');
      expect(StudioCodegen.identifier('Switch'), 'patternSwitch');
      expect(StudioCodegen.identifier('True'), 'patternTrue');
    });

    test('prefixes await and yield, since the snippet is async', () {
      expect(StudioCodegen.identifier('Await'), 'patternAwait');
      expect(StudioCodegen.identifier('yield'), 'patternYield');
    });

    test('leaves names that only contain a reserved word alone', () {
      expect(StudioCodegen.identifier('class act'), 'classAct');
      expect(StudioCodegen.identifier('newer'), 'newer');
    });

    test('leaves built-in identifiers alone: they are valid names', () {
      expect(StudioCodegen.identifier('late'), 'late');
      expect(StudioCodegen.identifier('required'), 'required');
    });

    test('names the variable in the generated snippet', () {
      final code = StudioCodegen.dart(const StudioDraft(name: 'Switch'));
      expect(code, contains('const patternSwitch = HapticPattern.empty;'));
      expect(code, contains('await FlutterHaptics.play(patternSwitch);'));
    });
  });
}
