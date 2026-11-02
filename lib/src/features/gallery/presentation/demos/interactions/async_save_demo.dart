import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_haptics.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/safe_animated_switcher.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/shaker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class _SaveError implements Exception {
  const _SaveError(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The domain side: saves, fails, and knows nothing about haptics.
class _SaveNotifier extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> save({required bool fail}) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (fail) throw const _SaveError('Server rejected the change');
    });
    if (!ref.mounted) return;
    state = result;
  }
}

final _saveProvider = AsyncNotifierProvider.autoDispose<_SaveNotifier, void>(
  _SaveNotifier.new,
);

/// The Riverpod recipe: the widget decides what each outcome feels like.
class AsyncSaveDemo extends ConsumerStatefulWidget {
  const AsyncSaveDemo({super.key});

  @override
  ConsumerState<AsyncSaveDemo> createState() => _AsyncSaveDemoState();
}

class _AsyncSaveDemoState extends ConsumerState<AsyncSaveDemo> {
  final ShakeController _shake = ShakeController();
  bool _fail = false;
  bool _saved = false;

  void _save() {
    FlutterHaptics.perform(AppHaptics.press);
    ref.read(_saveProvider.notifier).save(fail: _fail);
  }

  void _toggleFail(bool on) {
    FlutterHaptics.perform(on ? AppHaptics.switchOn : AppHaptics.switchOff);
    setState(() => _fail = on);
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Presentation owns the feel: react to the loading → done transition.
    ref.listen(_saveProvider, (previous, next) {
      if (previous == null || !previous.isLoading || next.isLoading) return;
      if (next.hasError) {
        FlutterHaptics.perform(AppHaptics.failure);
        _shake.shake();
      } else {
        FlutterHaptics.perform(AppHaptics.success);
        setState(() => _saved = true);
      }
    });

    final save = ref.watch(_saveProvider);
    final theme = Theme.of(context);

    final (String label, Color color, IconData icon) status;
    if (save.isLoading) {
      status = ('Saving…', AppColors.textMuted, Icons.sync_rounded);
    } else if (save.hasError) {
      status = ('${save.error}', AppColors.danger, Icons.error_outline_rounded);
    } else if (_saved) {
      status = ('Saved', AppColors.success, Icons.check_circle_rounded);
    } else {
      status = ('Unsaved changes', AppColors.textMuted, Icons.edit_note_rounded);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Shaker(
          controller: _shake,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: save.hasError && !save.isLoading
                    ? AppColors.danger.withValues(alpha: 0.6)
                    : AppColors.outline,
              ),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.surfaceHighest,
                  child: Icon(Icons.person_rounded, color: AppColors.text),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Profile', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 4),
                      SafeAnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: Row(
                          key: ValueKey(status.$1),
                          children: [
                            Icon(status.$3, size: 14, color: status.$2),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                status.$1,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: status.$2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                'Simulate failure',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Switch(value: _fail, onChanged: _toggleFail),
          ],
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: save.isLoading ? null : _save,
          child: save.isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.textMuted,
                  ),
                )
              : const Text('Save changes'),
        ),
      ],
    );
  }
}
