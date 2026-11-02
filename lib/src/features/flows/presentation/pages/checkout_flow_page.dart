import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_typography.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_haptics.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_patterns.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/safe_animated_switcher.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/shaker.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/tactile_card.dart';
import 'package:flutter_haptics_showcase/src/features/flows/presentation/widgets/flow_step_indicator.dart';
import 'package:flutter_haptics_showcase/src/features/flows/presentation/widgets/haptic_recap.dart';
import 'package:flutter_haptics_showcase/src/features/flows/presentation/widgets/hold_to_pay_button.dart';
import 'package:flutter_haptics_showcase/src/features/flows/presentation/widgets/success_burst.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

String _money(double value) => '\$${value.toStringAsFixed(2)}';

class _CartItem {
  _CartItem({
    required this.id,
    required this.name,
    required this.detail,
    required this.price,
    required this.icon,
    required this.color,
  });

  final String id;
  final String name;
  final String detail;
  final double price;
  final IconData icon;
  final Color color;
  int quantity = 1;
}

class _Delivery {
  const _Delivery(this.id, this.title, this.detail, this.price, this.icon);

  final String id;
  final String title;
  final String detail;
  final double price;
  final IconData icon;
}

enum _Phase { cart, delivery, pay, processing, done }

/// Checkout and pay: steppers, swipe-to-remove, a promo code that can be
/// refused, a hold-to-pay, and the one celebration a purchase deserves.
class CheckoutFlowPage extends ConsumerStatefulWidget {
  const CheckoutFlowPage({super.key});

  @override
  ConsumerState<CheckoutFlowPage> createState() => _CheckoutFlowPageState();
}

class _CheckoutFlowPageState extends ConsumerState<CheckoutFlowPage> {
  static const _steps = ['Cart', 'Delivery', 'Pay'];
  static const _deliveries = [
    _Delivery(
      'standard',
      'Standard',
      '3–5 days',
      0,
      Icons.local_shipping_outlined,
    ),
    _Delivery('express', 'Express', 'Tomorrow by 10:00', 9, Icons.bolt_rounded),
    _Delivery(
      'pickup',
      'Pickup',
      'Ready in 2 hours',
      0,
      Icons.storefront_outlined,
    ),
  ];

  final DateTime _start = DateTime.now();
  final List<_CartItem> _items = [
    _CartItem(
      id: 'buds',
      name: 'Pulse Buds',
      detail: 'Wireless · Graphite',
      price: 129,
      icon: Icons.headphones_rounded,
      color: AppColors.flows,
    ),
    _CartItem(
      id: 'band',
      name: 'Tempo Band',
      detail: 'Haptic fitness band',
      price: 79,
      icon: Icons.watch_rounded,
      color: AppColors.lab,
    ),
    _CartItem(
      id: 'case',
      name: 'Shell Case',
      detail: 'Matte · Lime',
      price: 24,
      icon: Icons.phone_iphone_rounded,
      color: AppColors.accent,
    ),
  ];
  final TextEditingController _promo = TextEditingController();
  final ShakeController _promoShake = ShakeController();

  _Phase _phase = _Phase.cart;
  String _delivery = 'standard';
  bool _discounted = false;
  String? _promoError;
  Timer? _processing;
  final String _order = 'TCT-${1000 + math.Random().nextInt(9000)}';

  int get _step => switch (_phase) {
    _Phase.cart => 0,
    _Phase.delivery => 1,
    _ => 2,
  };

  double get _subtotal =>
      _items.fold(0, (sum, item) => sum + item.price * item.quantity);

  double get _shipping =>
      _deliveries.firstWhere((d) => d.id == _delivery).price;

  double get _discount => _discounted ? _subtotal * 0.1 : 0;

  double get _total => _subtotal + _shipping - _discount;

  @override
  void initState() {
    super.initState();
    _promo.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _processing?.cancel();
    _promo.dispose();
    _promoShake.dispose();
    super.dispose();
  }

  // ─── Navigation ────────────────────────────────────────────────────

  /// A user-initiated step change ticks, like any segmented control.
  void _goTo(_Phase phase) {
    FocusScope.of(context).unfocus();
    FlutterHaptics.perform(AppHaptics.tick);
    setState(() => _phase = phase);
  }

  void _back() {
    switch (_phase) {
      case _Phase.delivery:
        _goTo(_Phase.cart);
      case _Phase.pay:
        _goTo(_Phase.delivery);
      case _Phase.cart:
      case _Phase.done:
        context.pop();
      case _Phase.processing:
        break;
    }
  }

  // ─── Cart ──────────────────────────────────────────────────────────

  void _remove(_CartItem item) {
    final index = _items.indexOf(item);
    // The armed tick already said "this will go"; the commit is a press.
    FlutterHaptics.perform(AppHaptics.press);
    setState(() => _items.remove(item));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${item.name} removed'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              if (!mounted) return;
              FlutterHaptics.play(AppPatterns.rewind);
              setState(
                () => _items.insert(math.min(index, _items.length), item),
              );
            },
          ),
        ),
      );
  }

  // ─── Delivery ──────────────────────────────────────────────────────

  void _selectDelivery(String id) {
    if (id == _delivery) return;
    FlutterHaptics.perform(AppHaptics.tick);
    setState(() => _delivery = id);
  }

  void _applyPromo() {
    final code = _promo.text.trim().toUpperCase();
    if (code.isEmpty) return;
    FocusScope.of(context).unfocus();
    if (code == 'TACTILE') {
      FlutterHaptics.perform(AppHaptics.success);
      setState(() {
        _discounted = true;
        _promoError = null;
      });
    } else {
      // Felt and seen together: the refusal and the shake share a frame.
      FlutterHaptics.perform(AppHaptics.failure);
      _promoShake.shake();
      setState(() => _promoError = '“$code” isn’t a valid code.');
    }
  }

  void _removePromo() {
    FlutterHaptics.perform(AppHaptics.tap);
    setState(() {
      _discounted = false;
      _promo.clear();
    });
  }

  // ─── Pay ───────────────────────────────────────────────────────────

  void _paid() {
    setState(() => _phase = _Phase.processing);
    // Silence while waiting: the spinner already says "working".
    _processing = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      FlutterHaptics.play(AppPatterns.celebrate);
      setState(() => _phase = _Phase.done);
    });
  }

  void _recap() => showHapticRecap(
    context,
    ref,
    start: _start,
    title: 'Checkout & pay',
    footnote:
        'Nothing played during the 1.4s of processing — '
        'by design.',
  );

  // ─── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final busy = _phase == _Phase.processing;
    final done = _phase == _Phase.done;

    return PopScope(
      canPop: _phase == _Phase.cart || done,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: busy
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: _phase == _Phase.cart || done ? 'Close' : 'Back',
                  icon: Icon(
                    _phase == _Phase.cart || done
                        ? Icons.close_rounded
                        : Icons.arrow_back_rounded,
                  ),
                  onPressed: _back,
                ),
          title: const Text('Checkout'),
          actions: [
            TextButton(onPressed: _recap, child: const Text('Recap')),
            const SizedBox(width: 4),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              if (!done && !busy)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: FlowStepIndicator(
                    steps: _steps,
                    current: _step,
                    onStepTap: (i) => _goTo(_Phase.values[i]),
                  ),
                ),
              Expanded(
                child: SafeAnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.04, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(_phase),
                    child: switch (_phase) {
                      _Phase.cart => _cart(context),
                      _Phase.delivery => _deliveryStep(context),
                      _Phase.pay => _payStep(context),
                      _Phase.processing => _processingStep(context),
                      _Phase.done => _doneStep(context),
                    },
                  ),
                ),
              ),
              if (_phase == _Phase.cart || _phase == _Phase.delivery)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.flows,
                      ),
                      onPressed: _items.isEmpty
                          ? null
                          : () => _goTo(
                              _phase == _Phase.cart
                                  ? _Phase.delivery
                                  : _Phase.pay,
                            ),
                      child: Text(
                        _phase == _Phase.cart
                            ? 'Continue · ${_money(_subtotal)}'
                            : 'Review & pay',
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cart(BuildContext context) {
    final theme = Theme.of(context);
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.shopping_bag_outlined,
              size: 48,
              color: AppColors.textFaint,
            ),
            const SizedBox(height: 12),
            Text('Your cart is empty', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Undo, or start the flow again.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        for (final item in _items) ...[
          Dismissible(
            key: ValueKey(item.id),
            direction: DismissDirection.endToStart,
            onUpdate: (details) {
              // Crossing the line is felt both ways, so the user knows
              // which side of it they will let go on.
              if (details.reached && !details.previousReached) {
                FlutterHaptics.perform(AppHaptics.armed);
              } else if (!details.reached && details.previousReached) {
                FlutterHaptics.perform(AppHaptics.disarmed);
              }
            },
            onDismissed: (_) => _remove(item),
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.danger,
              ),
            ),
            child: _CartRow(
              item: item,
              onQuantity: (q) => setState(() => item.quantity = q),
            ),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 6),
        _SummaryLine(label: 'Subtotal', value: _subtotal, emphasize: true),
        const SizedBox(height: 14),
        Row(
          children: [
            const Icon(
              Icons.swipe_left_rounded,
              size: 16,
              color: AppColors.textFaint,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Swipe an item left to remove it — feel the line as you cross it.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _deliveryStep(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        const Text('DELIVERY', style: AppTypography.eyebrow),
        const SizedBox(height: 10),
        for (final option in _deliveries) ...[
          _DeliveryCard(
            option: option,
            selected: option.id == _delivery,
            onTap: () => _selectDelivery(option.id),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 14),
        const Text('PROMO CODE', style: AppTypography.eyebrow),
        const SizedBox(height: 10),
        if (_discounted)
          TactileCard(
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
            borderColor: AppColors.accent.withValues(alpha: 0.5),
            color: AppColors.accent.withValues(alpha: 0.06),
            child: Row(
              children: [
                const Icon(
                  Icons.local_offer_rounded,
                  color: AppColors.accent,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'TACTILE · 10% off',
                    style: AppTypography.mono.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove code',
                  onPressed: _removePromo,
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
          )
        else
          Shaker(
            controller: _promoShake,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _promo,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _applyPromo(),
                    onChanged: (_) {
                      if (_promoError != null) {
                        setState(() => _promoError = null);
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Try TACTILE',
                      errorText: _promoError,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    onPressed: _promo.text.trim().isEmpty ? null : _applyPromo,
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 22),
        _SummaryLine(label: 'Subtotal', value: _subtotal),
        _SummaryLine(label: 'Delivery', value: _shipping),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          child: _discounted
              ? _SummaryLine(label: 'Discount', value: -_discount, accent: true)
              : const SizedBox(width: double.infinity),
        ),
        const Divider(height: 24),
        _SummaryLine(label: 'Total', value: _total, emphasize: true),
        const SizedBox(height: 8),
        Text(
          'A wrong code is refused with a felt "no" and a shake on the same '
          'frame. Typing itself stays silent.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _payStep(BuildContext context) {
    final theme = Theme.of(context);
    final delivery = _deliveries.firstWhere((d) => d.id == _delivery);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        const Text('ORDER', style: AppTypography.eyebrow),
        const SizedBox(height: 10),
        TactileCard(
          child: Column(
            children: [
              for (final item in _items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(item.icon, size: 18, color: item.color),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${item.name}  ×${item.quantity}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      Text(
                        _money(item.price * item.quantity),
                        style: AppTypography.mono,
                      ),
                    ],
                  ),
                ),
              const Divider(height: 20),
              _SummaryLine(label: delivery.title, value: delivery.price),
              if (_discounted)
                _SummaryLine(
                  label: 'Discount',
                  value: -_discount,
                  accent: true,
                ),
              const SizedBox(height: 6),
              _SummaryLine(label: 'Total', value: _total, emphasize: true),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text('PAYMENT', style: AppTypography.eyebrow),
        const SizedBox(height: 10),
        TactileCard(
          child: Row(
            children: [
              Container(
                width: 44,
                height: 30,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  gradient: const LinearGradient(
                    colors: [AppColors.flows, AppColors.studio],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text('Visa ·· 4242', style: theme.textTheme.titleSmall),
              ),
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.accent,
                size: 20,
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        HoldToPayButton(
          label: 'Hold to pay ${_money(_total)}',
          onConfirmed: _paid,
        ),
        const SizedBox(height: 10),
        Text(
          'Hold for a moment — a payment should never happen by accident. '
          'Let go early and the rumble stops mid-swell.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _processingStep(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.flows,
              ),
            ),
            const SizedBox(height: 24),
            Text('Processing payment…', style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            Text(
              'Silence while waiting. The spinner already says "working" — '
              'buzzing on a timer only adds anxiety.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _doneStep(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          const SuccessBurst(),
          const SizedBox(height: 28),
          Text('Payment complete', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            '${_money(_total)} · Order #$_order',
            style: AppTypography.mono.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          Text(
            'The longest pattern in the app plays exactly once per purchase: '
            'money moving deserves it.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
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

class _CartRow extends StatelessWidget {
  const _CartRow({required this.item, required this.onQuantity});

  final _CartItem item;
  final ValueChanged<int> onQuantity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TactileCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(item.icon, color: item.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(item.detail, style: theme.textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(
                  _money(item.price),
                  style: AppTypography.mono.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          _QuantityStepper(value: item.quantity, onChanged: onQuantity),
        ],
      ),
    );
  }
}

/// − n + with a felt end stop at both bounds.
class _QuantityStepper extends StatefulWidget {
  const _QuantityStepper({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  State<_QuantityStepper> createState() => _QuantityStepperState();
}

class _QuantityStepperState extends State<_QuantityStepper> {
  static const _min = 1;
  static const _max = 9;
  final ShakeController _shake = ShakeController();

  void _change(int delta) {
    final next = widget.value + delta;
    if (next < _min || next > _max) {
      // No further: a dull bump, and the number shakes with it.
      FlutterHaptics.perform(AppHaptics.limit);
      _shake.shake();
      return;
    }
    FlutterHaptics.perform(AppHaptics.tick);
    widget.onChanged(next);
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: Icons.remove_rounded,
            dimmed: widget.value <= _min,
            onTap: () => _change(-1),
          ),
          Shaker(
            controller: _shake,
            distance: 5,
            child: SizedBox(
              width: 24,
              child: SafeAnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: Text(
                  '${widget.value}',
                  key: ValueKey(widget.value),
                  textAlign: TextAlign.center,
                  style: AppTypography.mono.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add_rounded,
            dimmed: widget.value >= _max,
            onTap: () => _change(1),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.onTap,
    this.dimmed = false,
  });

  final IconData icon;
  final VoidCallback onTap;

  /// Looks unavailable but stays tappable, so hitting the limit is felt.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      pressedScale: 0.85,
      child: SizedBox(
        width: 36,
        height: 40,
        child: Icon(
          icon,
          size: 18,
          color: dimmed ? AppColors.textFaint : AppColors.text,
        ),
      ),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _Delivery option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TactileCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      borderColor: selected ? AppColors.flows : AppColors.outline,
      color: selected
          ? AppColors.flows.withValues(alpha: 0.08)
          : AppColors.surface,
      child: Row(
        children: [
          Icon(
            option.icon,
            color: selected ? AppColors.flows : AppColors.textMuted,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(option.title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(option.detail, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Text(
            option.price == 0 ? 'Free' : _money(option.price),
            style: AppTypography.mono.copyWith(fontSize: 12),
          ),
          const SizedBox(width: 12),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? AppColors.flows : AppColors.outlineStrong,
                width: selected ? 6 : 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
    this.emphasize = false,
    this.accent = false,
  });

  final String label;
  final double value;
  final bool emphasize;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = accent ? AppColors.accent : AppColors.text;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: emphasize
                  ? theme.textTheme.titleMedium
                  : theme.textTheme.bodyMedium,
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(end: value),
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Text(
              v < 0 ? '−${_money(-v)}' : _money(v),
              style: AppTypography.mono.copyWith(
                color: color,
                fontSize: emphasize ? 16 : 13,
                fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
