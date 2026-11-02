import 'package:flutter/material.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_typography.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_haptics.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/safe_animated_switcher.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/tactile_card.dart';

/// Success, warning and error — three outcomes you can tell apart blind.
class NotificationTrioDemo extends StatefulWidget {
  const NotificationTrioDemo({super.key});

  @override
  State<NotificationTrioDemo> createState() => _NotificationTrioDemoState();
}

enum _Kind { success, warning, error }

class _NotificationTrioDemoState extends State<NotificationTrioDemo> {
  _Kind? _kind;
  int _count = 0;

  void _fire(_Kind kind) {
    switch (kind) {
      case _Kind.success:
        FlutterHaptics.perform(AppHaptics.success);
      case _Kind.warning:
        // Native on iOS; Android names no warning, so its arm plays the
        // pattern by choice.
        FlutterHaptics.perform(AppHaptics.caution);
      case _Kind.error:
        FlutterHaptics.perform(AppHaptics.failure);
    }
    setState(() {
      _kind = kind;
      _count++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final kind = _kind;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 84,
          child: SafeAnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -0.3),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: kind == null
                ? const _Placeholder(key: ValueKey('empty'))
                : _Banner(key: ValueKey(_count), kind: kind),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            for (final k in _Kind.values) ...[
              if (k != _Kind.success) const SizedBox(width: 8),
              Expanded(
                child: _TrioButton(kind: k, onTap: () => _fire(k)),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

(Color, IconData, String, String, String) _styleOf(_Kind kind) =>
    switch (kind) {
      _Kind.success => (
          AppColors.success,
          Icons.check_circle_rounded,
          'Success',
          'Payment sent',
          'perform(AppHaptics.success)',
        ),
      _Kind.warning => (
          AppColors.warning,
          Icons.warning_amber_rounded,
          'Warning',
          'Storage almost full',
          'perform(AppHaptics.caution)',
        ),
      _Kind.error => (
          AppColors.danger,
          Icons.error_rounded,
          'Error',
          'Card declined',
          'perform(AppHaptics.failure)',
        ),
    };

class _TrioButton extends StatelessWidget {
  const _TrioButton({required this.kind, required this.onTap});

  final _Kind kind;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (color, icon, label, _, _) = _styleOf(kind);
    return PressableScale(
      onTap: onTap,
      pressedScale: 0.94,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({super.key, required this.kind});

  final _Kind kind;

  @override
  Widget build(BuildContext context) {
    final (color, icon, _, title, code) = _styleOf(kind);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 3),
                Text(
                  code,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.mono.copyWith(
                    fontSize: 11,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
      ),
      child: Text(
        'Tap an outcome below',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
