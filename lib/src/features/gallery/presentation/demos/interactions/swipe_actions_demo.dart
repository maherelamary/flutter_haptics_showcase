import 'package:flutter/material.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_haptics.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_patterns.dart';

/// Swipe right to archive, left to delete — with a threshold you can feel.
class SwipeActionsDemo extends StatefulWidget {
  const SwipeActionsDemo({super.key});

  @override
  State<SwipeActionsDemo> createState() => _SwipeActionsDemoState();
}

class _Mail {
  const _Mail(this.id, this.from, this.subject);

  final int id;
  final String from;
  final String subject;
}

class _SwipeActionsDemoState extends State<SwipeActionsDemo> {
  static const _seed = [
    _Mail(1, 'Lina', 'Haptics spec — final'),
    _Mail(2, 'Omar', 'Lunch tomorrow?'),
    _Mail(3, 'Build bot', 'Release 1.4 is green'),
    _Mail(4, 'Sara', 'The toggle feels too heavy'),
  ];

  final List<_Mail> _mails = [..._seed];
  int? _armedId;
  String _status = 'Swipe right to archive, left to delete.';

  void _onUpdate(_Mail mail, DismissUpdateDetails details) {
    if (details.reached && !details.previousReached) {
      FlutterHaptics.perform(AppHaptics.armed);
      setState(() => _armedId = mail.id);
    } else if (!details.reached && details.previousReached) {
      FlutterHaptics.perform(AppHaptics.disarmed);
      setState(() => _armedId = null);
    }
  }

  void _onDismissed(_Mail mail, int index, DismissDirection direction) {
    setState(() {
      _mails.remove(mail);
      _armedId = null;
    });

    if (direction == DismissDirection.startToEnd) {
      FlutterHaptics.perform(AppHaptics.success);
      setState(() => _status = 'Archived "${mail.subject}".');
      return;
    }

    FlutterHaptics.perform(AppHaptics.press);
    setState(() => _status = 'Deleted "${mail.subject}".');
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Deleted "${mail.subject}"'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => _undo(mail, index),
          ),
        ),
      );
  }

  void _undo(_Mail mail, int index) {
    if (!mounted || _mails.contains(mail)) return;
    FlutterHaptics.play(AppPatterns.rewind);
    setState(() {
      _mails.insert(index.clamp(0, _mails.length), mail);
      _status = 'Restored "${mail.subject}".';
    });
  }

  void _restoreAll() {
    FlutterHaptics.perform(AppHaptics.tap);
    setState(() {
      _mails
        ..clear()
        ..addAll(_seed);
      _status = 'Swipe right to archive, left to delete.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, mail) in _mails.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Dismissible(
                key: ValueKey(mail.id),
                onUpdate: (details) => _onUpdate(mail, details),
                onDismissed: (direction) => _onDismissed(mail, i, direction),
                background: _ActionBackground(
                  icon: Icons.archive_rounded,
                  label: 'Archive',
                  color: AppColors.info,
                  alignment: Alignment.centerLeft,
                  armed: _armedId == mail.id,
                ),
                secondaryBackground: _ActionBackground(
                  icon: Icons.delete_rounded,
                  label: 'Delete',
                  color: AppColors.danger,
                  alignment: Alignment.centerRight,
                  armed: _armedId == mail.id,
                ),
                child: _MailRow(mail: mail),
              ),
            ),
          ),
        if (_mails.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                const Icon(
                  Icons.inbox_rounded,
                  size: 36,
                  color: AppColors.textFaint,
                ),
                const SizedBox(height: 8),
                Text('Inbox zero', style: theme.textTheme.titleMedium),
                TextButton(
                  onPressed: _restoreAll,
                  child: const Text('Restore inbox'),
                ),
              ],
            ),
          ),
        const SizedBox(height: 6),
        Text(
          _status,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _ActionBackground extends StatelessWidget {
  const _ActionBackground({
    required this.icon,
    required this.label,
    required this.color,
    required this.alignment,
    required this.armed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Alignment alignment;
  final bool armed;

  @override
  Widget build(BuildContext context) {
    final foreground = armed ? AppColors.background : color;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      color: armed ? color : color.withValues(alpha: 0.16),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: alignment,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedScale(
            scale: armed ? 1.2 : 0.9,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutBack,
            child: Icon(icon, color: foreground, size: 22),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _MailRow extends StatelessWidget {
  const _MailRow({required this.mail});

  final _Mail mail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.surfaceHighest,
            child: Text(
              mail.from.characters.first,
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: AppColors.text),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mail.from, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  mail.subject,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
