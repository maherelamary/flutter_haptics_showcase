import 'package:flutter/material.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_typography.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_haptics.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/code_block.dart';
import 'package:flutter_haptics_showcase/src/features/studio/domain/studio_codegen.dart';
import 'package:flutter_haptics_showcase/src/features/studio/domain/studio_draft.dart';

/// Shows the draft as Dart and as AHAP, ready to copy into a client app.
Future<void> showStudioExportSheet(BuildContext context, StudioDraft draft) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) =>
          _ExportSheet(draft: draft, controller: controller),
    ),
  );
}

enum _Format { dart, ahap }

class _ExportSheet extends StatefulWidget {
  const _ExportSheet({required this.draft, required this.controller});

  final StudioDraft draft;
  final ScrollController controller;

  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  _Format _format = _Format.dart;
  late final String _dart = StudioCodegen.dart(widget.draft);
  late final AhapExport _ahap = StudioCodegen.ahap(widget.draft);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ahapError = _ahap.error;

    return ListView(
      controller: widget.controller,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Text(
          'EXPORT',
          style: AppTypography.eyebrow.copyWith(color: AppColors.studio),
        ),
        const SizedBox(height: 6),
        Text(widget.draft.name, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 16),
        SegmentedButton<_Format>(
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
            selectedBackgroundColor: AppColors.studio,
            selectedForegroundColor: AppColors.onAccent,
          ),
          segments: const [
            ButtonSegment(value: _Format.dart, label: Text('Dart')),
            ButtonSegment(value: _Format.ahap, label: Text('AHAP')),
          ],
          selected: {_format},
          onSelectionChanged: (selection) {
            FlutterHaptics.perform(AppHaptics.tick);
            setState(() => _format = selection.first);
          },
        ),
        const SizedBox(height: 16),
        if (_format == _Format.dart) ...[
          CodeBlock(_dart),
          const SizedBox(height: 12),
          Text(
            'A HapticPatternBuilder chain that rebuilds this pattern exactly. '
            'Drop it into your app\'s patterns file and play it with '
            'FlutterHaptics.play — or pair it with native constants in a '
            'HapticIntent.',
            style: theme.textTheme.bodySmall,
          ),
        ] else if (ahapError != null)
          _Notice(
            color: AppColors.danger,
            text: 'This pattern cannot be written as AHAP: $ahapError',
          )
        else ...[
          CodeBlock(_ahap.json ?? '', label: 'json'),
          const SizedBox(height: 12),
          Text(
            'Apple\'s Haptic and Audio Pattern format. Core Haptics loads it '
            'directly, haptic design tools open it, and Ahap.loadAsset plays '
            'it through the whole Android ladder too. Core Haptics reads at '
            'most ${Ahap.maxControlPoints} control points per curve.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: AppColors.text),
      ),
    );
  }
}
