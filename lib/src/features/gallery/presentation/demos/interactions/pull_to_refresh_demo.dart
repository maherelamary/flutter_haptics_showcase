import 'package:flutter/material.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_typography.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_haptics.dart';

/// A pull-to-refresh you can feel arm, disarm and land.
class PullToRefreshDemo extends StatefulWidget {
  const PullToRefreshDemo({super.key});

  @override
  State<PullToRefreshDemo> createState() => _PullToRefreshDemoState();
}

class _PullToRefreshDemoState extends State<PullToRefreshDemo> {
  static const _threshold = 80.0;
  static const _incoming = [
    'Haptics audit — checkout',
    'Android 16 envelope notes',
    'Release 1.5 checklist',
    'Design crit: toggles',
  ];

  final List<String> _items = [
    'Weekly metrics',
    'Onboarding copy v2',
    'Release 1.4 retro',
    'Icon refresh',
    'Accessibility pass',
  ];

  double _pull = 0;
  bool _dragging = false;
  bool _armed = false;
  bool _refreshing = false;
  int _fetched = 0;

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0) return false;
    final overscroll =
        (n.metrics.minScrollExtent - n.metrics.pixels).clamp(0.0, 160.0);

    if (n is ScrollStartNotification) {
      _dragging = n.dragDetails != null;
    } else if (n is ScrollUpdateNotification &&
        n.dragDetails == null &&
        _dragging) {
      // The finger lifted; the list is settling on its own now.
      _dragging = false;
      if (_armed && !_refreshing) _refresh();
    } else if (n is ScrollEndNotification) {
      if (_dragging && _armed && !_refreshing) _refresh();
      _dragging = false;
    }

    if (_dragging && !_refreshing) {
      if (!_armed && overscroll >= _threshold) {
        _armed = true;
        FlutterHaptics.perform(AppHaptics.armed);
      } else if (_armed && overscroll < _threshold) {
        _armed = false;
        FlutterHaptics.perform(AppHaptics.disarmed);
      }
    }

    setState(() => _pull = overscroll);
    return false;
  }

  Future<void> _refresh() async {
    setState(() {
      _armed = false;
      _refreshing = true;
    });
    // No haptics while loading: waiting is not an event.
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() {
      _items.insert(0, _incoming[_fetched % _incoming.length]);
      _fetched++;
      _refreshing = false;
    });
    FlutterHaptics.perform(AppHaptics.success);
  }

  String get _status {
    if (_refreshing) return 'Refreshing…';
    if (_armed) return 'Release to refresh';
    if (_fetched > 0 && _pull == 0) return 'Up to date';
    return 'Pull down';
  }

  @override
  Widget build(BuildContext context) {
    final lit = _armed || _refreshing;
    final color = lit ? AppColors.accent : AppColors.textMuted;
    final reveal = _refreshing ? 1.0 : (_pull / 40).clamp(0.0, 1.0);
    final indicatorTop = _refreshing ? 16.0 : (_pull / 2 - 16).clamp(4.0, 60.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _status.toUpperCase(),
              style: AppTypography.eyebrow.copyWith(color: color),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 280,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                Positioned(
                  top: indicatorTop,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Opacity(
                      opacity: reveal,
                      child: _Indicator(
                        progress: _refreshing
                            ? null
                            : (_pull / _threshold).clamp(0.0, 1.0),
                        armed: _armed,
                        color: color,
                      ),
                    ),
                  ),
                ),
                AnimatedPadding(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.only(top: _refreshing ? 64 : 0),
                  child: NotificationListener<ScrollNotification>(
                    onNotification: _onScroll,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: EdgeInsets.zero,
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final fresh = i == 0 && _fetched > 0;
                        final row = _Row(title: _items[i], fresh: fresh);
                        if (!fresh) return row;
                        return TweenAnimationBuilder<double>(
                          key: ValueKey(_fetched),
                          tween: Tween<double>(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 380),
                          curve: Curves.easeOutCubic,
                          builder: (context, t, child) => Opacity(
                            opacity: t,
                            child: Transform.translate(
                              offset: Offset(0, -18 * (1 - t)),
                              child: child,
                            ),
                          ),
                          child: row,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Indicator extends StatelessWidget {
  const _Indicator({
    required this.progress,
    required this.armed,
    required this.color,
  });

  /// Null while refreshing.
  final double? progress;
  final bool armed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 2.5,
            color: color,
            backgroundColor: AppColors.surfaceHighest,
          ),
          if (progress != null)
            AnimatedRotation(
              turns: armed ? 0.5 : 0,
              duration: const Duration(milliseconds: 180),
              child: Icon(
                Icons.arrow_downward_rounded,
                size: 16,
                color: color,
              ),
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.title, required this.fresh});

  final String title;
  final bool fresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: fresh
              ? AppColors.accent.withValues(alpha: 0.5)
              : AppColors.outline,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.article_outlined,
            size: 18,
            color: fresh ? AppColors.accent : AppColors.textMuted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.text),
            ),
          ),
          if (fresh)
            Text(
              'NEW',
              style: AppTypography.eyebrow.copyWith(color: AppColors.accent),
            ),
        ],
      ),
    );
  }
}
