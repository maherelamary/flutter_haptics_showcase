import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_typography.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_haptics.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/safe_animated_switcher.dart';

/// Hold a card, slide to an action, release — one continuous gesture.
class LongPressMenuDemo extends StatefulWidget {
  const LongPressMenuDemo({super.key});

  @override
  State<LongPressMenuDemo> createState() => _LongPressMenuDemoState();
}

class _MenuAction {
  const _MenuAction(this.label, this.done, this.icon, {this.destructive = false});

  final String label;
  final String done;
  final IconData icon;
  final bool destructive;
}

class _LongPressMenuDemoState extends State<LongPressMenuDemo> {
  static const _actions = [
    _MenuAction('Copy', 'Copied', Icons.copy_rounded),
    _MenuAction('Share', 'Shared', Icons.ios_share_rounded),
    _MenuAction('Pin', 'Pinned', Icons.push_pin_rounded),
    _MenuAction(
      'Delete',
      'Deleted',
      Icons.delete_outline_rounded,
      destructive: true,
    ),
  ];
  static const _itemHeight = 48.0;

  final GlobalKey _menuKey = GlobalKey();
  bool _pressing = false;
  bool _open = false;
  bool _slid = false;
  int? _hover;
  String? _result;

  void _onDown(LongPressDownDetails _) => setState(() => _pressing = true);

  void _onCancel() => setState(() => _pressing = false);

  void _onStart(LongPressStartDetails _) {
    // The moment the press becomes a menu.
    FlutterHaptics.perform(AppHaptics.longPress);
    setState(() {
      _pressing = false;
      _open = true;
      _slid = false;
      _hover = null;
      _result = null;
    });
  }

  void _onMove(LongPressMoveUpdateDetails details) {
    if (details.offsetFromOrigin.distance > 12) _slid = true;
    final index = _indexAt(details.globalPosition);
    if (index == _hover) return;
    setState(() => _hover = index);
    if (index != null) FlutterHaptics.perform(AppHaptics.tick);
  }

  void _onEnd(LongPressEndDetails details) {
    final index = _indexAt(details.globalPosition);
    if (index != null) {
      _select(index);
    } else if (_slid) {
      // Released away from the menu: cancelling is not an event.
      _close();
    }
    // Released without sliding: the menu stays open for a tap.
  }

  void _onTapCard() {
    if (_open) _close();
  }

  void _select(int index) {
    FlutterHaptics.perform(AppHaptics.tap);
    setState(() {
      _result = _actions[index].done;
      _open = false;
      _hover = null;
    });
  }

  void _close() => setState(() {
        _open = false;
        _hover = null;
      });

  int? _indexAt(Offset global) {
    final box = _menuKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    final local = box.globalToLocal(global);
    if (local.dx < 0 ||
        local.dy < 0 ||
        local.dx > box.size.width ||
        local.dy > box.size.height) {
      return null;
    }
    final index = (local.dy / _itemHeight).floor();
    return index >= 0 && index < _actions.length ? index : null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scale = _pressing ? 0.97 : (_open ? 1.03 : 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RawGestureDetector(
          gestures: {
            LongPressGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
              () => LongPressGestureRecognizer(
                duration: const Duration(milliseconds: 450),
              ),
              (recognizer) => recognizer
                ..onLongPressDown = _onDown
                ..onLongPressCancel = _onCancel
                ..onLongPressStart = _onStart
                ..onLongPressMoveUpdate = _onMove
                ..onLongPressEnd = _onEnd,
            ),
            TapGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
              TapGestureRecognizer.new,
              (recognizer) => recognizer..onTap = _onTapCard,
            ),
          },
          child: AnimatedScale(
            scale: scale,
            duration: Duration(milliseconds: _pressing ? 450 : 200),
            curve: _pressing ? Curves.easeIn : Curves.easeOutBack,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _open ? AppColors.surfaceHighest : AppColors.surfaceRaised,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _open
                      ? AppColors.accent.withValues(alpha: 0.5)
                      : AppColors.outline,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: _open ? 0.5 : 0),
                    blurRadius: _open ? 24 : 0,
                    offset: Offset(0, _open ? 10 : 0),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.surface,
                    child: Text('L', style: TextStyle(color: AppColors.text)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('Lina', style: theme.textTheme.titleSmall),
                            const Spacer(),
                            Text(
                              '09:41',
                              style: AppTypography.mono.copyWith(
                                fontSize: 11,
                                color: AppColors.textFaint,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Can you check the switch feel on Android 14? '
                          'It might be too heavy.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        IgnorePointer(
          ignoring: !_open,
          child: AnimatedOpacity(
            opacity: _open ? 1 : 0,
            duration: const Duration(milliseconds: 160),
            child: AnimatedScale(
              scale: _open ? 1 : 0.9,
              alignment: Alignment.topCenter,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: _menu(theme),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SafeAnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _result == null
              ? Text(
                  'Hold the card, slide to an action, release.',
                  key: const ValueKey('hint'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                )
              : Row(
                  key: ValueKey(_result),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _result!,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(color: AppColors.accent),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _menu(ThemeData theme) {
    return Container(
      key: _menuKey,
      width: 220,
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _actions.length; i++)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _select(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 90),
                  height: _itemHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  color: _hover == i
                      ? AppColors.surfaceHighest
                      : Colors.transparent,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _actions[i].label,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: _actions[i].destructive
                                ? AppColors.danger
                                : AppColors.text,
                            fontWeight:
                                _hover == i ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                      Icon(
                        _actions[i].icon,
                        size: 18,
                        color: _actions[i].destructive
                            ? AppColors.danger
                            : AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
