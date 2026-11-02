import 'package:flutter/material.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_haptics.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_patterns.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/safe_animated_switcher.dart';

/// Delete with an undo that feels like the delete running backwards.
class UndoSnackbarDemo extends StatefulWidget {
  const UndoSnackbarDemo({super.key});

  @override
  State<UndoSnackbarDemo> createState() => _UndoSnackbarDemoState();
}

class _UndoSnackbarDemoState extends State<UndoSnackbarDemo> {
  static const _mails = [
    ('Lina', 'Spec review moved to 3pm'),
    ('Build bot', 'Nightly #212 failed'),
    ('Omar', 'Coffee tomorrow?'),
  ];

  final Set<int> _deleted = {};

  void _delete(int index) {
    FlutterHaptics.perform(AppHaptics.press);
    setState(() => _deleted.add(index));
    // The snackbar appearing is silent: the delete already spoke.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Deleted "${_mails[index].$2}"'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => _undo(index),
          ),
        ),
      );
  }

  void _undo(int index) {
    if (!mounted || !_deleted.contains(index)) return;
    FlutterHaptics.play(AppPatterns.rewind);
    setState(() => _deleted.remove(index));
  }

  void _restoreAll() {
    FlutterHaptics.perform(AppHaptics.tap);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(_deleted.clear);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _mails.length; i++)
          SafeAnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => SizeTransition(
              sizeFactor: animation,
              alignment: Alignment.topCenter,
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: _deleted.contains(i)
                ? SizedBox(key: ValueKey('gone-$i'), width: double.infinity)
                : Padding(
                    key: ValueKey('row-$i'),
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _MailRow(
                      from: _mails[i].$1,
                      subject: _mails[i].$2,
                      onDelete: () => _delete(i),
                    ),
                  ),
          ),
        if (_deleted.length == _mails.length)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Text('Inbox zero', style: theme.textTheme.titleMedium),
                TextButton(
                  onPressed: _restoreAll,
                  child: const Text('Restore all'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MailRow extends StatelessWidget {
  const _MailRow({
    required this.from,
    required this.subject,
    required this.onDelete,
  });

  final String from;
  final String subject;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(from, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  subject,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: onDelete,
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
