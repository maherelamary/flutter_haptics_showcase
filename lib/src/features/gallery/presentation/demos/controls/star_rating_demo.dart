import 'package:flutter/material.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_typography.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_patterns.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/haptic_pacer.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/haptic_echo.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/pattern_waveform.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/safe_animated_switcher.dart';

/// Five stars that climb in strength, so the rating can be felt.
class StarRatingDemo extends StatefulWidget {
  const StarRatingDemo({super.key});

  /// One tap per star, stronger and crisper as the rating rises.
  static HapticPattern patternFor(int stars) => HapticPattern([
    TransientEvent(
      intensity: 0.35 + 0.15 * (stars - 1),
      sharpness: 0.3 + 0.15 * (stars - 1),
    ),
  ]);

  @override
  State<StarRatingDemo> createState() => _StarRatingDemoState();
}

class _StarRatingDemoState extends State<StarRatingDemo> {
  static const _starWidth = 48.0;
  static const _labels = ['Awful', 'Meh', 'Okay', 'Good', 'Loved it'];
  static const _gold = AppColors.warning;

  // Five prepared handles: a drag across the row replays them quickly.
  final List<HapticHandle> _steps = [
    for (var n = 1; n <= 5; n++)
      FlutterHaptics.register(StarRatingDemo.patternFor(n)),
  ];

  // Shared across the handles above. Each handle paces only itself, so
  // without this, switching between them could still fire faster than
  // the actuator can separate.
  final HapticPacer _pacer = HapticPacer();

  int _rating = 0;
  int _sparkle = 0;

  /// The star whose tick the pacer dropped, if the drag has not moved on.
  int? _pacedOut;
  HapticPattern _last = HapticPattern.empty;
  String _lastName = 'tap or drag across the stars';

  int _starAt(double dx) => (dx / _starWidth).floor().clamp(0, 4) + 1;

  void _tap(int stars) {
    if (stars == 5) {
      _celebrate();
      return;
    }
    final pattern = StarRatingDemo.patternFor(stars);
    FlutterHaptics.play(pattern);
    setState(() {
      _rating = stars;
      _last = pattern;
      _lastName = 'play(star $stars)';
    });
  }

  void _celebrate() {
    FlutterHaptics.play(AppPatterns.pop);
    setState(() {
      _rating = 5;
      _sparkle++;
      _last = AppPatterns.pop;
      _lastName = 'play(pop)';
    });
  }

  void _drag(double dx) {
    final stars = _starAt(dx);
    if (stars == _rating) return;
    if (_pacer.ready()) {
      _steps[stars - 1].play();
      _pacedOut = null;
    } else {
      _pacedOut = stars;
    }
    setState(() {
      _rating = stars;
      _last = _steps[stars - 1].pattern;
      _lastName = 'handle(star $stars)';
    });
  }

  void _dragEnd() {
    // The drag already spoke star by star; only a five-star commit earns
    // the extra pop.
    if (_rating == 5) {
      _celebrate();
    } else if (_pacedOut == _rating) {
      // The pacer swallowed the star the drag stopped on; the rating the
      // finger lifts on is the one that must be felt.
      _steps[_rating - 1].play();
    }
    _pacedOut = null;
  }

  @override
  void dispose() {
    for (final step in _steps) {
      step.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('How was your order?', style: theme.textTheme.titleMedium),
        const SizedBox(height: 14),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => _tap(_starAt(d.localPosition.dx)),
          onHorizontalDragStart: (d) {
            _pacer.reset();
            _drag(d.localPosition.dx);
          },
          onHorizontalDragUpdate: (d) => _drag(d.localPosition.dx),
          onHorizontalDragEnd: (_) => _dragEnd(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var n = 1; n <= 5; n++)
                SizedBox(
                  width: _starWidth,
                  height: _starWidth,
                  child: Center(
                    child: _Star(
                      lit: n <= _rating,
                      sparkle: n == 5 ? _sparkle : 0,
                      color: _gold,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SafeAnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: Text(
            _rating == 0 ? ' ' : _labels[_rating - 1],
            key: ValueKey(_rating),
            style: theme.textTheme.titleSmall?.copyWith(
              color: _rating == 0 ? AppColors.textFaint : _gold,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Text(
                _lastName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.mono.copyWith(
                  fontSize: 10.5,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        PatternWaveform(
          pattern: _last,
          color: _gold,
          height: 40,
          minDuration: const Duration(milliseconds: 120),
        ),
      ],
    );
  }
}

class _Star extends StatelessWidget {
  const _Star({required this.lit, required this.sparkle, required this.color});

  final bool lit;
  final int sparkle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return HapticEcho(
      trigger: sparkle,
      color: color,
      spread: 2.4,
      child: AnimatedScale(
        scale: lit ? 1.12 : 1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        child: Icon(
          lit ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 38,
          color: lit ? color : AppColors.outlineStrong,
        ),
      ),
    );
  }
}
