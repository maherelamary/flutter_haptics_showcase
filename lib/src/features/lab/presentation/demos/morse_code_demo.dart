import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_typography.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_haptics.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/pattern_waveform.dart';
import 'package:flutter_haptics_showcase/src/features/lab/presentation/widgets/lab_layout.dart';

/// One dot or dash, placed on the pattern's timeline.
class _Symbol {
  const _Symbol({
    required this.dash,
    required this.startMs,
    required this.endMs,
    required this.charIndex,
  });

  final bool dash;
  final int startMs;
  final int endMs;
  final int charIndex;
}

/// A message encoded as Morse, built with HapticPatternBuilder and played
/// as one pattern.
class _MorseMessage {
  _MorseMessage._(this.text, this.pattern, this.symbols);

  factory _MorseMessage.encode(String raw) {
    final text = raw.toUpperCase();
    final builder = HapticPatternBuilder();
    final symbols = <_Symbol>[];
    // Mirror the builder's cursor so the screen can follow the pattern.
    var cursor = 0;
    var pendingGap = 0;

    for (var i = 0; i < text.length; i++) {
      final code = table[text[i]];
      if (text[i] == ' ') {
        // A word gap is seven units, replacing the letter gap.
        pendingGap = unit * 7;
        continue;
      }
      if (code == null) continue;
      for (var s = 0; s < code.length; s++) {
        if (pendingGap > 0 && cursor > 0) {
          builder.waitMs(pendingGap);
          cursor += pendingGap;
        }
        pendingGap = 0;
        final dash = code[s] == '-';
        final start = cursor;
        if (dash) {
          builder.rumble(
            duration: const Duration(milliseconds: dashMs),
            intensity: 0.8,
          );
          cursor += dashMs;
        } else {
          builder.tap(intensity: 0.8, sharpness: 0.8);
          // tap() advances 25 ms; a dot occupies one full unit.
          builder.waitMs(unit - HapticEvent.transientWidth.inMilliseconds);
          cursor += unit;
        }
        symbols.add(
          _Symbol(dash: dash, startMs: start, endMs: cursor, charIndex: i),
        );
        // Gap inside a letter: one unit.
        pendingGap = unit;
      }
      // Gap between letters: three units in total.
      pendingGap = unit * 3;
    }
    return _MorseMessage._(text, builder.build(), symbols);
  }

  /// The length of a dot, and of the gap inside a letter.
  static const unit = 90;

  /// Three units, as in standard Morse.
  static const dashMs = unit * 3;

  static const table = <String, String>{
    'A': '.-',
    'B': '-...',
    'C': '-.-.',
    'D': '-..',
    'E': '.',
    'F': '..-.',
    'G': '--.',
    'H': '....',
    'I': '..',
    'J': '.---',
    'K': '-.-',
    'L': '.-..',
    'M': '--',
    'N': '-.',
    'O': '---',
    'P': '.--.',
    'Q': '--.-',
    'R': '.-.',
    'S': '...',
    'T': '-',
    'U': '..-',
    'V': '...-',
    'W': '.--',
    'X': '-..-',
    'Y': '-.--',
    'Z': '--..',
    '0': '-----',
    '1': '.----',
    '2': '..---',
    '3': '...--',
    '4': '....-',
    '5': '.....',
    '6': '-....',
    '7': '--...',
    '8': '---..',
    '9': '----.',
  };

  final String text;
  final HapticPattern pattern;
  final List<_Symbol> symbols;

  bool get isEmpty => symbols.isEmpty;
}

/// Type a message and feel it in Morse — information carried by rhythm
/// alone, which survives every device tier.
class MorseCodeDemo extends StatefulWidget {
  const MorseCodeDemo({super.key});

  @override
  State<MorseCodeDemo> createState() => _MorseCodeDemoState();
}

class _MorseCodeDemoState extends State<MorseCodeDemo>
    with SingleTickerProviderStateMixin {
  final _field = TextEditingController(text: 'SOS HI');
  late _MorseMessage _message = _MorseMessage.encode(_field.text);
  late final AnimationController _play = AnimationController(vsync: this)
    ..addListener(() => setState(() {}));
  late final AppLifecycleListener _lifecycle;

  bool get _playing => _play.isAnimating;

  void _onChanged(String value) {
    if (_playing) _stop();
    setState(() => _message = _MorseMessage.encode(value));
  }

  void _start() {
    if (_message.isEmpty) return;
    FocusScope.of(context).unfocus();
    FlutterHaptics.play(_message.pattern);
    _play
      ..duration = _message.pattern.duration
      ..forward(from: 0);
  }

  void _stop() {
    _halt();
    FlutterHaptics.perform(AppHaptics.tap);
  }

  /// Ends playback without the acknowledging tap: for leaving, not pressing.
  void _halt() {
    FlutterHaptics.stop();
    _play
      ..stop()
      ..value = 0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The tab shell keeps this page alive offstage with its tickers muted,
    // but the message is one pattern already on the actuator. Leaving the
    // tab stops it rather than letting it buzz out of sight.
    if (!TickerMode.valuesOf(context).enabled && _playing) _halt();
  }

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: () {
        if (_playing) _halt();
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    if (_playing) FlutterHaptics.stop();
    _play.dispose();
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final elapsed = _play.value * _message.pattern.duration.inMilliseconds;
    final active = _playing
        ? _message.symbols
              .where((s) => elapsed >= s.startMs && elapsed < s.endMs)
              .firstOrNull
        : null;

    return LabLayout(
      hint:
          'Type up to 24 letters and press Play. Dots are taps, dashes '
          'are short rumbles — only timing carries the message.',
      status: TextField(
        controller: _field,
        maxLength: 24,
        textCapitalization: TextCapitalization.characters,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9 ]')),
        ],
        style: AppTypography.mono.copyWith(fontSize: 16, letterSpacing: 2),
        decoration: const InputDecoration(
          hintText: 'Your message',
          counterText: '',
          prefixIcon: Icon(Icons.edit_rounded, size: 18),
        ),
        onChanged: _onChanged,
        onSubmitted: (_) => _start(),
      ),
      stage: LabPanel(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 14,
                  runSpacing: 16,
                  children: [
                    for (var i = 0; i < _message.text.length; i++)
                      _Letter(
                        char: _message.text[i],
                        symbols: _message.symbols
                            .where((s) => s.charIndex == i)
                            .toList(),
                        active: active,
                        done: (s) => _playing && elapsed >= s.endMs,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _message.isEmpty
                  ? 'PATTERN'
                  : 'PATTERN · ${_message.pattern.events.length} EVENTS · '
                        '${(_message.pattern.duration.inMilliseconds / 1000).toStringAsFixed(1)}S',
              style: AppTypography.eyebrow,
            ),
            const SizedBox(height: 8),
            PatternWaveform(
              pattern: _message.pattern,
              color: AppColors.lab,
              height: 40,
              progress: _playing ? _play.value : null,
            ),
          ],
        ),
      ),
      controls: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: _playing ? AppColors.surfaceHighest : AppColors.lab,
          foregroundColor: _playing ? AppColors.text : AppColors.onAccent,
        ),
        onPressed: _message.isEmpty ? null : (_playing ? _stop : _start),
        icon: Icon(_playing ? Icons.stop_rounded : Icons.play_arrow_rounded),
        label: Text(
          _playing ? 'Stop' : 'Play in Morse',
          style: theme.textTheme.labelLarge,
        ),
      ),
    );
  }
}

class _Letter extends StatelessWidget {
  const _Letter({
    required this.char,
    required this.symbols,
    required this.active,
    required this.done,
  });

  final String char;
  final List<_Symbol> symbols;
  final _Symbol? active;
  final bool Function(_Symbol) done;

  @override
  Widget build(BuildContext context) {
    if (char == ' ') return const SizedBox(width: 18, height: 44);
    final lit = symbols.contains(active);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          char,
          style: AppTypography.mono.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: lit ? AppColors.lab : AppColors.text,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final s in symbols)
              AnimatedContainer(
                duration: const Duration(milliseconds: 60),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: s.dash ? 18 : 7,
                height: 7,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: identical(s, active)
                      ? AppColors.lab
                      : done(s)
                      ? AppColors.lab.withValues(alpha: 0.35)
                      : AppColors.surfaceHighest,
                  boxShadow: identical(s, active)
                      ? [
                          BoxShadow(
                            color: AppColors.lab.withValues(alpha: 0.7),
                            blurRadius: 10,
                          ),
                        ]
                      : null,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
