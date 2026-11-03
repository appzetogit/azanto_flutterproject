import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../domain/model/product.dart';
import '../../../../../presentation/branding/app_colors.dart';
import '../../../common/cart_actions.dart';
import '../../../common/widgets/misc/app_network_image.dart';
import '../../../../../shared/widgets/drifting_rail.dart';
import 'bouncing_heading.dart';

/// "LOWEST PRICES EVER" section rail:
///
/// - Section Background: Uses active default app theme color tint ([AppColors.primaryTint]).
/// - Heading Animation: Continuous floating/popping loop with [BouncingHeading].
/// - Image Area: Full coverage image ([BoxFit.cover]) with zero empty white margin around it.
/// - Ultra-Compact Card Dimensions: Reduced card width (132) & height (228) for maximum space efficiency.
/// - Product Card Layout:
///   - Top Half: 95px image container box completely covered by product image.
///   - Top-Left: Red discount pill badge ("20% OFF", "17% OFF").
///   - Top-Right: Compact circular Wishlist heart button.
///   - Floating "ADD" Button: Compact bordered button in active theme color.
///   - Bottom Half: Streamlined details section with rating, ETA, price, and "See more like this ▶" pill.
/// - Product Sorting: Lowest-priced products displayed first!
class LowestPricesEverRow extends ConsumerWidget {
  const LowestPricesEverRow({
    super.key,
    required this.products,
    required this.onProductTap,
  });

  final List<Product> products;
  final void Function(Product) onProductTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (products.isEmpty) return const SizedBox.shrink();

    // Sort products by price ascending (lowest price first)
    final sortedProducts = List<Product>.from(products)
      ..sort((a, b) => a.price.compareTo(b.price));

    final primaryTint = AppColors.primaryTint;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: primaryTint, // Dynamic default app theme background tint
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TITLE HEADER: "— LOWEST PRICES EVER —" (ANIMATED BOUNCING HEADING)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 20,
                  height: 1.5,
                  color: const Color(0xFF9CA3AF),
                ),
                const SizedBox(width: 8),
                // Flexible so the rules give way instead of the row overflowing.
                // The heading's width depends on the font that actually loads
                // and on the system text size, so a fixed layout only fits at
                // the default of both.
                Flexible(
                  child: BouncingHeading(
                    text: 'LOWEST PRICES EVER',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      letterSpacing: 0.5,
                      color: const Color(0xFF111827),
                      shadows: const [
                        Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 2,
                          color: Colors.black12,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 20,
                  height: 1.5,
                  color: const Color(0xFF9CA3AF),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // HORIZONTAL PRODUCT CAROUSEL RAIL (ULTRA-COMPACT HEIGHT 228)
          SizedBox(
            height: 228,
            child: DriftingRail(
              itemCount: sortedProducts.length,
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) => _LowestPriceCard(
                product: sortedProducts[i],
                onTap: () => onProductTap(sortedProducts[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LowestPriceCard extends ConsumerStatefulWidget {
  const _LowestPriceCard({required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  ConsumerState<_LowestPriceCard> createState() => _LowestPriceCardState();
}

class _LowestPriceCardState extends ConsumerState<_LowestPriceCard> {
  final _imageKey = GlobalKey();
  bool _isFavorite = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final strike = p.strikePrice;
    final discount = p.discountPercent;
    final primaryColor = AppColors.primary;
    final primaryTintStrong = AppColors.primaryTintStrong;

    final packSizeStr = p.packSize.trim().isNotEmpty
        ? p.packSize.trim()
        : '40 g';

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 132, // Compact width to fit multiple cards on screen
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primaryTintStrong, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TOP IMAGE CONTAINER: FULL COVERAGE PRODUCT IMAGE (BoxFit.cover)
            SizedBox(
              height: 95,
              child: Stack(
                children: [
                  // Full coverage product image with no white margins
                  Positioned.fill(
                    child: AppNetworkImage(
                      key: _imageKey,
                      url: p.imageUrl,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),

                  // Top Left Discount Red Pill Badge — only for a real markdown.
                  if (p.isDiscounted)
                    Positioned(
                      left: 5,
                      top: 5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$discount% OFF',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 8,
                          ),
                        ),
                      ),
                    ),

                  // Top Right White Wishlist Heart Button
                  Positioned(
                    right: 5,
                    top: 5,
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _isFavorite = !_isFavorite);
                      },
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          _isFavorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 12,
                          color: _isFavorite
                              ? Colors.red
                              : const Color(0xFF374151),
                        ),
                      ),
                    ),
                  ),

                  // Floating "ADD" Button (Bottom Right of Image Container)
                  Positioned(
                    right: 5,
                    bottom: 4,
                    child: GestureDetector(
                      onTap: p.isPurchasable
                          ? () => CartActions.add(
                              context,
                              ref,
                              product: p,
                              sourceKey: _imageKey,
                            )
                          : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: primaryColor, width: 1.6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Text(
                          p.isPurchasable ? 'ADD' : 'OUT',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w900,
                            fontSize: 9.5,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // BOTTOM DETAILS SECTION (COMPACT & READABLE)
            Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // GRAMMAGE / PACK SIZE CHIP
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      packSizeStr,
                      style: GoogleFonts.inter(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF4B5563),
                      ),
                    ),
                  ),

                  const SizedBox(height: 3),

                  // PRODUCT TITLE
                  Text(
                    p.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      height: 1.15,
                      color: const Color(0xFF111827),
                    ),
                  ),

                  const SizedBox(height: 2),

                  // RATING & ETA ROW
                  Row(
                    children: [
                      // The rating is the product's own. It was a hardcoded
                      // "4.5 (85)", so every card on the row claimed the same
                      // 85 reviews — including products nobody has rated. An
                      // unrated product shows no stars rather than borrowed ones.
                      if (p.rating > 0) ...[
                        const Icon(
                          Icons.star_rounded,
                          size: 10,
                          color: Color(0xFFFFB800),
                        ),
                        const SizedBox(width: 1.5),
                        Flexible(
                          child: Text(
                            p.ratingCount > 0
                                ? '${p.rating.toStringAsFixed(1)} (${p.ratingCount})'
                                : p.rating.toStringAsFixed(1),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                        ),
                        Text(
                          ' • ',
                          style: GoogleFonts.inter(
                            fontSize: 8.5,
                            color: const Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                      Text(
                        '${p.deliveryMinutes ?? 20}m',
                        style: GoogleFonts.inter(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF4B5563),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 3),

                  // PRICE & DISCOUNT ROW
                  Row(
                    children: [
                      Text(
                        '₹${p.price.toStringAsFixed(0)}',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      if (p.isDiscounted) ...[
                        const SizedBox(width: 3),
                        Text(
                          '₹${strike!.toStringAsFixed(0)}',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            decoration: TextDecoration.lineThrough,
                            color: const Color(0xFF9CA3AF),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '$discount%',
                          style: GoogleFonts.inter(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 5),

                  // BOTTOM ACTION PILL: "See more like this ▶"
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: primaryTintStrong,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'See more like this',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryDeepText,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.play_arrow_rounded,
                          size: 10,
                          color: primaryColor,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
