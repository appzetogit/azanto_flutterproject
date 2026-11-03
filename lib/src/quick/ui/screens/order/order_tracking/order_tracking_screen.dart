import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../presentation/branding/app_colors.dart';
import '../../../../../shared/ui/food_style_card.dart';
import '../../../../core/extensions/num_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../domain/model/order.dart';
import '../../../../navigation/route_paths.dart';
import '../../../common/widgets/buttons/primary_button.dart';
import '../../../common/widgets/buttons/secondary_button.dart';
import '../../../common/widgets/feedback/app_toast.dart';
import '../../../common/widgets/loaders/full_page_loader.dart';
import '../../../common/widgets/maps/order_route_map.dart';
import '../../../common/widgets/misc/rating_stars.dart';
import '../../../common/widgets/states/error_state_widget.dart';
import '../../chat/chat_screen.dart';
import '../order_details/order_details_provider.dart';
import '../widgets/order_status_chip.dart';
import 'widgets/tracking_timeline.dart';

/// Live order tracking. Polls the order endpoint while the order is in flight.
class OrderTrackingScreen extends ConsumerWidget {
  const OrderTrackingScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(orderDetailProvider(orderId).select((s) => (
          order: s.order,
          status: s.order?.status,
          eta: s.order?.etaMinutes,
          hasRider: s.order?.deliveryPartner != null,
          dropOtp: s.dropOtp,
          isLoading: s.isLoading,
          failure: s.failure,
        )));
    final order = view.order;

    if (view.isLoading && order == null) {
      return const Scaffold(
        body: FullPageLoader(message: 'Fetching your order…'),
      );
    }
    if (order == null) {
      return Scaffold(
        appBar: AppBar(),
        body: ErrorStateWidget(
          failure: view.failure!,
          onRetry: () => ref.read(orderDetailProvider(orderId).notifier).load(),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(RoutePaths.home);
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF4F5F7),
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(
            'Order ${order.displayId}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          actions: [
            OrderStatusChip(status: order.status),
            const SizedBox(width: AppSpacing.lg),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
            children: [
              _LiveStatusBanner(order: order),
              _TrackingMap(orderId: orderId),
              if (order.status.isOutForDelivery && view.dropOtp.isNotEmpty)
                _DropOtpCard(otp: view.dropOtp),
              if (order.deliveryPartner != null)
                _RiderCard(partner: order.deliveryPartner!, orderId: order.id),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter, vertical: AppSpacing.sm),
                child: FoodStyleCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Live Order Status',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TrackingTimeline(order: order),
                    ],
                  ),
                ),
              ),
              _OrderSummaryCard(order: order),
              const SizedBox(height: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
                child: PrimaryButton(
                  label: 'Need help with this order?',
                  icon: Icons.support_agent_rounded,
                  onPressed: () => context.push(RoutePaths.help),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
                child: SecondaryButton(
                  label: 'View full order details',
                  icon: Icons.receipt_long_rounded,
                  expand: true,
                  onPressed: () =>
                      context.push(RoutePaths.orderDetailsOf(order.id)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The live map, isolated so it is the only thing that rebuilds on a rider GPS ping.
class _TrackingMap extends ConsumerWidget {
  const _TrackingMap({required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = orderDetailProvider(orderId);
    final route = ref.watch(provider.select((s) => s.route));
    final riderLocation = ref.watch(provider.select((s) => s.riderLocation));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter, vertical: AppSpacing.xs),
      child: FoodStyleCard(
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            height: 220,
            child: OrderRouteMap(route: route, riderLocation: riderLocation),
          ),
        ),
      ),
    );
  }
}

/// Gradient banner + pulsing status icon & live ETA at top.
class _LiveStatusBanner extends StatefulWidget {
  const _LiveStatusBanner({required this.order});

  final Order order;

  @override
  State<_LiveStatusBanner> createState() => _LiveStatusBannerState();
}

class _LiveStatusBannerState extends State<_LiveStatusBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final live = order.status.isActive;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.sm,
        AppSpacing.gutter,
        AppSpacing.xs,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          RepaintBoundary(
            child: ScaleTransition(
              scale: Tween(begin: 0.92, end: 1.08).animate(
                CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
              ),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  live ? Icons.delivery_dining_rounded : Icons.check_circle_rounded,
                  size: 28,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.status.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  live
                      ? order.etaMinutes != null
                          ? 'Arriving in about ${order.etaMinutes} minutes'
                          : 'Preparing your order'
                      : 'Order completed · Thank you!',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DropOtpCard extends StatelessWidget {
  const _DropOtpCard({required this.otp});

  final String otp;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter, vertical: AppSpacing.xs),
      child: FoodStyleCard(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.lock_rounded,
                color: Color(0xFFD97706),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Delivery OTP',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Share code with rider at door',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: otp
                  .split('')
                  .map(
                    (digit) => Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        digit,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _RiderCard extends StatelessWidget {
  const _RiderCard({required this.partner, required this.orderId});

  final DeliveryPartner partner;
  final String orderId;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter, vertical: AppSpacing.xs),
      child: FoodStyleCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              child: Icon(Icons.person_rounded, color: AppColors.primary, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    partner.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (partner.rating > 0) ...[
                        RatingStars(rating: partner.rating, size: 11),
                        const SizedBox(width: 6),
                      ],
                      if (partner.vehicleNumber.isNotEmpty)
                        Text(
                          partner.vehicleNumber,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            _RiderAction(
              icon: Icons.call_rounded,
              label: 'Call',
              onTap: partner.phone.trim().isEmpty
                  ? null
                  : () => _callRider(context, partner.phone),
            ),
            const SizedBox(width: 8),
            _RiderAction(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'Message',
              onTap: () => context.push(
                RoutePaths.orderChatOf(orderId),
                extra: ChatArgs(riderName: partner.name),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _callRider(BuildContext context, String rawPhone) async {
    final cleaned = rawPhone.trim();
    final digits = cleaned.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.replaceAll('+', '').isEmpty) {
      AppToast.error(context, 'No phone number for this rider yet');
      return;
    }

    final uri = Uri(scheme: 'tel', path: digits);
    try {
      final launched = await launchUrl(uri);
      if (!launched && context.mounted) {
        AppToast.error(context, 'Could not open the dialer');
      }
    } catch (_) {
      if (context.mounted) AppToast.error(context, 'Could not open the dialer');
    }
  }
}

class _RiderAction extends StatelessWidget {
  const _RiderAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
      ),
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter, vertical: AppSpacing.xs),
      child: FoodStyleCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.shopping_bag_outlined,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Order Summary',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (order.lines.isNotEmpty) ...[
              for (final item in order.lines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        '${item.quantity}x',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        item.lineTotal.asCurrency,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Divider(color: isDark ? AppColors.borderDark : const Color(0xFFF1F5F9)),
              const SizedBox(height: 12),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Paid via ${order.paymentMethod.label}',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                Text(
                  order.pricing.total.asCurrency,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
