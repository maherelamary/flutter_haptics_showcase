import 'package:flutter_haptics/flutter_haptics.dart';

/// The result of an AHAP import: the pattern, or why it could not be read.
typedef AhapImport = ({HapticPattern? pattern, String? error});

/// Reads patterns from outside the app into the Studio.
abstract final class StudioImport {
  /// Parses the text of an `.ahap` file. Any failure comes back as a
  /// message fit to show the user, never as a throw.
  static AhapImport ahap(String text) {
    final source = text.trim();
    if (source.isEmpty) {
      return (
        pattern: null,
        error: 'The clipboard is empty — copy the contents of an .ahap file '
            'first.',
      );
    }

    final HapticPattern pattern;
    try {
      pattern = Ahap.decode(source);
    } on FormatException catch (error) {
      return (pattern: null, error: 'Not valid AHAP: ${error.message}');
    } on Object {
      // Ahap.decode reports bad input as a FormatException; this is the
      // backstop for anything else a malformed file provokes, so a bad
      // import is a message rather than a crash.
      return (
        pattern: null,
        error: 'Not valid AHAP: a field has the wrong type.',
      );
    }
    if (pattern.events.isEmpty) {
      return (
        pattern: null,
        error: 'That AHAP has no haptic events. Audio events are dropped.',
      );
    }
    return (pattern: pattern, error: null);
  }
}
