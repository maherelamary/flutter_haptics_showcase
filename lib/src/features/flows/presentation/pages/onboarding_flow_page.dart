import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_typography.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_haptics.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/haptics_providers.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/pill_tag.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/safe_animated_switcher.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/shaker.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/tactile_card.dart';
import 'package:flutter_haptics_showcase/src/features/flows/presentation/widgets/haptic_recap.dart';
import 'package:flutter_haptics_showcase/src/features/flows/presentation/widgets/success_burst.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum _Step { intro, verify, permissions, feel, done }

class _IntroData {
  const _IntroData(this.icon, this.color, this.title, this.body);

  final IconData icon;
  final Color color;
  final String title;
  final String body;
}

/// Onboarding: intro pages, a one-time code, permissions — and the user
/// choosing whether the app should buzz at all.
class OnboardingFlowPage extends ConsumerStatefulWidget {
  const OnboardingFlowPage({super.key});

  @override
  ConsumerState<OnboardingFlowPage> createState() => _OnboardingFlowPageState();
}

class _OnboardingFlowPageState extends ConsumerState<OnboardingFlowPage> {
  static const _code = '424242';
  static const _intro = [
    _IntroData(
      Icons.waving_hand_rounded,
      AppColors.flows,
      'Welcome to Flutter Haptics Tactile',
      'A wallet that answers back. Every confirmation, limit and threshold '
          'is something you can feel.',
    ),
    _IntroData(
      Icons.vibration_rounded,
      AppColors.accent,
      'Felt, not noisy',
      'Haptics mark what matters — accepted, refused, committed. '
          'Scrolling and browsing stay quiet.',
    ),
    _IntroData(
      Icons.tune_rounded,
      AppColors.studio,
      'Yours to tune',
      'Prefer silence? One switch turns every haptic off, everywhere. '
          'You will choose in a moment.',
    ),
  ];

  final DateTime _start = DateTime.now();
  final PageController _pages = PageController();
  final ShakeController _otpShake = ShakeController();

  _Step _step = _Step.intro;
  int _page = 0;
  String _entered = '';

  /// null while typing, true once verified, false while showing an error.
  bool? _verified;
  Timer? _otpTimer;
  bool _notifications = false;
  bool _location = false;

  @override
  void dispose() {
    _otpTimer?.cancel();
    _pages.dispose();
    _otpShake.dispose();
    super.dispose();
  }

  /// A user-initiated step change ticks; the flow advancing on its own
  /// after a verified code does not (the success already spoke).
  void _goTo(_Step step, {bool tick = true}) {
    if (tick) FlutterHaptics.perform(AppHaptics.tick);
    setState(() => _step = step);
  }

  // ─── Intro ─────────────────────────────────────────────────────────

  void _next() {
    if (_page < _intro.length - 1) {
      // onPageChanged ticks, exactly once, whether swiped or tapped.
      _pages.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      _goTo(_Step.verify);
    }
  }

  // ─── Verify ────────────────────────────────────────────────────────

  void _key(String digit) {
    if (_entered.length >= _code.length || _verified != null) return;
    FlutterHaptics.perform(AppHaptics.key);
    setState(() => _entered += digit);
    if (_entered.length == _code.length) {
      _otpTimer?.cancel();
      _otpTimer = Timer(const Duration(milliseconds: 180), _verify);
    }
  }

  void _backspace() {
    if (_entered.isEmpty || _verified != null) return;
    // A sixth digit has a check pending; taking a digit back cancels it, or
    // it would judge the five that are left.
    _otpTimer?.cancel();
    FlutterHaptics.perform(AppHaptics.key);
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  void _verify() {
    if (!mounted) return;
    if (_entered == _code) {
      FlutterHaptics.perform(AppHaptics.success);
      setState(() => _verified = true);
      _otpTimer = Timer(const Duration(milliseconds: 750), () {
        if (mounted) _goTo(_Step.permissions, tick: false);
      });
    } else {
      // The refusal, the shake and the red boxes land on one frame.
      FlutterHaptics.perform(AppHaptics.failure);
      _otpShake.shake();
      setState(() => _verified = false);
      _otpTimer = Timer(const Duration(milliseconds: 650), () {
        if (!mounted) return;
        setState(() {
          _entered = '';
          _verified = null;
        });
      });
    }
  }

  // ─── Permissions & feel ────────────────────────────────────────────

  void _toggle(bool on, ValueChanged<bool> apply) {
    FlutterHaptics.perform(on ? AppHaptics.switchOn : AppHaptics.switchOff);
    setState(() => apply(on));
  }

  Future<void> _chooseHaptics(bool on) async {
    final settings = ref.read(hapticsSettingsProvider);
    if (settings.enabled == on) return;
    final notifier = ref.read(hapticsSettingsProvider.notifier);
    // Same order as Settings: silence what is playing and feel "off" before
    // it goes quiet, feel "on" once it can be felt.
    if (!on) {
      await FlutterHaptics.stop();
      await FlutterHaptics.perform(AppHaptics.switchOff);
    }
    await notifier.setEnabled(on);
    if (on) FlutterHaptics.perform(AppHaptics.switchOn);
  }

  void _finish() {
    FlutterHaptics.perform(AppHaptics.success);
    setState(() => _step = _Step.done);
  }

  void _recap() => showHapticRecap(
    context,
    ref,
    start: _start,
    title: 'Onboarding',
    footnote:
        'If you chose "Haptics off", everything after that moment '
        'is missing here — the package never reached the platform.',
  );

  // ─── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final progress = (_step.index + 1) / _Step.values.length;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Onboarding'),
        actions: [
          TextButton(onPressed: _recap, child: const Text('Recap')),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: progress),
                  duration: const Duration(milliseconds: 360),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => LinearProgressIndicator(
                    value: v,
                    minHeight: 4,
                    color: AppColors.flows,
                  ),
                ),
              ),
            ),
            Expanded(
              child: SafeAnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOutCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.05, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: switch (_step) {
                    _Step.intro => _introStep(context),
                    _Step.verify => _verifyStep(context),
                    _Step.permissions => _permissionsStep(context),
                    _Step.feel => _feelStep(context),
                    _Step.done => _doneStep(context),
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _introStep(BuildContext context) {
    final last = _page == _intro.length - 1;
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pages,
            itemCount: _intro.length,
            onPageChanged: (i) {
              FlutterHaptics.perform(AppHaptics.tick);
              setState(() => _page = i);
            },
            itemBuilder: (context, i) => _IntroPage(data: _intro[i]),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _intro.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _page ? 22 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: i == _page
                      ? AppColors.flows
                      : AppColors.surfaceHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            children: [
              TextButton(
                onPressed: last ? null : () => _goTo(_Step.verify),
                child: Text(
                  'Skip',
                  style: TextStyle(
                    color: last ? Colors.transparent : AppColors.textMuted,
                  ),
                ),
              ),
              const Spacer(),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.flows),
                onPressed: _next,
                child: Text(last ? 'Get started' : 'Next'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _verifyStep(BuildContext context) {
    final theme = Theme.of(context);
    final boxColor = switch (_verified) {
      true => AppColors.accent,
      false => AppColors.danger,
      null => AppColors.flows,
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      children: [
        Text('Verify your number', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
          'We sent a 6-digit code to +20 ··· 4821.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 10),
        const Align(
          alignment: Alignment.centerLeft,
          child: PillTag('Demo code · 424242', color: AppColors.flows),
        ),
        const SizedBox(height: 24),
        Shaker(
          controller: _otpShake,
          child: Row(
            children: [
              for (var i = 0; i < _code.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _verified == true
                          ? AppColors.accent.withValues(alpha: 0.1)
                          : AppColors.surfaceRaised,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        width: i == _entered.length && _verified == null
                            ? 1.6
                            : 1,
                        color: _verified != null
                            ? boxColor
                            : i < _entered.length
                            ? boxColor.withValues(alpha: 0.6)
                            : i == _entered.length
                            ? AppColors.text
                            : AppColors.outline,
                      ),
                    ),
                    child: SafeAnimatedSwitcher(
                      duration: const Duration(milliseconds: 140),
                      transitionBuilder: (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                      child: Text(
                        i < _entered.length ? _entered[i] : '',
                        key: ValueKey('$i-${i < _entered.length}'),
                        style: AppTypography.mono.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: _verified == null ? AppColors.text : boxColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 20,
          child: SafeAnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Text(
              switch (_verified) {
                true => 'Verified',
                false => 'That code didn’t match. Try again.',
                null => 'The last digit submits — no button to find.',
              },
              key: ValueKey(_verified),
              style: theme.textTheme.bodySmall?.copyWith(
                color: _verified == null ? AppColors.textMuted : boxColor,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        _Keypad(onDigit: _key, onBackspace: _backspace),
      ],
    );
  }

  Widget _permissionsStep(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      children: [
        Text('A few permissions', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
          'Each switch is felt: on is bright and crisp, off is dull and soft. '
          'You can tell which way it went without looking.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 22),
        _PermissionRow(
          icon: Icons.notifications_active_rounded,
          title: 'Notifications',
          body: 'Payment receipts and security alerts.',
          value: _notifications,
          onChanged: (on) => _toggle(on, (v) => _notifications = v),
        ),
        const SizedBox(height: 10),
        _PermissionRow(
          icon: Icons.location_on_rounded,
          title: 'Location',
          body: 'Find nearby pickup points.',
          value: _location,
          onChanged: (on) => _toggle(on, (v) => _location = v),
        ),
        const SizedBox(height: 28),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.flows),
          onPressed: () => _goTo(_Step.feel),
          child: const Text('Continue'),
        ),
      ],
    );
  }

  Widget _feelStep(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = ref.watch(hapticsSettingsProvider.select((s) => s.enabled));
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      children: [
        Text(
          'How should Flutter Haptics Tactile feel?',
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        Text(
          'This is the real setting. It drives FlutterHaptics.enabled, so '
          'every haptic in the app obeys it without a single check.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 22),
        _FeelCard(
          icon: Icons.vibration_rounded,
          title: 'Haptics on',
          body: 'Feel confirmations, limits and thresholds.',
          selected: enabled,
          onTap: () => _chooseHaptics(true),
        ),
        const SizedBox(height: 10),
        _FeelCard(
          icon: Icons.mobile_off_rounded,
          title: 'Haptics off',
          body: 'Silence. The screen still shows everything.',
          selected: !enabled,
          onTap: () => _chooseHaptics(false),
        ),
        const SizedBox(height: 12),
        Text(
          'Change it any time in Settings.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 28),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.flows),
          onPressed: _finish,
          child: const Text('Finish'),
        ),
      ],
    );
  }

  Widget _doneStep(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = ref.watch(hapticsSettingsProvider.select((s) => s.enabled));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          const SuccessBurst(),
          const SizedBox(height: 28),
          Text('You’re all set', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            enabled
                ? 'Haptics are on. Change it any time in Settings.'
                : 'Haptics are off — that success was shown, not felt.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 36),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _recap,
              icon: const Icon(Icons.timeline_rounded),
              label: const Text('See haptic recap'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => context.pop(),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntroPage extends StatelessWidget {
  const _IntroPage({required this.data});

  final _IntroData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 12),
      child: Column(
        children: [
          SizedBox(
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                for (final (size, alpha) in const [
                  (210.0, 0.05),
                  (150.0, 0.09),
                  (96.0, 0.16),
                ])
                  Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: data.color.withValues(alpha: alpha),
                      border: Border.all(
                        color: data.color.withValues(alpha: alpha * 2),
                      ),
                    ),
                  ),
                Icon(data.icon, size: 44, color: data.color),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            data.body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onDigit, required this.onBackspace});

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '<'],
    ];
    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                for (var i = 0; i < row.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: row[i].isEmpty
                        ? const SizedBox(height: 58)
                        : _Key(
                            label: row[i],
                            onTap: row[i] == '<'
                                ? onBackspace
                                : () => onDigit(row[i]),
                          ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final backspace = label == '<';
    return PressableScale(
      onTap: onTap,
      pressedScale: 0.92,
      child: Container(
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: backspace ? Colors.transparent : AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: backspace ? Colors.transparent : AppColors.outline,
          ),
        ),
        child: backspace
            ? const Icon(Icons.backspace_outlined, color: AppColors.textMuted)
            : Text(
                label,
                style: AppTypography.mono.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.icon,
    required this.title,
    required this.body,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TactileCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: (value ? AppColors.accent : AppColors.textFaint)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: value ? AppColors.accent : AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(body, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _FeelCard extends StatelessWidget {
  const _FeelCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TactileCard(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      borderColor: selected ? AppColors.flows : AppColors.outline,
      color: selected
          ? AppColors.flows.withValues(alpha: 0.08)
          : AppColors.surface,
      child: Row(
        children: [
          Icon(
            icon,
            size: 30,
            color: selected ? AppColors.flows : AppColors.textMuted,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(body, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          AnimatedOpacity(
            opacity: selected ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: const Icon(
              Icons.check_circle_rounded,
              color: AppColors.flows,
            ),
          ),
        ],
      ),
    );
  }
}
