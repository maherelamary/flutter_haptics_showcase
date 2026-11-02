import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_typography.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_haptics.dart';

/// A syntax-highlighted, horizontally scrolling code panel with a copy
/// button.
class CodeBlock extends StatelessWidget {
  const CodeBlock(
    this.code, {
    super.key,
    this.label = 'dart',
    this.maxHeight,
  });

  final String code;
  final String label;

  /// Caps the height and scrolls vertically past it.
  final double? maxHeight;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: code));
    FlutterHaptics.perform(AppHaptics.tap);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
  }

  @override
  Widget build(BuildContext context) {
    final body = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Text.rich(
        label == 'dart' || label.endsWith('.dart')
            ? DartHighlighter.highlight(code)
            : TextSpan(text: code, style: AppTypography.mono),
        softWrap: false,
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 4, 0),
            child: Row(
              children: [
                Text(label.toUpperCase(), style: AppTypography.eyebrow),
                const Spacer(),
                IconButton(
                  tooltip: 'Copy',
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  color: AppColors.textMuted,
                  icon: const Icon(Icons.copy_rounded),
                  onPressed: () => _copy(context),
                ),
              ],
            ),
          ),
          if (maxHeight == null)
            body
          else
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight!),
              child: SingleChildScrollView(child: body),
            ),
        ],
      ),
    );
  }
}

/// A small, dependency-free Dart highlighter. Good enough for snippets.
abstract final class DartHighlighter {
  static const _keyword = Color(0xFFC792FF);
  static const _string = Color(0xFFC3E88D);
  static const _comment = Color(0xFF62626E);
  static const _number = Color(0xFFFF9E64);
  static const _type = Color(0xFF5EEAD4);
  static const _annotation = Color(0xFFFFB547);
  static const _plain = Color(0xFFE6E6EA);

  static final RegExp _token = RegExp(
    r'(?<comment>//[^\n]*)'
    r"|(?<string>'(?:[^'\\\n]|\\.)*'|" r'"(?:[^"\\\n]|\\.)*")'
    r'|(?<annotation>@\w+)'
    r'|(?<keyword>\b(?:abstract|async|await|break|case|class|const|continue|'
    r'default|else|enum|extends|false|final|for|if|import|in|late|new|null|'
    r'override|required|return|static|super|switch|this|true|var|void|while|'
    r'with|yield)\b)'
    r'|(?<number>\b\d+(?:\.\d+)?\b)'
    r'|(?<type>\b[A-Z][A-Za-z0-9_]*\b)',
  );

  static TextSpan highlight(String code) {
    final spans = <TextSpan>[];
    var cursor = 0;
    for (final match in _token.allMatches(code)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: code.substring(cursor, match.start)));
      }
      spans.add(TextSpan(text: match[0], style: _styleFor(match)));
      cursor = match.end;
    }
    if (cursor < code.length) spans.add(TextSpan(text: code.substring(cursor)));
    return TextSpan(
      style: AppTypography.mono.copyWith(color: _plain),
      children: spans,
    );
  }

  static TextStyle _styleFor(RegExpMatch match) {
    if (match.namedGroup('comment') != null) {
      return const TextStyle(color: _comment, fontStyle: FontStyle.italic);
    }
    if (match.namedGroup('string') != null) {
      return const TextStyle(color: _string);
    }
    if (match.namedGroup('annotation') != null) {
      return const TextStyle(color: _annotation);
    }
    if (match.namedGroup('keyword') != null) {
      return const TextStyle(color: _keyword, fontWeight: FontWeight.w600);
    }
    if (match.namedGroup('number') != null) {
      return const TextStyle(color: _number);
    }
    return const TextStyle(color: _type);
  }
}
