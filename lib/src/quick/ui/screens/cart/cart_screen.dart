import 'package:flutter/material.dart';
import '../../../../shared/celebration/free_delivery_celebration.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../presentation/branding/app_colors.dart';
import '../../../../shared/address/global_address.dart';
import '../../../../shared/ui/food_style_card.dart';
import '../../../core/extensions/num_extensions.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../di/app_providers.dart';
import '../../../di/service_providers.dart';
import '../../../domain/model/product.dart';
import '../../../navigation/route_paths.dart';
import '../../common/widgets/cards/product_card.dart';
import '../../common/widgets/feedback/app_dialog.dart';
import '../../common/widgets/misc/section_header.dart';
import '../../common/widgets/states/empty_state_widget.dart';
import '../../common/widgets/states/offline_banner.dart';
import '../home/home_provider.dart';
import 'widgets/bill_details_card.dart';
import 'widgets/cart_line_tile.dart';
import '../../../../shared/celebration/coupon_celebration.dart';
import '../../../../shared/widgets/free_delivery_progress.dart';
import '../../../../shared/widgets/tip_your_driver_card.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key, this.showAppBar = true});

  /// The cart tab supplies its own chrome; the pushed route wants an app bar.
  final bool showAppBar;

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  /// Where the free-delivery bar sits, so the unlock celebration can scroll
  /// the page to it before showing its card.
  final GlobalKey _freeDeliveryKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final showAppBar = widget.showAppBar;
    final state = ref.watch(cartProvider);
    final cart = state.cart;
    final pricingService = ref.watch(cartPricingServiceProvider);

    if (cart.isEmpty) {
      return Scaffold(
        appBar: showAppBar ? AppBar(title: const Text('Your cart')) : null,
        body: SafeArea(
          child: EmptyStateWidget(
            icon: Icons.shopping_basket_outlined,
            title: 'Your cart is empty',
            message:
                'Add a few essentials and we will have them at your door in minutes.',
            actionLabel: 'Browse products',
            onAction: () => context.go(RoutePaths.home),
          ),
        ),
      );
    }

    final crossSell = _crossSell(ref, cart.items.map((i) => i.product.id).toSet());

    final spent = cart.pricing.subtotal > 0
        ? cart.pricing.subtotal
        : cart.provisionalSubtotal;
    final threshold = pricingService.freeDeliveryThreshold;
    // The backend now actually grants free delivery once subtotal crosses
    // this threshold (resolveUserDeliveryFee), so this bar's promise is real
    // again — celebrate it unconditionally, same as before.
    //
    // Driven from here rather than the bar itself: the bar is below the fold
    // in a lazily-built list, so on open it does not exist yet to notice
    // anything. Idempotent — it celebrates once per unlock, not per build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      celebrateFreeDeliveryUnlock(
        context,
        scope: 'quick',
        unlocked: spent >= threshold,
        threshold: threshold,
        sectionKey: _freeDeliveryKey,
      );
    });

    return Scaffold(
      appBar: showAppBar
          ? AppBar(
              title: const Text('Your cart'),
              actions: [
                TextButton(
                  onPressed: () => _confirmClear(context, ref),
                  child: Text(
                    'Clear',
                    style: context.text.labelMedium!
                        .copyWith(color: context.semantic.danger),
                  ),
                ),
              ],
            )
          : null,
      bottomNavigationBar: _CheckoutBar(
        total: cart.pricing.total > 0
            ? cart.pricing.total
            : cart.provisionalSubtotal,
        itemCount: cart.itemCount,
        isPricing: state.isPricing,
        onCheckout: () => context.push(RoutePaths.checkout),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          // Deep enough to build the free-delivery section on open. A lazy
          // list leaves it unbuilt below the fold, and an unbuilt bar cannot
          // scroll itself into view to celebrate.
          cacheExtent: 2000,
          children: [
            const OfflineBanner(),
            const _DeliveryAddressCard(),
            if (cart.priceChanges.isNotEmpty)
              _PriceChangeNotice(changes: cart.priceChanges),
            _SellerHeader(
              name: cart.sellerName,
              etaMinutes: cart.pricing.deliveryPromiseMinutes,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
              child: FoodStyleCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    for (final item in cart.items)
                      CartLineTile(
                        item: item,
                        onIncrement: () =>
                            ref.read(cartProvider.notifier).increment(item.lineId),
                        onDecrement: () =>
                            ref.read(cartProvider.notifier).decrement(item.lineId),
                        onRemove: () =>
                            ref.read(cartProvider.notifier).removeLine(item.lineId),
                        onTap: () => context.push(
                          RoutePaths.productDetailsOf(item.product.id),
                          extra: item.product,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (crossSell.isNotEmpty) ...[
              const SectionHeader(
                title: 'Add these to your order',
                subtitle: 'People often buy these together',
              ),
              SizedBox(
                height: 285,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
                  itemCount: crossSell.length,
                  separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
                  itemBuilder: (context, index) => ProductCard(
                    product: crossSell[index],
                    heroTag: 'cart-cross-sell',
                    onTap: () => context.push(
                      RoutePaths.productDetailsOf(crossSell[index].id),
                      extra: crossSell[index],
                    ),
                  ),
                ),
              ),
            ],

            // Below the recommendations, as in the reference: the shopper sees
            // what to add, then how much closer it takes them.
            FreeDeliveryProgress(
              key: _freeDeliveryKey,
              spent: spent,
              threshold: threshold,
              formatAmount: (amount) => amount.asCurrency,
              onTap: () => context.push(RoutePaths.coupons),
            ),

            const SizedBox(height: AppSpacing.lg),
            _CouponRow(
              appliedCode: cart.pricing.couponCode ?? cart.appliedCoupon?.code,
              discount: cart.pricing.discount,
              onApply: () => _openCoupons(context),
              onRemove: () => ref.read(cartProvider.notifier).removeCoupon(),
            ),

            const SizedBox(height: AppSpacing.xl),
            // Same card as the Food cart, one implementation shared by both —
            // Mart had no tip at all before this.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
              child: TipYourDriverCard(
                selected: cart.deliveryTip,
                presets: ref.watch(feeSettingsProvider).value?.tipPresets ??
                    kDefaultTipPresets,
                onSelect: (amount) =>
                    ref.read(cartProvider.notifier).setDeliveryTip(amount),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
              child: BillDetailsCard(
                lines: pricingService.billLines(cart),
                savings: cart.totalSavings,
                isPricing: state.isPricing,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Cross-sell drawn from home's already-fetched catalog — no extra request.
  List<Product> _crossSell(WidgetRef ref, Set<String> inCart) {
    final sections = ref.watch(homeProvider).sections;
    final seen = <String>{};
    final suggestions = <Product>[];

    for (final section in sections) {
      for (final product in section.products) {
        if (inCart.contains(product.id) || !seen.add(product.id)) continue;
        if (!product.isPurchasable) continue;
        suggestions.add(product);
        if (suggestions.length == 10) return suggestions;
      }
    }
    return suggestions;
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await AppDialog.confirm(
      context,
      icon: Icons.remove_shopping_cart_outlined,
      title: 'Clear your cart?',
      message: 'This removes everything you have added so far.',
      confirmLabel: 'Clear cart',
      destructive: true,
    );
    if (confirmed) await ref.read(cartProvider.notifier).clear();
  }
  /// Opens the coupon picker and, if one was accepted, celebrates here — on the
  /// cart, which is where the user lands and where the new total is visible.
  Future<void> _openCoupons(BuildContext context) async {
    final win = await context.push<Object?>(RoutePaths.coupons);
    if (win is! CouponWin || !context.mounted) return;
    await showCouponCelebration(
      context,
      code: win.code,
      savings: win.savings,
    );
  }
}

class _DeliveryAddressCard extends ConsumerWidget {
  const _DeliveryAddressCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final address = ref.watch(globalSelectedAddressProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter, vertical: AppSpacing.xs),
      child: FoodStyleCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.location_on_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    address != null && address.title.isNotEmpty
                        ? 'Deliver to ${address.title}'
                        : 'Delivery Address',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    address != null && address.fullAddress.isNotEmpty
                        ? address.fullAddress
                        : 'Select address to see delivery availability',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => context.push(RoutePaths.addresses),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
              ),
              child: Text(
                'Change',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SellerHeader extends StatelessWidget {
  const _SellerHeader({required this.name, this.etaMinutes});

  final String name;
  final int? etaMinutes;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.sm,
        AppSpacing.gutter,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.storefront_rounded, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              name.isEmpty ? 'Your Mart Order' : name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
          ),
          // A promise of "0 mins" is the server saying it could not estimate —
          // it returns 0, not null, when the cart has no distance to work from
          // yet. Printing it promises an instant delivery; showing nothing is
          // honest, and the badge reappears the moment pricing returns a real
          // figure.
          if ((etaMinutes ?? 0) > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer_outlined, size: 13, color: Color(0xFF059669)),
                  const SizedBox(width: 4),
                  Text(
                    etaMinutes!.asDurationLabel,
                    style: const TextStyle(
                      color: Color(0xFF059669),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
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

class _PriceChangeNotice extends StatelessWidget {
  const _PriceChangeNotice({required this.changes});

  final List changes;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.semantic.dangerSoft,
        borderRadius: AppRadii.rMd,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_rounded, size: 18, color: context.semantic.danger),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              '${changes.length} ${changes.length == 1 ? 'price has' : 'prices have'} '
              'changed since you added them. The bill below is current.',
              style: context.text.labelMedium!
                  .copyWith(color: context.semantic.danger),
            ),
          ),
        ],
      ),
    );
  }

}

class _CouponRow extends StatelessWidget {
  const _CouponRow({
    required this.appliedCode,
    required this.discount,
    required this.onApply,
    required this.onRemove,
  });

  final String? appliedCode;
  final double discount;
  final VoidCallback onApply;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final applied = appliedCode != null && appliedCode!.isNotEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: FoodStyleCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: applied ? const Color(0xFF10B981) : AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.local_offer_rounded,
                size: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: applied
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$appliedCode applied',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF059669),
                          ),
                        ),
                        Text(
                          'You saved ${discount.asCurrency}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      'Apply a coupon',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14.5,
                        color: isDark ? Colors.white : AppColors.textPrimaryLight,
                      ),
                    ),
            ),
            if (applied)
              TextButton(
                onPressed: onRemove,
                child: const Text(
                  'Remove',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              )
            else
              TextButton(
                onPressed: onApply,
                child: Text(
                  'View offers',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Sticky checkout bar with Food style theme.
class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({
    required this.total,
    required this.itemCount,
    required this.isPricing,
    required this.onCheckout,
  });

  final double total;
  final int itemCount;
  final bool isPricing;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md + MediaQuery.viewPaddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: isDark ? AppColors.borderDark : const Color(0xFFF3F4F6))),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  total.asCurrency,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: isPricing ? null : onCheckout,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'Proceed to Checkout',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
