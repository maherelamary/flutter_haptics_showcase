import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_typography.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_patterns.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/haptic_echo.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/safe_animated_switcher.dart';
import 'package:flutter_haptics_showcase/src/features/gallery/presentation/demos/controls/route_readout.dart';

/// A post with a heart: liking pops, unliking barely whispers.
class LikeButtonDemo extends StatefulWidget {
  const LikeButtonDemo({super.key});

  @override
  State<LikeButtonDemo> createState() => _LikeButtonDemoState();
}

class _LikeButtonDemoState extends State<LikeButtonDemo>
    with TickerProviderStateMixin {
  static const _heart = Color(0xFFFF4D6D);

  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  );
  late final AnimationController _bigHeart = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  bool _liked = false;
  int _likes = 128;
  int _echo = 0;
  String _call = 'tap the heart, or double-tap the photo';
  HapticRoute? _route;

  Future<void> _setLiked(bool liked) async {
    setState(() {
      _liked = liked;
      _likes += liked ? 1 : -1;
      if (liked) _echo++;
      _call = liked ? 'play(pop)' : 'play(unpop)';
      _route = null;
    });
    if (liked) _burst.forward(from: 0);
    final route = await FlutterHaptics.play(
      liked ? AppPatterns.pop : AppPatterns.unpop,
    );
    if (mounted) setState(() => _route = route);
  }

  Future<void> _onDoubleTap() async {
    _bigHeart.forward(from: 0);
    if (!_liked) {
      await _setLiked(true);
      return;
    }
    // Already liked: the gesture still deserves its pop. Reaffirming is
    // never an error, and the big heart needs something to land with.
    _burst.forward(from: 0);
    setState(() {
      _echo++;
      _call = 'play(pop)';
    });
    final route = await FlutterHaptics.play(AppPatterns.pop);
    if (mounted) setState(() => _route = route);
  }

  @override
  void dispose() {
    _burst.dispose();
    _bigHeart.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF7AA7FF), Color(0xFFC792FF)],
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                'M',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.onAccent,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'maya shared a photo',
                style: theme.textTheme.titleSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onDoubleTap: _onDoubleTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 150,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF2B1E3D),
                          Color(0xFF4A2340),
                          Color(0xFF1B2B3D),
                        ],
                      ),
                    ),
                  ),
                  const Align(
                    alignment: Alignment(0.6, -0.4),
                    child: Icon(
                      Icons.wb_sunny_rounded,
                      size: 44,
                      color: Color(0x55FFB547),
                    ),
                  ),
                  Center(
                    child: AnimatedBuilder(
                      animation: _bigHeart,
                      builder: (context, _) {
                        final t = _bigHeart.value;
                        if (_bigHeart.isDismissed || t >= 1) {
                          return const SizedBox();
                        }
                        final scale = t < 0.3
                            ? Curves.easeOutBack.transform(t / 0.3)
                            : 1.0;
                        final opacity = t < 0.6 ? 1.0 : (1 - (t - 0.6) / 0.4);
                        return Opacity(
                          opacity: opacity.clamp(0.0, 1.0),
                          child: Transform.scale(
                            scale: scale,
                            child: const Icon(
                              Icons.favorite_rounded,
                              size: 84,
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            HapticEcho(
              trigger: _echo,
              color: _heart,
              spread: 2.2,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _setLiked(!_liked),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: AnimatedBuilder(
                    animation: _burst,
                    builder: (context, child) {
                      final t = _burst.value;
                      final scale = 1 + 0.35 * math.sin(math.pi * t);
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: SafeAnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      child: Icon(
                        _liked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        key: ValueKey(_liked),
                        size: 28,
                        color: _liked ? _heart : AppColors.text,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            SafeAnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, animation) => SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.4),
                  end: Offset.zero,
                ).animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: Text(
                '$_likes',
                key: ValueKey(_likes),
                style: AppTypography.mono.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Text('likes', style: theme.textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 4),
        RouteReadout(call: _call, route: _route),
      ],
    );
  }
}
