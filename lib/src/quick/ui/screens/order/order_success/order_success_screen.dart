import '../../../../../presentation/orders/widgets/celebration_painter.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/utils/haptics.dart';
import '../../../../../presentation/branding/app_colors.dart';
import '../../../../../shared/ui/food_style_card.dart';
import '../../../../core/extensions/num_extensions.dart';
import '../../../../domain/model/order.dart';
import '../../../../domain/model/order_status.dart';
import '../../../../navigation/route_paths.dart';
import '../../../common/widgets/feedback/app_toast.dart';
import '../../../common/widgets/loaders/full_page_loader.dart';
import '../../../common/widgets/states/error_state_widget.dart';
import '../order_details/order_details_provider.dart';

/// Same design as the food vertical's order-success screen (shared brand,
/// shared layout) so a customer sees one consistent "order placed" moment
/// regardless of which vertical they ordered from.
class OrderSuccessScreen extends ConsumerStatefulWidget {
  const OrderSuccessScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends ConsumerState<OrderSuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _staggerController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  bool _navigatedAway = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Haptics.medium();
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) Haptics.success();
      });
      _staggerController.forward();
    });
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  Animation<double> _getInterval(double start, double end) {
    return CurvedAnimation(
      parent: _staggerController,
      curve: Interval(start, end, curve: Curves.easeOutBack),
    );
  }

  void _continueShopping() {
    Haptics.light();
    context.go(RoutePaths.home);
  }

  void _trackOrder(String orderId) {
    Haptics.light();
    context.go(RoutePaths.orderTrackingOf(orderId));
  }

  /// Once the seller has answered — accepted or rejected — this screen has
  /// nothing left to say; hand off to tracking (or home, with the reason),
  /// the same way the food vertical's success screen does.
  void _handleStatus(Order order) {
    if (_navigatedAway || !mounted) return;

    if (order.status.isCancelled) {
      _navigatedAway = true;
      Haptics.error();
      final reason = order.cancellationReason.isNotEmpty
          ? order.cancellationReason
          : 'The seller was unable to accept this order.';
      context.go(RoutePaths.home);
      AppToast.error(context, reason);
      return;
    }

    if (order.status != OrderStatus.created) {
      _navigatedAway = true;
      Haptics.success();
      context.go(RoutePaths.orderTrackingOf(order.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Fetched by id rather than carried through the route's `extra` — an
    // object passed that way is gone the moment Android reclaims a
    // backgrounded process (routine during a real payment-app handoff), which
    // left this screen blank on real devices. An id survives that the same
    // way every other order screen already fetches by id.
    final state = ref.watch(orderDetailProvider(widget.orderId));
    final order = state.order;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (order != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleStatus(order));
    }

    if (order == null) {
      return Scaffold(
        body: state.isLoading
            ? const FullPageLoader(message: 'Placing your order…')
            : ErrorStateWidget(
                failure: state.failure!,
                onRetry: () =>
                    ref.read(orderDetailProvider(widget.orderId).notifier).load(),
              ),
      );
    }

    final awaitingAcceptance = order.status == OrderStatus.created;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _continueShopping();
      },
      child: CelebrationEffect(
        child: Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [AppColors.backgroundDark, AppColors.backgroundDark]
                    : [AppColors.primary.withValues(alpha: 0.08), const Color(0xFFF4F5F7)],
                stops: const [0.0, 0.4],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 500),
                            transitionBuilder: (child, animation) => FadeTransition(
                              opacity: animation,
                              child: ScaleTransition(scale: animation, child: child),
                            ),
                            child: awaitingAcceptance
                                ? const _WaitingAnimation(key: ValueKey('waiting'))
                                : const _SuccessBadge(key: ValueKey('success')),
                          ),
                          const SizedBox(height: 24),
                          _StaggeredWidget(
                            animation: _getInterval(0.1, 0.4),
                            child: Text(
                              awaitingAcceptance ? 'Order placed!' : 'Order confirmed!',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : AppColors.textPrimaryLight,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _StaggeredWidget(
                            animation: _getInterval(0.2, 0.5),
                            child: Text(
                              awaitingAcceptance
                                  ? 'Waiting for seller confirmation...'
                                  : (order.etaMinutes != null
                                      ? 'Arriving in about ${order.etaMinutes} minutes'
                                      : 'Your order is being packed'),
                              style: TextStyle(
                                fontSize: 15,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 32),
                          _StaggeredWidget(
                            animation: _getInterval(0.3, 0.6),
                            child: _OrderInfoCard(order: order),
                          ),
                          if (order.lines.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _StaggeredWidget(
                              animation: _getInterval(0.4, 0.7),
                              child: _ItemsCard(order: order),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  _StaggeredWidget(
                    animation: _getInterval(0.5, 0.8),
                    beginOffset: 0.5,
                    child: _BottomActions(
                      onContinue: _continueShopping,
                      onTrack: () => _trackOrder(order.id),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StaggeredWidget extends StatelessWidget {
  final Widget child;
  final Animation<double> animation;
  final double beginOffset;

  const _StaggeredWidget({
    required this.child,
    required this.animation,
    this.beginOffset = 30.0,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final opacity = animation.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, beginOffset * (1 - opacity)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Looping ring while the order sits with the seller, unanswered.
class _WaitingAnimation extends StatefulWidget {
  const _WaitingAnimation({super.key});

  @override
  State<_WaitingAnimation> createState() => _WaitingAnimationState();
}

class _WaitingAnimationState extends State<_WaitingAnimation> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 100,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 0; i < 3; i++)
                Builder(
                  builder: (context) {
                    final t = (_controller.value + i / 3) % 1.0;
                    final scale = 0.4 + t * 0.6;
                    final opacity = (1 - t).clamp(0.0, 1.0);
                    return Opacity(
                      opacity: opacity,
                      child: Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.5),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.shopping_basket_rounded, color: Colors.white, size: 34),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SuccessBadge extends StatelessWidget {
  const _SuccessBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.elasticOut,
      builder: (_, t, _) {
        return Transform.scale(
          scale: t,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12 * t.clamp(0.0, 1.0)),
              shape: BoxShape.circle,
              boxShadow: [
                if (t > 0.8)
                  BoxShadow(
                    color: AppColors.success.withValues(alpha: 0.3 * (t - 0.8).clamp(0.0, 1.0)),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
              ],
            ),
            child: Center(
              child: Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 40),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OrderInfoCard extends StatelessWidget {
  final Order order;
  const _OrderInfoCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      _row(context, Icons.receipt_long_outlined, 'Order ID', '#${order.displayId}'),
      if (order.sellerName.isNotEmpty)
        _row(context, Icons.storefront_outlined, 'Seller', order.sellerName),
      _row(context, Icons.payments_outlined, 'Payment', order.paymentMethod.label),
      if (order.address != null && order.address!.fullLine.isNotEmpty)
        _row(context, Icons.location_on_outlined, 'Delivering to', order.address!.fullLine),
    ];
    return FoodStyleCard(padding: const EdgeInsets.all(20), child: Column(children: rows));
  }

  Widget _row(BuildContext context, IconData icon, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final secondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: secondary)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemsCard extends StatelessWidget {
  final Order order;
  const _ItemsCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final secondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final pricing = order.pricing;

    return FoodStyleCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOUR ORDER',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: secondary,
            ),
          ),
          const SizedBox(height: 16),
          for (final item in order.lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${item.quantity}×',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.variantName.isEmpty ? item.name : '${item.name} (${item.variantName})',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
                    ),
                  ),
                  Text(
                    item.lineTotal.asCurrency,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
                  ),
                ],
              ),
            ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
          Text('Bill Details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: textColor)),
          const SizedBox(height: 12),
          _billRow('Item Total', pricing.subtotal.asCurrency, textColor, secondary),
          if (pricing.packagingFee > 0)
            _billRow('Packing Charges', pricing.packagingFee.asCurrency, textColor, secondary),
          if (pricing.deliveryFee > 0)
            _billRow('Delivery Fee', pricing.deliveryFee.asCurrency, textColor, secondary),
          if (pricing.platformFee > 0)
            _billRow('Platform Fee', pricing.platformFee.asCurrency, textColor, secondary),
          if (pricing.tax > 0) _billRow('GST', pricing.tax.asCurrency, textColor, secondary),
          if (pricing.deliveryFeeGst > 0)
            _billRow('Delivery Taxes', pricing.deliveryFeeGst.asCurrency, textColor, secondary),
          if (pricing.discount > 0)
            _billRow(
              pricing.couponCode == null ? 'Discount' : 'Coupon Discount',
              '-${pricing.discount.asCurrency}',
              AppColors.success,
              secondary,
            ),
          if (pricing.deliveryTip > 0)
            _billRow('Tip', pricing.deliveryTip.asCurrency, textColor, secondary),
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Paid', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
              Text(
                pricing.total.asCurrency,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _billRow(String label, String value, Color valueColor, Color labelColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: labelColor)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: valueColor)),
        ],
      ),
    );
  }
}

class _PulseButton extends StatefulWidget {
  final Widget child;
  const _PulseButton({required this.child});

  @override
  State<_PulseButton> createState() => _PulseButtonState();
}

class _PulseButtonState extends State<_PulseButton> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) => Transform.scale(scale: 1.0 + (_ctrl.value * 0.03), child: child),
      child: widget.child,
    );
  }
}

class _BottomActions extends StatelessWidget {
  final VoidCallback onContinue;
  final VoidCallback onTrack;
  const _BottomActions({required this.onContinue, required this.onTrack});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : AppColors.shadow1,
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: onContinue,
              child: Text(
                'Continue Shopping',
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _PulseButton(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 4,
                  shadowColor: AppColors.primary.withValues(alpha: 0.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: onTrack,
                child: const Text(
                  'Track Order',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
