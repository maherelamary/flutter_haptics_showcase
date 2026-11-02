import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_typography.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_haptics.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_patterns.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/haptic_pacer.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/safe_animated_switcher.dart';
import 'package:flutter_haptics_showcase/src/features/flows/presentation/widgets/haptic_recap.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class _Message {
  _Message({
    required this.id,
    required this.text,
    this.mine = false,
    this.system = false,
    this.replyTo,
  });

  final int id;
  final String text;
  final bool mine;

  /// A quiet in-thread note, not a chat message.
  final bool system;

  /// Text of the message this one answers.
  final String? replyTo;

  String? reaction;
}

/// Messaging: send, react, reply — and when an incoming message should
/// stay silent.
class ChatFlowPage extends ConsumerStatefulWidget {
  const ChatFlowPage({super.key});

  @override
  ConsumerState<ChatFlowPage> createState() => _ChatFlowPageState();
}

class _ChatFlowPageState extends ConsumerState<ChatFlowPage> {
  static const _reactions = ['❤️', '👍', '😂', '😮', '😢', '🔥'];
  static const _slot = 46.0;
  static const _barPad = 8.0;
  static const _barHeight = 58.0;
  static const _replies = [
    'Got it 👌',
    'Scroll up a little before my next reply — you’ll get a tap, because '
        'you can’t see it arrive.',
    'Ha, felt that one.',
    'Perfect — thanks!',
    'On my way.',
  ];

  final DateTime _start = DateTime.now();
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final GlobalKey _stackKey = GlobalKey();
  final HapticPacer _pacer = HapticPacer(
    minInterval: const Duration(milliseconds: 60),
  );
  final List<Timer> _timers = [];
  final Set<int> _fresh = {};
  final List<_Message> _messages = [
    _Message(id: 1, text: 'Did the transfer go through?'),
    _Message(id: 2, text: 'Sending it now', mine: true),
    _Message(
      id: 3,
      text:
          'Long-press any message to react — slide across the emoji and '
          'let go on one.',
    ),
    _Message(id: 4, text: 'Or swipe a message to the right to reply.'),
  ];

  int _nextId = 100;
  int _replyIndex = 0;
  bool _typing = false;
  bool _explained = false;
  bool _atBottom = true;
  int _unseen = 0;
  _Message? _replyTo;

  // Reaction picker.
  _Message? _reacting;
  Offset _anchor = Offset.zero;
  Size _stackSize = Size.zero;
  int? _hover;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _scroll.dispose();
    _input.dispose();
    super.dispose();
  }

  void _later(Duration delay, VoidCallback action) {
    _timers.add(
      Timer(delay, () {
        if (mounted) action();
      }),
    );
  }

  void _onScroll() {
    // The list is reversed: offset 0 is the newest message.
    final atBottom = _scroll.offset <= 32;
    if (atBottom == _atBottom) return;
    setState(() {
      _atBottom = atBottom;
      if (atBottom) _unseen = 0;
    });
  }

  void _toBottom() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _add(_Message message) {
    _messages.add(message);
    _fresh.add(message.id);
    _later(const Duration(milliseconds: 500), () => _fresh.remove(message.id));
  }

  // ─── Send & receive ────────────────────────────────────────────────

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    // A message leaving: a short swell, on the frame the bubble flies in.
    FlutterHaptics.play(AppPatterns.whoosh);
    setState(() {
      _add(
        _Message(
          id: _nextId++,
          text: text,
          mine: true,
          replyTo: _replyTo?.text,
        ),
      );
      _replyTo = null;
    });
    _input.clear();
    _toBottom();
    _later(
      const Duration(milliseconds: 650),
      () => setState(() => _typing = true),
    );
    _later(const Duration(milliseconds: 1850), _receive);
  }

  void _receive() {
    final text = _replies[_replyIndex++ % _replies.length];
    setState(() {
      _typing = false;
      _add(_Message(id: _nextId++, text: text));
    });

    if (_atBottom) {
      // Silent on purpose: the user is looking at the thread, and the
      // screen has already told them.
      if (!_explained) {
        _explained = true;
        _later(const Duration(milliseconds: 500), () {
          setState(
            () => _add(
              _Message(
                id: _nextId++,
                system: true,
                text:
                    'Incoming messages are silent while you’re looking — '
                    'the screen already told you.',
              ),
            ),
          );
        });
      }
    } else {
      // Out of sight, so worth a light tap.
      FlutterHaptics.perform(AppHaptics.tap);
      setState(() => _unseen++);
    }
  }

  // ─── Reactions ─────────────────────────────────────────────────────

  RenderBox? get _stackBox =>
      _stackKey.currentContext?.findRenderObject() as RenderBox?;

  Rect _barRect() {
    // Slots, padding, and the 1 px border on each side.
    final width = _reactions.length * _slot + _barPad * 2 + 2;
    final maxLeft = math.max(8.0, _stackSize.width - width - 8);
    final left = (_anchor.dx - width / 2).clamp(8.0, maxLeft);
    final top = math.max(8.0, _anchor.dy - _barHeight - 56);
    return Rect.fromLTWH(left, top, width, _barHeight);
  }

  void _startReacting(_Message message, Offset global) {
    final box = _stackBox;
    if (box == null) return;
    FlutterHaptics.perform(AppHaptics.longPress);
    _pacer.reset();
    setState(() {
      _reacting = message;
      _anchor = box.globalToLocal(global);
      _stackSize = box.size;
      _hover = null;
    });
  }

  void _moveReacting(Offset global) {
    final box = _stackBox;
    if (box == null || _reacting == null) return;
    final local = box.globalToLocal(global);
    final bar = _barRect();
    int? hover;
    if (bar.inflate(28).contains(local)) {
      final i = ((local.dx - bar.left - _barPad) / _slot).floor();
      if (i >= 0 && i < _reactions.length) hover = i;
    }
    if (hover == _hover) return;
    // Sliding across the emoji ticks like a picker, paced so a fast sweep
    // never smears into a buzz.
    if (hover != null && _pacer.ready()) {
      FlutterHaptics.perform(AppHaptics.tick);
    }
    setState(() => _hover = hover);
  }

  /// Closes the reaction bar without choosing anything.
  void _dismissReacting() {
    if (_reacting == null) return;
    setState(() {
      _reacting = null;
      _hover = null;
    });
  }

  void _endReacting() {
    final message = _reacting;
    final hover = _hover;
    if (message == null) return;
    if (hover != null) {
      FlutterHaptics.play(AppPatterns.pop);
      message.reaction = _reactions[hover];
    }
    // Released anywhere else: dismissed, silently.
    setState(() {
      _reacting = null;
      _hover = null;
    });
  }

  // ─── Reply ─────────────────────────────────────────────────────────

  void _setReply(_Message message) => setState(() => _replyTo = message);

  void _recap() => showHapticRecap(
    context,
    ref,
    start: _start,
    title: 'Messaging',
    footnote:
        'Replies that arrived while you were looking played nothing '
        '— they are not in this list at all.',
  );

  // ─── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: AppColors.flows.withValues(alpha: 0.18),
              child: Text(
                'N',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: AppColors.flows,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nour', style: theme.textTheme.titleMedium),
                SafeAnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: Text(
                    _typing ? 'typing…' : 'online',
                    key: ValueKey(_typing),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _typing ? AppColors.flows : AppColors.success,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: _recap, child: const Text('Recap')),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          key: _stackKey,
          children: [
            Column(
              children: [
                Expanded(child: _thread()),
                _composer(context),
              ],
            ),
            if (_reacting != null) ...[
              // Tapping the dimmed thread always closes the bar, even if the
              // long-press that opened it was lost to a rebuild.
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _dismissReacting,
                  child: const ColoredBox(color: Color(0x73000000)),
                ),
              ),
              Positioned.fromRect(
                rect: _barRect(),
                child: IgnorePointer(
                  child: _ReactionBar(
                    reactions: _reactions,
                    hover: _hover,
                    slot: _slot,
                    padding: _barPad,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _thread() {
    final count = _messages.length + (_typing ? 1 : 0);
    return Stack(
      children: [
        ListView.builder(
          controller: _scroll,
          reverse: true,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          itemCount: count,
          // Inserts land at index 0 of a reversed list and shift every row.
          // Mapping keys back to indices keeps each row's element — and any
          // long-press or swipe in progress on it — alive across the shift.
          findChildIndexCallback: (key) {
            if (key is! ValueKey) return null;
            final value = key.value;
            if (value == 'typing') return _typing ? 0 : null;
            final i = _messages.indexWhere((m) => m.id == value);
            if (i < 0) return null;
            return _messages.length - 1 - i + (_typing ? 1 : 0);
          },
          itemBuilder: (context, index) {
            if (_typing && index == 0) {
              return const _TypingBubble(key: ValueKey('typing'));
            }
            final i = _typing ? index - 1 : index;
            final message = _messages[_messages.length - 1 - i];
            return _tile(context, message);
          },
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 12,
          child: Center(
            child: AnimatedSlide(
              offset: _unseen > 0 && !_atBottom
                  ? Offset.zero
                  : const Offset(0, 1.6),
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: _unseen > 0 && !_atBottom ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: ActionChip(
                  backgroundColor: AppColors.flows,
                  side: BorderSide.none,
                  labelStyle: const TextStyle(
                    color: AppColors.onAccent,
                    fontWeight: FontWeight.w700,
                  ),
                  avatar: const Icon(
                    Icons.arrow_downward_rounded,
                    size: 16,
                    color: AppColors.onAccent,
                  ),
                  label: Text(
                    _unseen > 1 ? '$_unseen new messages' : 'New message',
                  ),
                  onPressed: _toBottom,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tile(BuildContext context, _Message message) {
    if (message.system) {
      return KeyedSubtree(
        key: ValueKey(message.id),
        child: _SystemNote(text: message.text),
      );
    }

    Widget tile = Align(
      alignment: message.mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPressStart: (d) => _startReacting(message, d.globalPosition),
        onLongPressMoveUpdate: (d) => _moveReacting(d.globalPosition),
        onLongPressEnd: (_) => _endReacting(),
        onLongPressCancel: _endReacting,
        child: _SwipeToReply(
          onReply: () => _setReply(message),
          child: _Bubble(
            message: message,
            lifted: identical(_reacting, message),
          ),
        ),
      ),
    );

    // Always wrapped, so a row's structure never changes when it stops
    // being fresh (a structural change would rebuild it mid-gesture).
    tile = TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: _fresh.contains(message.id) ? 0 : 1, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset((message.mine ? 28 : -28) * (1 - t), 14 * (1 - t)),
          child: child,
        ),
      ),
      child: tile,
    );

    return Padding(
      key: ValueKey(message.id),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: tile,
    );
  }

  Widget _composer(BuildContext context) {
    final theme = Theme.of(context);
    final reply = _replyTo;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.outline)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: reply == null
                ? const SizedBox(width: double.infinity)
                : Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8, right: 4),
                    padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceRaised,
                      borderRadius: BorderRadius.circular(12),
                      border: const Border(
                        left: BorderSide(color: AppColors.flows, width: 3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                reply.mine
                                    ? 'Replying to yourself'
                                    : 'Replying to Nour',
                                style: AppTypography.eyebrow.copyWith(
                                  color: AppColors.flows,
                                  fontSize: 9,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                reply.text,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Cancel reply',
                          visualDensity: VisualDensity.compact,
                          iconSize: 18,
                          onPressed: () => setState(() => _replyTo = null),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Message',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: const BorderSide(color: AppColors.outline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: const BorderSide(color: AppColors.outline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: const BorderSide(color: AppColors.flows),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _input,
                builder: (context, value, _) {
                  final canSend = value.text.trim().isNotEmpty;
                  return AnimatedScale(
                    scale: canSend ? 1 : 0.9,
                    duration: const Duration(milliseconds: 160),
                    child: IconButton.filled(
                      tooltip: 'Send',
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.flows,
                        foregroundColor: AppColors.onAccent,
                        disabledBackgroundColor: AppColors.surfaceHighest,
                        disabledForegroundColor: AppColors.textFaint,
                        minimumSize: const Size(46, 46),
                      ),
                      // Empty send is disabled, and therefore silent.
                      onPressed: canSend ? _send : null,
                      icon: const Icon(Icons.arrow_upward_rounded),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, this.lifted = false});

  final _Message message;
  final bool lifted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mine = message.mine;
    final reaction = message.reaction;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.74;
    final textColor = mine ? AppColors.onAccent : AppColors.text;

    final bubble = AnimatedScale(
      scale: lifted ? 1.04 : 1,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: mine ? AppColors.flows : AppColors.surfaceRaised,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 6),
            bottomRight: Radius.circular(mine ? 6 : 18),
          ),
          border: mine ? null : Border.all(color: AppColors.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.replyTo != null) ...[
              Container(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: mine ? 0.12 : 0.25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border(
                    left: BorderSide(
                      color: mine ? AppColors.onAccent : AppColors.flows,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  message.replyTo!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: textColor.withValues(alpha: 0.75),
                  ),
                ),
              ),
              const SizedBox(height: 6),
            ],
            Text(
              message.text,
              style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
            ),
          ],
        ),
      ),
    );

    if (reaction == null) return bubble;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          bubble,
          Positioned(
            bottom: -16,
            right: mine ? null : -4,
            left: mine ? -4 : null,
            child: TweenAnimationBuilder<double>(
              key: ValueKey(reaction),
              tween: Tween<double>(begin: 0.3, end: 1),
              duration: const Duration(milliseconds: 520),
              curve: Curves.elasticOut,
              builder: (context, t, child) =>
                  Transform.scale(scale: t, child: child),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHighest,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.background, width: 2),
                ),
                child: Text(reaction, style: const TextStyle(fontSize: 15)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Drag a bubble right to reply. Crossing the line is felt both ways.
class _SwipeToReply extends StatefulWidget {
  const _SwipeToReply({required this.child, required this.onReply});

  final Widget child;
  final VoidCallback onReply;

  @override
  State<_SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<_SwipeToReply>
    with SingleTickerProviderStateMixin {
  static const _threshold = 60.0;
  static const _max = 96.0;

  late final AnimationController _settle =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 220),
      )..addListener(() {
        setState(
          () =>
              _dx = _from * (1 - Curves.easeOutCubic.transform(_settle.value)),
        );
      });

  double _dx = 0;
  double _from = 0;
  bool _armed = false;

  void _update(DragUpdateDetails details) {
    _settle.stop();
    // Resistance past the line, so it feels like a detent, not a rail.
    final resistance = _dx > _threshold ? 0.35 : 1.0;
    final next = (_dx + details.delta.dx * resistance).clamp(0.0, _max);
    final armed = next >= _threshold;
    if (armed != _armed) {
      FlutterHaptics.perform(armed ? AppHaptics.armed : AppHaptics.disarmed);
      _armed = armed;
    }
    setState(() => _dx = next);
  }

  void _release() {
    if (_armed) widget.onReply();
    _armed = false;
    _from = _dx;
    _settle.forward(from: 0);
  }

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_dx / _threshold).clamp(0.0, 1.0);
    return GestureDetector(
      onHorizontalDragUpdate: _update,
      onHorizontalDragEnd: (_) => _release(),
      onHorizontalDragCancel: _release,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerLeft,
        children: [
          Positioned(
            left: -36,
            child: Opacity(
              opacity: progress,
              child: Transform.scale(
                scale: 0.6 + 0.4 * progress,
                child: Icon(
                  Icons.reply_rounded,
                  color: _armed ? AppColors.flows : AppColors.textMuted,
                ),
              ),
            ),
          ),
          Transform.translate(offset: Offset(_dx, 0), child: widget.child),
        ],
      ),
    );
  }
}

class _ReactionBar extends StatelessWidget {
  const _ReactionBar({
    required this.reactions,
    required this.hover,
    required this.slot,
    required this.padding,
  });

  final List<String> reactions;
  final int? hover;
  final double slot;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.6, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Transform.scale(
        scale: t,
        child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
      ),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: padding),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.outlineStrong),
          boxShadow: [
            BoxShadow(
              color: AppColors.flows.withValues(alpha: 0.25),
              blurRadius: 24,
            ),
          ],
        ),
        child: Row(
          children: [
            for (var i = 0; i < reactions.length; i++)
              SizedBox(
                width: slot,
                child: AnimatedSlide(
                  offset: hover == i ? const Offset(0, -0.25) : Offset.zero,
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.easeOutBack,
                  child: AnimatedScale(
                    scale: hover == i ? 1.5 : 1,
                    duration: const Duration(milliseconds: 140),
                    curve: Curves.easeOutBack,
                    child: Text(
                      reactions[i],
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble({super.key});

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dots = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _dots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.outline),
          ),
          child: AnimatedBuilder(
            animation: _dots,
            builder: (context, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 5),
                  Opacity(
                    opacity:
                        0.3 +
                        0.7 *
                            (0.5 +
                                0.5 *
                                    math.sin(
                                      (_dots.value - i * 0.18) * 2 * math.pi,
                                    )),
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SystemNote extends StatelessWidget {
  const _SystemNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.notifications_off_outlined,
            size: 14,
            color: AppColors.textFaint,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textFaint),
            ),
          ),
        ],
      ),
    );
  }
}
