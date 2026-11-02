import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_typography.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/fidelity_simulator.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/haptic_registry.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/haptic_tracer.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/haptics_providers.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/pattern_waveform.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A pill at the top of the screen that shows every haptic as it plays:
/// which route it took and, for patterns, what the waveform looked like.
///
/// Haptics are invisible in a screen recording and silent on a simulator;
/// the island makes a demo legible to everyone watching, not just the
/// person holding the phone.
class HapticIsland extends ConsumerStatefulWidget {
  const HapticIsland({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<HapticIsland> createState() => _HapticIslandState();
}

class _HapticIslandState extends ConsumerState<HapticIsland>
    with SingleTickerProviderStateMixin {
  late final AnimationController _presence = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    reverseDuration: const Duration(milliseconds: 260),
  );
  // Built once: a CurvedAnimation registers a listener on its parent, so
  // creating one per build would leak a listener per haptic.
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _presence,
    curve: Curves.easeOutBack,
    reverseCurve: Curves.easeIn,
  );
  late final Animation<double> _scale =
      Tween<double>(begin: 0.86, end: 1).animate(_curve);
  StreamSubscription<HapticTrace>? _subscription;
  Timer? _hide;
  _IslandContent? _content;

  @override
  void initState() {
    super.initState();
    _subscription = ref.read(hapticTracerProvider).traces.listen(_onTrace);
  }

  void _onTrace(HapticTrace trace) {
    if (!mounted) return;

    // perform() asks for the native constant first and recovers with its
    // pattern when that is declined. The tracer marks the pattern with the
    // declined request, so the two show as one event.
    setState(
      () => _content = _IslandContent.from(
        trace,
        recoveredFrom: trace.recoveredFrom,
      ),
    );

    _presence.forward();
    _hide?.cancel();
    _hide = Timer(const Duration(milliseconds: 1700), () {
      if (mounted) _presence.reverse();
    });
  }

  @override
  void dispose() {
    _hide?.cancel();
    _subscription?.cancel();
    _curve.dispose();
    _presence.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final show = ref.watch(
      hapticsSettingsProvider.select((s) => s.showIsland),
    );
    final content = _content;
    final top = MediaQuery.paddingOf(context).top;

    return Stack(
      children: [
        widget.child,
        if (show && content != null)
          Positioned(
            top: top + 4,
            left: 16,
            right: 16,
            child: IgnorePointer(
              child: Center(
                child: FadeTransition(
                  opacity: _presence,
                  child: ScaleTransition(
                    scale: _scale,
                    child: _IslandPill(content: content),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _IslandContent {
  const _IslandContent({
    required this.tag,
    required this.title,
    required this.color,
    this.detail,
    this.trace,
  });

  factory _IslandContent.from(HapticTrace trace, {HapticTrace? recoveredFrom}) {
    final pattern = trace.pattern;
    if (recoveredFrom != null && pattern != null) {
      return _IslandContent(
        tag: 'RECOVERED',
        title: '${recoveredFrom.system?.name ?? 'system'} → ${HapticRegistry.labelOf(pattern)}',
        detail: recoveredFrom.reason,
        color: AppColors.pattern,
        trace: trace,
      );
    }
    if (!trace.played) {
      return _IslandContent(
        tag: 'SILENT',
        title: trace.system?.name ??
            (pattern == null ? 'nothing' : HapticRegistry.labelOf(pattern)),
        detail: trace.reason,
        color: AppColors.silent,
        trace: trace,
      );
    }
    return switch (trace.kind) {
      HapticTraceKind.system => _IslandContent(
          tag: 'SYSTEM',
          title: trace.system?.name ?? 'constant',
          color: AppColors.system,
          trace: trace,
        ),
      HapticTraceKind.pattern => _IslandContent(
          tag: 'PATTERN',
          title: pattern == null ? 'pattern' : HapticRegistry.labelOf(pattern),
          color: AppColors.pattern,
          trace: trace,
        ),
      HapticTraceKind.replay => _IslandContent(
          tag: 'HANDLE',
          title: pattern == null ? 'prepared' : HapticRegistry.labelOf(pattern),
          color: AppColors.pattern,
          trace: trace,
        ),
    };
  }

  final String tag;
  final String title;
  final String? detail;
  final Color color;
  final HapticTrace? trace;
}

class _IslandPill extends StatelessWidget {
  const _IslandPill({required this.content});

  final _IslandContent content;

  @override
  Widget build(BuildContext context) {
    final pattern = content.trace?.pattern;
    final tier = content.trace?.tier ?? SimulatedTier.native;
    return Material(
      color: Colors.black,
      shape: StadiumBorder(
        side: BorderSide(color: content.color.withValues(alpha: 0.35)),
      ),
      elevation: 12,
      shadowColor: content.color.withValues(alpha: 0.4),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360, minHeight: 36),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 7, 14, 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: content.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: content.color.withValues(alpha: 0.7),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                content.tag,
                style: AppTypography.eyebrow.copyWith(
                  color: content.color,
                  fontSize: 9.5,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      content.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.mono.copyWith(
                        fontSize: 12,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (content.detail != null && content.detail!.isNotEmpty)
                      Text(
                        content.detail!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.mono.copyWith(
                          fontSize: 10,
                          height: 1.2,
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              if (pattern != null && pattern.events.isNotEmpty) ...[
                const SizedBox(width: 10),
                SizedBox(
                  width: 64,
                  child: PatternWaveform(
                    pattern: pattern,
                    color: content.color,
                    height: 18,
                    showBaseline: false,
                  ),
                ),
              ],
              if (tier != SimulatedTier.native) ...[
                const SizedBox(width: 8),
                Text(
                  'SIM·${tier.name.toUpperCase()}',
                  style: AppTypography.eyebrow.copyWith(
                    fontSize: 8.5,
                    color: AppColors.warning,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
