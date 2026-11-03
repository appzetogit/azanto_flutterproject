import '../../../../core/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../domain/model/category.dart';
import '../../../common/widgets/loaders/shimmer_box.dart';
import '../../../common/widgets/misc/app_network_image.dart';

/// "SHOP BY CATEGORY" tiles, backed by the real top-level category list.
class ShopByCategoryRow extends StatefulWidget {
  const ShopByCategoryRow({
    super.key,
    this.categories = const [],
    this.isLoading = false,
    this.onCategoryTap,
    this.onSeeAll,
  });

  final List<Category> categories;
  final bool isLoading;
  final ValueChanged<String>? onCategoryTap;
  final VoidCallback? onSeeAll;

  @override
  State<ShopByCategoryRow> createState() => _ShopByCategoryRowState();
}

class _ShopByCategoryRowState extends State<ShopByCategoryRow> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollRight() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.offset + 180,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoading && widget.categories.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(AppSpacing.gutter, 2, AppSpacing.gutter, 2),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'SHOP BY CATEGORY',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                    color: context.colors.onSurface,
                  ),
                ),
              ),
              GestureDetector(
                onTap: widget.onSeeAll,
                child: Row(
                  children: [
                    Text(
                      'View all',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: context.colors.primary,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: context.colors.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Stack(
          alignment: Alignment.centerRight,
          children: [
            SizedBox(
              height: 135,
              child: widget.categories.isEmpty
                  ? ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
                      itemCount: 5,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (_, _) => const Column(
                        children: [
                          ShimmerBox(width: 90, height: 86, radius: BorderRadius.all(Radius.circular(14))),
                          SizedBox(height: 6),
                          ShimmerBox(width: 70, height: 10),
                        ],
                      ),
                    )
                  : ListView.separated(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
                      itemCount: widget.categories.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final item = widget.categories[index];
                        return GestureDetector(
                          onTap: () => widget.onCategoryTap?.call(item.id),
                          child: Container(
                            width: 96,
                            decoration: BoxDecoration(
                              color: context.colors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFF3F4F6)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Upper Image Area: Fills full width & height above title
                                SizedBox(
                                  height: 82,
                                  width: double.infinity,
                                  child: AppNetworkImage(
                                    url: item.imageUrl,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                    fallbackIcon: Icons.shopping_basket_outlined,
                                  ),
                                ),
                                // Lower Title Area: Clean, separate, centered
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 4,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      item.name,
                                      maxLines: 2,
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        color: context.colors.onSurface,
                                        height: 1.15,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Scroll Right Arrow Floating Button
            if (widget.categories.length > 3)
              Positioned(
                right: 4,
                child: GestureDetector(
                  onTap: _scrollRight,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 22,
                      color: context.colors.onSurface,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
