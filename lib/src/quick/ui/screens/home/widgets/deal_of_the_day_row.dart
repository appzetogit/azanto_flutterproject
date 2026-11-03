import '../../../../core/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../domain/model/product.dart';
import '../../../common/cart_actions.dart';
import '../../../common/widgets/misc/app_network_image.dart';

/// "Deal of the day" — the discount rail, in the compact card style with a
/// full-width ADD TO CART action.
///
/// Products come straight from the home state's discount section; the % badge,
/// strike price and pack size are the product's own backend values, so a card
/// with no real discount simply shows no badge rather than inventing one.
class DealOfTheDayRow extends ConsumerWidget {
  const DealOfTheDayRow({
    super.key,
    required this.products,
    required this.onSeeAll,
    required this.onProductTap,
  });

  final List<Product> products;
  final VoidCallback onSeeAll;
  final void Function(Product) onProductTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (products.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(AppSpacing.gutter, 2, AppSpacing.gutter, 2),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'DEAL OF THE DAY',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    letterSpacing: 0.3,
                    color: context.colors.onSurface,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onSeeAll,
                child: Row(
                  children: [
                    Text(
                      'View all deals',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: context.semantic.accent,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: context.semantic.accent,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
            itemCount: products.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) => _DealCard(
              product: products[i],
              onTap: () => onProductTap(products[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _DealCard extends ConsumerStatefulWidget {
  const _DealCard({required this.product, required this.onTap});
  final Product product;
  final VoidCallback onTap;

  @override
  ConsumerState<_DealCard> createState() => _DealCardState();
}

class _DealCardState extends ConsumerState<_DealCard> {
  // Flight origin for the add-to-cart animation
  final _imageKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final strike = p.strikePrice;
    final discount = p.discountPercent;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 138,
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Center(
                  child: Container(
                    height: 86,
                    alignment: Alignment.center,
                    child: AppNetworkImage(
                      key: _imageKey,
                      url: p.imageUrl,
                      width: 96,
                      height: 80,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                // Top Left Discount Badge Tag — only for a real markdown.
                if (p.isDiscounted)
                  Positioned(
                    left: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: context.semantic.accent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$discount% OFF',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 8.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              p.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
                color: context.colors.onSurface,
              ),
            ),
            Text(
              p.packSize.isNotEmpty ? p.packSize : '1 kg',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '₹${p.price.toStringAsFixed(0)}',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: context.colors.onSurface,
                  ),
                ),
                if (p.isDiscounted) ...[
                  const SizedBox(width: 4),
                  Text(
                    '₹${strike!.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      decoration: TextDecoration.lineThrough,
                      color: const Color(0xFF9CA3AF),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 30,
              child: OutlinedButton(
                onPressed: p.isPurchasable
                    ? () => CartActions.add(
                          context,
                          ref,
                          product: p,
                          sourceKey: _imageKey,
                        )
                    : null,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  foregroundColor: context.semantic.accent,
                  side: BorderSide(color: context.semantic.accent, width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      p.isPurchasable ? 'ADD TO CART' : 'OUT OF STOCK',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w900,
                        fontSize: 9,
                      ),
                    ),
                    if (p.isPurchasable) ...[
                      const SizedBox(width: 3),
                      Icon(
                        Icons.shopping_cart_outlined,
                        size: 11,
                        color: context.semantic.accent,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
