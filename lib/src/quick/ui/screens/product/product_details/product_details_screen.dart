import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_colors.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/extensions/num_extensions.dart';
import '../../../../core/network/share_links.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../di/app_providers.dart';
import '../../../../di/service_providers.dart';

import '../../../../domain/model/product.dart';
import '../../../../domain/model/product_variant.dart';
import '../../../../navigation/route_paths.dart';
import '../../../common/cart_actions.dart';
import '../../../common/widgets/feedback/app_toast.dart';
import '../../../common/widgets/badges/delivery_time_badge.dart';
import '../../../common/widgets/loaders/full_page_loader.dart';
import '../../../common/widgets/misc/quantity_stepper.dart';
import '../../../common/widgets/misc/section_header.dart';
import '../../../common/widgets/states/error_state_widget.dart';
import '../../home/widgets/product_row.dart';
import '../product_listing/product_listing_args.dart';
import 'product_details_provider.dart';
import 'product_details_state.dart';
import 'widgets/product_image_carousel.dart';
import 'widgets/reviews_section.dart';
import 'widgets/write_review_sheet.dart';
import '../../../common/widgets/misc/mart_view_cart_bar.dart';
import '../../../../../presentation/cart/widgets/floating_view_cart_bar.dart';

class ProductDetailsScreen extends ConsumerStatefulWidget {
  const ProductDetailsScreen({
    super.key,
    required this.productId,
    this.product,
    this.heroTag,
  });

  final String productId;
  final Product? product;
  final String? heroTag;

  @override
  ConsumerState<ProductDetailsScreen> createState() =>
      _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends ConsumerState<ProductDetailsScreen> {
  late final ProductDetailsArgs _args = ProductDetailsArgs(
    productId: widget.productId,
    product: widget.product,
  );

  final _imageKey = GlobalKey();

  Future<void> _addToCart(ProductDetailsState state) async {
    final product = state.product;
    if (product == null) return;

    await CartActions.add(
      context,
      ref,
      product: product,
      variant: state.selectedVariant,
      addons: state.selectedAddons,
      quantity: state.quantity,
      sourceKey: _imageKey,
      askForAddons: false,
    );
  }

  Future<void> _writeReview(ProductDetailsState state) async {
    final product = state.product;
    if (product == null) return;

    final draft = await WriteReviewSheet.show(
      context,
      productName: product.name,
      orders: state.rateableOrders,
    );
    if (draft == null || !mounted) return;

    try {
      await ref
          .read(productDetailsProvider(_args).notifier)
          .submitReview(
            orderId: draft.orderId,
            rating: draft.rating,
            comment: draft.comment,
          );
      if (mounted) {
        AppToast.success(context, 'Thanks for your review');
      }
    } catch (_) {
      if (mounted) {
        AppToast.error(context, 'Could not submit your review');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productDetailsProvider(_args));

    if (state.isLoading && state.product == null) {
      return const Scaffold(body: FullPageLoader(message: 'Loading product…'));
    }

    final product = state.product;
    if (product == null) {
      return Scaffold(
        appBar: AppBar(),
        body: ErrorStateWidget(
          failure:
              state.failure ??
              const NotFoundFailure(
                'We could not load this product right now.',
              ),
          onRetry: () =>
              ref.read(productDetailsProvider(_args).notifier).load(),
        ),
      );
    }

    final inCartQuantity = ref.watch(
      cartProvider.select((s) => s.cart.quantityOf(product.id)),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      // The same "N items · ₹X — View cart" bar every browsing screen carries,
      // sitting above this screen's add-to-cart bar. It hides itself while the
      // cart is empty, so it appears the moment something is added — the route
      // to the cart used to disappear the instant you opened a product.
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StickyBottomBar(
            state: state,
            inCartQuantity: inCartQuantity,
            onAdd: () => _addToCart(state),
            onViewCart: () => context.go(RoutePaths.cart),
            onSelectVariant: (v) => ref
                .read(productDetailsProvider(_args).notifier)
                .selectVariant(v),
          ),
        ],
      ),
      body: Stack(
        // The bar sits on the window edge; a clipping Stack would
        // shave its shadow and its lower corners.
        clipBehavior: Clip.none,
        children: [
          CustomScrollView(
            slivers: [
              // 1. Top header: storefront name, delivery estimate, action buttons.
              _buildTopHeader(context, product, state),

              // 2. Product Image Gallery Section
              SliverToBoxAdapter(
                child: _buildImageGallerySection(context, product),
              ),

              // 3. Delivery Time & Rating Banner Card
              SliverToBoxAdapter(
                child: _buildDeliveryAndRatingCard(context, product),
              ),

              // 4. Product Name, Unit Subtitle & Select Unit Grid
              SliverToBoxAdapter(
                child: _buildProductTitleAndVariants(context, state),
              ),

              // 5. Pricing & Discount Row
              SliverToBoxAdapter(child: _buildPricingRow(context, state)),

              // 6. View Product Details Accordion
              SliverToBoxAdapter(
                child: _buildViewProductDetailsAccordion(context, product),
              ),

              // 8. Reviews & Ratings Section
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(title: 'Ratings & reviews'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: ReviewsSection(
                        summary: state.ratingSummary,
                        reviews: state.reviews,
                        canWrite: state.canRate,
                        onWrite: () => _writeReview(state),
                      ),
                    ),
                  ],
                ),
              ),

              // 9. Similar Products Horizontal Strip
              if (state.related.isNotEmpty)
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(
                        title: 'Similar products',
                        onSeeAll: () => context.push(
                          RoutePaths.productListing,
                          extra: ProductListingArgs(
                            title: 'Similar Products',
                            categoryId: product.categoryId,
                          ),
                        ),
                      ),
                      ProductRow(
                        products: state.related,
                        heroTag: 'related-${product.id}',
                        onProductTap: (p) => context.push(
                          RoutePaths.productDetailsOf(p.id),
                          extra: p,
                        ),
                      ),
                    ],
                  ),
                ),

              // Clears the floating cart bar, which overlays the last
              // section rather than pushing it up. Same raise the bar uses.
              SliverToBoxAdapter(
                child: SizedBox(
                  height: FloatingViewCartBar.reservedBottomSpace(
                    context,
                    bottomOffset: 108.0,
                  ),
                ),
              ),
            ],
          ),
          // Raised so it floats clear of _StickyBottomBar, the same reason
          // Food Details raises it.
          const MartViewCartBar(bottomOffset: 108.0),
        ],
      ),
    );
  }

  // 1. Top header: storefront name, delivery estimate, action buttons.
  Widget _buildTopHeader(
    BuildContext context,
    Product product,
    ProductDetailsState state,
  ) {
    final isWishlisted = ref.watch(isWishlistedProvider(product.id));

    return SliverAppBar(
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: context.colors.surface,
      toolbarHeight: 56,
      automaticallyImplyLeading: false,
      titleSpacing: 12,
      title: Row(
        children: [
          // Left: Back button card
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.arrow_back_rounded,
                size: 20,
                color: context.colors.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Centre: the storefront, from the admin panel.
          //
          // This was a hardcoded 'appzeto' wordmark over 'Groceries in 10 Mins'
          // — the wrong brand entirely, and a delivery promise no store had
          // made. Both now come from the same places the home header reads.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Scaled down rather than clipped: at a fixed 25px the action
                // buttons left too little room and the brand rendered as
                // "Hiber…", which reads as a broken string rather than a name.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    ref.watch(storeNameProvider).value ?? '',
                    maxLines: 1,
                    style: context.text.displaySmall!.copyWith(
                      fontWeight: FontWeight.w900,
                      color: context.colors.onSurface,
                      fontSize: 25,
                      letterSpacing: -0.5,
                      height: 1.0,
                    ),
                  ),
                ),
                if (product.deliveryMinutes != null)
                  Text(
                    'Groceries in ${product.deliveryMinutes} Mins',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelSmall!.copyWith(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF6B7280),
                      height: 1.1,
                    ),
                  ),
              ],
            ),
          ),
          const Spacer(),
          // Right action cards: Search | Wishlist | Share
          _headerActionBtn(
            icon: Icons.search_rounded,
            onTap: () => context.push(RoutePaths.search),
          ),
          const SizedBox(width: 6),
          _headerActionBtn(
            icon: isWishlisted
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            iconColor: isWishlisted
                ? Color(0xFFEF4444)
                : context.colors.onSurface,
            onTap: () => CartActions.toggleWishlist(context, ref, product),
          ),
          const SizedBox(width: 6),
          _headerActionBtn(
            icon: Icons.share_outlined,
            onTap: () => SharePlus.instance.share(
              ShareParams(
                text:
                    '${product.name} on Azanto — ${product.price.asCurrency}\n'
                    '${ShareLinks.product(productId: product.id, sellerId: product.sellerId)}',
                subject: product.name,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerActionBtn({
    required IconData icon,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 19,
          color: iconColor ?? context.colors.onSurface,
        ),
      ),
    );
  }

  // 2. Product Image Gallery Section
  Widget _buildImageGallerySection(BuildContext context, Product product) {
    final images = product.gallery.isNotEmpty
        ? product.gallery
        : [product.imageUrl];

    return Container(
      color: context.colors.surface,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Stack(
        children: [
          // Gallery Carousel
          ProductImageCarousel(
            images: images,
            heroTag: '${widget.heroTag ?? 'product'}-${product.id}',
            height: 220,
            desaturated: !product.isPurchasable,
          ),
          // Veg Indicator Badge on top left
          Positioned(
            left: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: VegIndicator(isVeg: product.isVeg),
            ),
          ),
        ],
      ),
    );
  }

  // 3. Delivery Time & Rating Banner Card
  Widget _buildDeliveryAndRatingCard(BuildContext context, Product product) {
    final address = ref.watch(selectedAddressProvider);
    final rating = product.rating;
    final ratingCount = product.ratingCount;
    final hasRating = rating > 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Scooter icon + Delivery text
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: context.semantic.brandSurfaceSoft,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.two_wheeler_rounded,
              size: 17,
              color: context.colors.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.deliveryMinutes != null
                      ? 'Delivered in ~${product.deliveryMinutes} mins'
                      : 'Delivery time at checkout',
                  style: context.text.titleSmall!.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: context.colors.onSurface,
                  ),
                ),
                const SizedBox(height: 1),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        address?.shortLine ?? 'Set your delivery address',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall!.copyWith(
                          fontSize: 10.5,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.location_on_outlined,
                      size: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Rating card — only when the product has been rated.
          if (hasRating)
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.rating,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.star_rounded,
                        size: 13,
                        color: context.colors.onSurface,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        rating.toStringAsFixed(1),
                        style: context.text.titleSmall!.copyWith(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          color: context.colors.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                if (ratingCount > 0) ...[
                  const SizedBox(width: 4),
                  Text(
                    '($ratingCount ${ratingCount == 1 ? 'review' : 'reviews'})',
                    style: context.text.bodySmall!.copyWith(
                      fontSize: 10,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  // 4. Product Name, Unit Subtitle & Select Unit Grid
  Widget _buildProductTitleAndVariants(
    BuildContext context,
    ProductDetailsState state,
  ) {
    final product = state.product!;
    final variants = product.variants.isNotEmpty
        ? product.variants
        : [
            ProductVariant(
              id: 'default',
              name: product.unitLabel,
              price: product.price,
              comparePrice: product.strikePrice,
            ),
          ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            product.name,
            style: context.text.titleLarge!.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 17,
              color: context.colors.onSurface,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 2),
          // Subtitle (e.g. 500 ml)
          Text(
            state.selectedVariant?.name ?? product.unitLabel,
            style: context.text.bodyMedium!.copyWith(
              fontSize: 12,
              color: const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          // Select Unit Section Header
          Text(
            'Select Unit',
            style: context.text.titleSmall!.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              color: context.colors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          // Variant Grid / Horizontal Row
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: variants.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final v = variants[index];
                final isSelected =
                    (state.selectedVariant?.id == v.id) ||
                    (state.selectedVariant == null && index == 0);

                return GestureDetector(
                  onTap: () {
                    AppHaptics.selection();
                    ref
                        .read(productDetailsProvider(_args).notifier)
                        .selectVariant(v);
                  },
                  child: Container(
                    width: 88,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? context.semantic.brandSurfaceSoft
                          : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? context.colors.primary
                            : const Color(0xFFE5E7EB),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          v.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleSmall!.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 11.5,
                            color: context.colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '₹${v.price.toInt()}',
                          style: context.text.bodySmall!.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 10.5,
                            color: context.colors.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 5. Pricing & Discount Row
  Widget _buildPricingRow(BuildContext context, ProductDetailsState state) {
    final product = state.product!;
    final isPurchasable = product.isPurchasable;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                state.effectiveUnitPrice.asCurrency,
                style: context.text.displaySmall!.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  color: context.colors.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              if (state.effectiveStrikePrice != null &&
                  state.effectiveStrikePrice! > state.effectiveUnitPrice) ...[
                Text(
                  'MRP ${state.effectiveStrikePrice!.asCurrency}',
                  style: context.text.bodyMedium!.copyWith(
                    decoration: TextDecoration.lineThrough,
                    color: const Color(0xFF9CA3AF),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: context.semantic.border,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    '${state.effectiveUnitPrice.discountPercentFrom(state.effectiveStrikePrice)}% OFF',
                    style: context.text.labelSmall!.copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: 9.5,
                      color: context.semantic.accent,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (!isPurchasable)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Out of stock',
                    style: context.text.labelSmall!.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFDC2626),
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 1),
          Text(
            'Inclusive of all taxes',
            style: context.text.bodySmall!.copyWith(
              fontSize: 10.5,
              color: const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  // 6. View Product Details Accordion
  Widget _buildViewProductDetailsAccordion(
    BuildContext context,
    Product product,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 2, 12, 4),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: context.theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          leading: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: context.semantic.border,
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.assignment_outlined,
              size: 14,
              color: context.colors.primary,
            ),
          ),
          title: Text(
            'View product details',
            style: context.text.titleSmall!.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
              color: context.colors.onSurface,
            ),
          ),
          trailing: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: context.colors.onSurface,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (product.description.trim().isNotEmpty) ...[
              Text(
                'Description',
                style: context.text.titleSmall!.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 11.5,
                  color: context.colors.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                product.description,
                style: context.text.bodySmall!.copyWith(
                  fontSize: 11,
                  color: const Color(0xFF4B5563),
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 6),
            ],
            _specRow('Brand', product.brand),
            _specRow('Pack size', product.packSize),
            _specRow('Category', product.categoryName),
            _specRow(
              'Food type',
              product.isVeg ? 'Vegetarian' : 'Non-vegetarian',
            ),
          ],
        ),
      ),
    );
  }

  Widget _specRow(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: context.colors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sticky bottom bar: quantity, live line price, and add/view-cart.
class _StickyBottomBar extends ConsumerWidget {
  const _StickyBottomBar({
    required this.state,
    required this.inCartQuantity,
    required this.onAdd,
    required this.onViewCart,
    required this.onSelectVariant,
  });

  final ProductDetailsState state;
  final int inCartQuantity;
  final VoidCallback onAdd;
  final VoidCallback onViewCart;
  final ValueChanged<ProductVariant> onSelectVariant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = state.product;
    if (product == null) return const SizedBox.shrink();

    final purchasable = product.isPurchasable && product.sellerAcceptingOrders;
    final selectedVariantName =
        state.selectedVariant?.name ?? product.unitLabel;

    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        6,
        12,
        6 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left: Variant Dropdown Pill
          GestureDetector(
            onTap: () {
              if (product.variants.isNotEmpty) {
                _showVariantPicker(
                  context,
                  product,
                  state.selectedVariant,
                  onSelectVariant,
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: context.semantic.brandSurfaceSoft,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.semantic.accent),
              ),
              child: Row(
                children: [
                  Text(
                    selectedVariantName,
                    style: context.text.titleSmall!.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 11.5,
                      color: context.colors.onSurface,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 15,
                    color: context.colors.onSurface,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Price Column
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                state.effectiveUnitPrice.asCurrency,
                style: context.text.titleLarge!.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  color: context.colors.onSurface,
                ),
              ),
              Text(
                'Inclusive of all taxes',
                style: context.text.bodySmall!.copyWith(
                  fontSize: 9,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          const Spacer(),
          // Add to Cart / Stepper Button
          if (!purchasable)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Out of stock',
                style: context.text.labelMedium!.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFDC2626),
                  fontSize: 12,
                ),
              ),
            )
          else if (inCartQuantity > 0)
            QuantityStepper(
              quantity: inCartQuantity,
              height: 38,
              canIncrement: true,
              onIncrement: onAdd,
              onDecrement: () => CartActions.decrement(ref, product),
            )
          else
            GestureDetector(
              onTap: () {
                AppHaptics.medium();
                onAdd();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: context.colors.primary,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: context.colors.primary.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.shopping_cart_outlined,
                      size: 16,
                      color: context.colors.onSurface,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Add to Cart',
                      style: context.text.titleSmall!.copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        color: context.colors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showVariantPicker(
    BuildContext context,
    Product product,
    ProductVariant? current,
    ValueChanged<ProductVariant> onSelect,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Unit',
                style: context.text.titleMedium!.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              for (final v in product.variants)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    v.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text('₹${v.price.toInt()}'),
                  trailing: current?.id == v.id
                      ? Icon(Icons.check_circle, color: context.semantic.accent)
                      : null,
                  onTap: () {
                    onSelect(v);
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
