import 'package:flutter/material.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_typography.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_haptics.dart';

/// A text limit you feel once, not on every extra keystroke.
class CharacterLimitDemo extends StatefulWidget {
  const CharacterLimitDemo({super.key});

  @override
  State<CharacterLimitDemo> createState() => _CharacterLimitDemoState();
}

class _CharacterLimitDemoState extends State<CharacterLimitDemo> {
  static const _max = 40;
  static const _warnAt = 35;

  final TextEditingController _controller = TextEditingController();
  int _length = 0;
  bool _atLimit = false;
  int _hits = 0;

  void _onChanged(String text) {
    final length = text.characters.length;
    if (length >= _max && !_atLimit) {
      // Feel the wall once. Further keystrokes are blocked by the field and
      // stay silent until there is room again.
      _atLimit = true;
      _hits++;
      FlutterHaptics.perform(AppHaptics.limit);
    } else if (length < _max) {
      _atLimit = false;
    }
    setState(() => _length = length);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _length >= _max
        ? AppColors.danger
        : (_length >= _warnAt ? AppColors.warning : AppColors.textMuted);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          maxLength: _max,
          minLines: 2,
          maxLines: 3,
          onChanged: _onChanged,
          decoration: const InputDecoration(
            hintText: 'What are you working on?',
            counterText: '',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: _length / _max,
                  minHeight: 6,
                  color: _length >= _warnAt ? color : AppColors.accent,
                  backgroundColor: AppColors.surfaceHighest,
                ),
              ),
            ),
            const SizedBox(width: 12),
            TweenAnimationBuilder<double>(
              key: ValueKey(_hits),
              tween: Tween<double>(begin: _hits == 0 ? 1 : 1.4, end: 1),
              duration: const Duration(milliseconds: 340),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Text(
                '$_length / $_max',
                style: AppTypography.mono.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Type past 40. You feel the wall once — the amber counter at 35 '
          'does the warning.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
