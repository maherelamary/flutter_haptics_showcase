import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_typography.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_haptics.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_patterns.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/fidelity_simulator.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/haptic_registry.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/haptics_providers.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/tactile_card.dart';
import 'package:flutter_haptics_showcase/src/features/studio/domain/studio_draft.dart';
import 'package:flutter_haptics_showcase/src/features/studio/domain/studio_event.dart';
import 'package:flutter_haptics_showcase/src/features/studio/domain/studio_import.dart';
import 'package:flutter_haptics_showcase/src/features/studio/presentation/providers/studio_provider.dart';
import 'package:flutter_haptics_showcase/src/features/studio/presentation/widgets/event_card.dart';
import 'package:flutter_haptics_showcase/src/features/studio/presentation/widgets/export_sheet.dart';
import 'package:flutter_haptics_showcase/src/features/studio/presentation/widgets/preset_picker.dart';
import 'package:flutter_haptics_showcase/src/features/studio/presentation/widgets/studio_canvas.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Compose a pattern, feel it on this phone and on cheaper ones, and export
/// it as Dart or AHAP.
///
/// The Studio's own chrome stays nearly silent — a tick for the tier, a tap
/// for adding — so the only thing you feel is the thing being designed.
class StudioPage extends ConsumerStatefulWidget {
  const StudioPage({super.key});

  @override
  ConsumerState<StudioPage> createState() => _StudioPageState();
}

class _StudioPageState extends ConsumerState<StudioPage>
    with SingleTickerProviderStateMixin {
  static const _loopGap = Duration(milliseconds: 300);

  late final AnimationController _playhead = AnimationController(vsync: this)
    ..addStatusListener(_onPlayheadStatus);
  late final Map<String, HapticPattern> _presets = HapticRegistry.allPatterns;

  Timer? _loopTimer;
  int? _selectedId;
  SimulatedTier _tier = SimulatedTier.native;
  bool _playing = false;
  int _playingMs = 1;

  // A backgrounded app can be killed before the save debounce fires.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: () => ref.read(studioProvider.notifier).flush(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The tab shell keeps this page alive offstage with its tickers muted.
    // Leaving the tab stops playback instead of looping out of sight.
    if (!TickerMode.valuesOf(context).enabled && _playing) {
      _halt(rebuild: false);
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _halt(rebuild: false);
    _playhead.dispose();
    super.dispose();
  }

  // ─── Playback ──────────────────────────────────────────────────────

  /// The draft as it will be felt on the previewed tier.
  HapticPattern _render(StudioDraft draft) =>
      FidelitySimulator.degrade(draft.toPattern(), _tier);

  /// Plays [pattern] at the previewed tier alone. The app-wide simulation
  /// would otherwise apply on top, and the tier picked here would not be
  /// the one felt.
  void _preview(HapticPattern pattern) => FlutterHaptics.play(
    ref.read(hapticTracerProvider).pinTier(pattern, _tier),
  );

  void _play() {
    _loopTimer?.cancel();
    final pattern = ref.read(studioProvider).toPattern();
    final rendered = FidelitySimulator.degrade(pattern, _tier);
    if (rendered.events.isEmpty) {
      _halt();
      return;
    }
    _preview(pattern);
    _playingMs = math.max(1, rendered.duration.inMilliseconds);
    _playhead
      ..duration = Duration(milliseconds: _playingMs)
      ..forward(from: 0);
    if (!_playing) setState(() => _playing = true);
  }

  void _onPlayheadStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !_playing || !mounted) return;
    if (ref.read(studioProvider).loop) {
      // Each pass rebuilds from the current draft, so edits made while
      // looping are felt on the next pass.
      _loopTimer = Timer(_loopGap, () {
        if (mounted && _playing) _play();
      });
    } else {
      setState(() => _playing = false);
    }
  }

  void _halt({bool rebuild = true}) {
    _loopTimer?.cancel();
    _loopTimer = null;
    if (_playing) FlutterHaptics.stop();
    _playhead
      ..stop()
      ..value = 0;
    if (rebuild && mounted) {
      setState(() => _playing = false);
    } else {
      _playing = false;
    }
  }

  /// Plays one event alone — the instant answer to "how does that feel?".
  void _audition(StudioEvent event) => _preview(StudioDraft.single(event));

  // ─── Editing ───────────────────────────────────────────────────────

  StudioNotifier get _notifier => ref.read(studioProvider.notifier);

  void _add(StudioEventKind kind) {
    FlutterHaptics.perform(AppHaptics.tap);
    final id = _notifier.add(kind);
    setState(() => _selectedId = id);
  }

  void _toggleSelected(int id) =>
      setState(() => _selectedId = _selectedId == id ? null : id);

  void _selectFromCanvas(int id) {
    setState(() => _selectedId = id);
    for (final event in ref.read(studioProvider).events) {
      if (event.id == id) _audition(event);
    }
  }

  void _duplicate(int id) {
    final copy = _notifier.duplicate(id);
    if (copy != null) setState(() => _selectedId = copy);
  }

  void _delete(int id) {
    _notifier.remove(id);
    if (_selectedId == id) setState(() => _selectedId = null);
  }

  void _setTier(SimulatedTier tier) {
    FlutterHaptics.perform(AppHaptics.tick);
    setState(() => _tier = tier);
  }

  void _load(String name, HapticPattern pattern) {
    _halt();
    _notifier.load(name, pattern);
    setState(() => _selectedId = null);
    // Feel what you just loaded.
    _play();
  }

  Future<void> _browsePresets() async {
    final pick = await showPresetSheet(context, _presets);
    if (pick != null && mounted) _load(pick.key, pick.value);
  }

  Future<void> _rename(String current) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initial: current),
    );
    if (name != null && mounted) _notifier.rename(name);
  }

  void _clear() {
    final before = ref.read(studioProvider);
    final notifier = _notifier;
    _halt();
    notifier.clear();
    setState(() => _selectedId = null);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Timeline cleared'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              FlutterHaptics.play(AppPatterns.rewind);
              notifier.restore(before);
            },
          ),
        ),
      );
  }

  Future<void> _importAhap() async {
    final messenger = ScaffoldMessenger.of(context);
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final (:pattern, :error) = StudioImport.ahap(data?.text ?? '');
    if (pattern == null) {
      _reject(messenger, error!);
      return;
    }

    _halt();
    _notifier.load('Imported', pattern);
    setState(() => _selectedId = null);
    FlutterHaptics.perform(AppHaptics.success);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Imported ${pattern.events.length} '
            '${pattern.events.length == 1 ? 'event' : 'events'}, '
            'approximated as Studio events.',
          ),
        ),
      );
  }

  void _reject(ScaffoldMessengerState messenger, String message) {
    FlutterHaptics.perform(AppHaptics.failure);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ─── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(studioProvider);
    final globalTier = ref.watch(hapticsSettingsProvider.select((s) => s.tier));
    final display = _render(draft);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
              sliver: SliverToBoxAdapter(child: _header(draft, theme)),
            ),
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 22, 20, 10),
              sliver: SliverToBoxAdapter(
                child: Text('START FROM', style: AppTypography.eyebrow),
              ),
            ),
            SliverToBoxAdapter(
              child: PresetStrip(
                presets: _presets,
                onPick: _load,
                onBrowse: _browsePresets,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverToBoxAdapter(
                child: TactileCard(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  child: AnimatedBuilder(
                    animation: _playhead,
                    builder: (context, _) => StudioCanvas(
                      pattern: display,
                      spans: draft.spans,
                      selectedId: _selectedId,
                      onSelect: _selectFromCanvas,
                      elapsedMs: _playing ? _playhead.value * _playingMs : null,
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverToBoxAdapter(child: _transport(draft)),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
              sliver: SliverToBoxAdapter(child: _tierPicker(theme, globalTier)),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 26, 8, 4),
              sliver: SliverToBoxAdapter(child: _eventsHeader(draft, theme)),
            ),
            if (draft.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                sliver: SliverToBoxAdapter(child: _emptyState(theme)),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                sliver: SliverReorderableList(
                  itemCount: draft.events.length,
                  onReorderItem: _notifier.move,
                  onReorderStart: (_) =>
                      FlutterHaptics.perform(AppHaptics.lift),
                  onReorderEnd: (_) => FlutterHaptics.perform(AppHaptics.drop),
                  proxyDecorator: _liftedCard,
                  itemBuilder: (context, i) {
                    final event = draft.events[i];
                    return Padding(
                      key: ValueKey(event.id),
                      padding: const EdgeInsets.only(bottom: 10),
                      child: EventCard(
                        event: event,
                        index: i,
                        selected: event.id == _selectedId,
                        onTap: () => _toggleSelected(event.id),
                        onChanged: _notifier.update,
                        onAudition: _audition,
                        onDuplicate: () => _duplicate(event.id),
                        onDelete: () => _delete(event.id),
                      ),
                    );
                  },
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  Widget _header(StudioDraft draft, ThemeData theme) {
    final pattern = draft.toPattern();
    final count = draft.events.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STUDIO',
          style: AppTypography.eyebrow.copyWith(color: AppColors.studio),
        ),
        const SizedBox(height: 8),
        Text('Pattern Studio', style: theme.textTheme.displaySmall),
        const SizedBox(height: 10),
        Text(
          'Compose taps and rumbles, feel them here and on cheaper phones, '
          'then take the code with you.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _rename(draft.name),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            draft.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.edit_rounded,
                          size: 16,
                          color: AppColors.textFaint,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$count ${count == 1 ? 'event' : 'events'} · '
                      '${pattern.duration.inMilliseconds} ms',
                      style: AppTypography.mono.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: 'Paste AHAP from clipboard',
              onPressed: _importAhap,
              icon: const Icon(Icons.content_paste_rounded),
            ),
            IconButton(
              tooltip: 'Clear timeline',
              onPressed: draft.isEmpty ? null : _clear,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
          ],
        ),
      ],
    );
  }

  Widget _transport(StudioDraft draft) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.studio,
              foregroundColor: AppColors.onAccent,
            ),
            onPressed: draft.isEmpty
                ? null
                : (_playing ? () => _halt() : _play),
            icon: Icon(
              _playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
            ),
            label: Text(_playing ? 'Stop' : 'Play'),
          ),
        ),
        const SizedBox(width: 10),
        _ToolButton(
          icon: Icons.repeat_rounded,
          tooltip: draft.loop ? 'Loop on' : 'Loop off',
          selected: draft.loop,
          // Silent on purpose: the loop toggle should not compete with the
          // pattern playing underneath it.
          onTap: () => _notifier.setLoop(!draft.loop),
        ),
        const SizedBox(width: 10),
        _ToolButton(
          icon: Icons.ios_share_rounded,
          tooltip: 'Export as Dart or AHAP',
          onTap: draft.isEmpty
              ? null
              : () => showStudioExportSheet(context, draft),
        ),
      ],
    );
  }

  Widget _tierPicker(ThemeData theme, SimulatedTier globalTier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('FEEL IT ON', style: AppTypography.eyebrow),
        const SizedBox(height: 10),
        SegmentedButton<SimulatedTier>(
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
            selectedBackgroundColor: AppColors.studio,
            selectedForegroundColor: AppColors.onAccent,
          ),
          segments: [
            for (final tier in SimulatedTier.values)
              ButtonSegment(value: tier, label: Text(tier.label)),
          ],
          selected: {_tier},
          onSelectionChanged: (selection) => _setTier(selection.first),
        ),
        const SizedBox(height: 10),
        Text(_tier.explanation, style: theme.textTheme.bodySmall),
        if (globalTier != SimulatedTier.native) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.studio.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.studio.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: AppColors.studio,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'App-wide simulation (${globalTier.label}) is on in '
                    'Settings. Studio previews ignore it and play at the '
                    'tier picked here.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _eventsHeader(StudioDraft draft, ThemeData theme) {
    final addStyle = TextButton.styleFrom(foregroundColor: AppColors.studio);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('EVENTS', style: AppTypography.eyebrow),
            const SizedBox(width: 8),
            Text(
              '${draft.events.length}',
              style: AppTypography.eyebrow.copyWith(color: AppColors.textFaint),
            ),
            const Spacer(),
            TextButton.icon(
              style: addStyle,
              onPressed: () => _add(StudioEventKind.tap),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Tap'),
            ),
            TextButton.icon(
              style: addStyle,
              onPressed: () => _add(StudioEventKind.rumble),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Rumble'),
            ),
          ],
        ),
        if (!draft.isEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Text(
              'Drag the handle to reorder · tap an event to edit · release a '
              'slider to feel it.',
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  Widget _emptyState(ThemeData theme) {
    return TactileCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(
            Icons.graphic_eq_rounded,
            size: 36,
            color: AppColors.studio,
          ),
          const SizedBox(height: 12),
          Text('An empty timeline', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Add a tap or a rumble, or start from one of the library '
            'patterns.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.studio,
              foregroundColor: AppColors.onAccent,
            ),
            onPressed: _browsePresets,
            icon: const Icon(Icons.grid_view_rounded),
            label: const Text('Start from a preset'),
          ),
        ],
      ),
    );
  }

  Widget _liftedCard(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final t = Curves.easeOut.transform(animation.value);
        return Transform.scale(
          scale: 1 + 0.02 * t,
          child: Material(
            color: Colors.transparent,
            elevation: 10 * t,
            shadowColor: AppColors.studio.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(18),
            child: child,
          ),
        );
      },
    );
  }
}

/// A square icon button for the transport row; [selected] shows a toggle on.
class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color: selected ? AppColors.studio : AppColors.outlineStrong,
      ),
    );
    final color = onTap == null
        ? AppColors.textFaint
        : (selected ? AppColors.studio : AppColors.text);

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        toggled: selected,
        child: Material(
          color: selected
              ? AppColors.studio.withValues(alpha: 0.16)
              : AppColors.surfaceRaised,
          shape: shape,
          child: InkWell(
            customBorder: shape,
            onTap: onTap,
            child: SizedBox(
              width: 52,
              height: 52,
              child: Icon(icon, color: color),
            ),
          ),
        ),
      ),
    );
  }
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Name this pattern'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 32,
        onSubmitted: (_) => _submit(),
        decoration: const InputDecoration(
          hintText: 'unlock, payment, heartbeat…',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
