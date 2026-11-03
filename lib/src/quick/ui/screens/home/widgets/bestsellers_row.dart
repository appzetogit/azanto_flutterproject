import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../domain/model/category.dart';
import '../../../../domain/model/product.dart';
import '../../../../domain/model/sale_campaign.dart';
import '../../../common/widgets/misc/app_network_image.dart';
import '../home_state.dart';

/// Bestsellers — a 2×3 grid of category tiles.
///
/// Each tile is a 2×2 collage of that category's real product photos, a
/// "+N more" pill sitting on the collage's bottom-right corner, and a footer
/// row of tinted badge, name and chevron.
///
/// Every value comes from the catalogue. This used to be six hardcoded
/// categories with hardcoded Unsplash URLs and invented counts ('+172 more'),
/// and tapping one fuzzy-matched the fake title against the real category list,
/// falling back to `categories.first` — so a tile could open something
/// unrelated to the pictures on it.
class BestsellersRow extends StatelessWidget {
  const BestsellersRow({
    super.key,
    required this.categories,
    required this.onCategoryTap,
    this.sections = const [],
    this.campaigns = const [],
    this.onSeeAll,
  });

  final List<Category> categories;

  /// Supplies each tile's product photos; a category with no loaded section
  /// falls back to its own artwork.
  final List<HomeSection> sections;

  /// Supplies each tile's tint, so a colour set in Admin → Mart Category Themes
  /// reaches this card too instead of the app picking pastels of its own.
  final List<SaleCampaign> campaigns;

  final ValueChanged<String> onCategoryTap;
  final VoidCallback? onSeeAll;

  static const _tileCount = 6;

  /// Photos in the collage. The pill counts everything beyond them.
  static const _collageSize = 4;

  /// The categories with the most to sell, which is what "bestsellers" means
  /// here — ranked by real stock rather than by a hand-picked list.
  List<Category> get _tiles {
    final core = categories.where((c) => c.isCore && c.itemCount > 0).toList()
      ..sort((a, b) => b.itemCount.compareTo(a.itemCount));
    return core.take(_tileCount).toList();
  }

  List<String> _photosFor(Category category) {
    for (final section in sections) {
      if (section.categoryId != category.id) continue;
      final photos = <String>[];
      for (final Product product in section.products) {
        final image = product.gallery.isEmpty ? '' : product.gallery.first;
        if (image.trim().isEmpty || photos.contains(image)) continue;
        photos.add(image);
        if (photos.length == _collageSize) break;
      }
      if (photos.isNotEmpty) return photos;
    }
    // No section loaded yet: the category's own artwork beats four grey boxes.
    return category.imageUrl.trim().isEmpty ? const [] : [category.imageUrl];
  }

  Color? _tintFor(Category category) {
    for (final campaign in campaigns) {
      if (campaign.categoryId != category.id) continue;
      final themed = parseHexColor(campaign.themeColor);
      return themed == null ? null : Color(themed);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final tiles = _tiles;
    // Nothing to rank yet — an empty grid of placeholder frames reads as broken.
    if (tiles.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Bestsellers',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      height: 1.0,
                      letterSpacing: -0.3,
                      color: const Color(0xFF111827),
                    ),
                  ),
                ),
                if (onSeeAll != null)
                  GestureDetector(
                    onTap: onSeeAll,
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      children: [
                        Text(
                          'View all',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            height: 1.0,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
            child: GridView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: tiles.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 10,
                // Collage over a single footer row, at the reference's
                // proportions. The footer's height is fixed by the badge, so
                // the collage absorbs any slack and a two-line name can never
                // overflow the tile.
                childAspectRatio: 0.80,
              ),
              itemBuilder: (context, index) {
                final category = tiles[index];
                return _BestsellerTile(
                  category: category,
                  photos: _photosFor(category),
                  tint: _tintFor(category),
                  onTap: () => onCategoryTap(category.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BestsellerTile extends StatelessWidget {
  const _BestsellerTile({
    required this.category,
    required this.photos,
    required this.tint,
    required this.onTap,
  });

  final Category category;
  final List<String> photos;

  /// The category's admin-set colour, or null to stay neutral.
  final Color? tint;

  final VoidCallback onTap;

  /// How many products the collage does not show.
  int get _remaining => category.itemCount - photos.length;

  @override
  Widget build(BuildContext context) {
    final wash = tint == null
        ? const Color(0xFFF3F4F6)
        : Color.alphaBlend(tint!.withValues(alpha: 0.22), Colors.white);
    final ink = tint == null
        ? const Color(0xFF4B5563)
        : HSLColor.fromColor(tint!)
            .withLightness(
              (HSLColor.fromColor(tint!).lightness - 0.32).clamp(0.0, 1.0),
            )
            .toColor();

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(child: _Collage(photos: photos)),
                  if (_remaining > 0)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: wash,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          '+$_remaining more',
                          style: GoogleFonts.inter(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: ink,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: wash,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  clipBehavior: Clip.antiAlias,
                  alignment: Alignment.center,
                  child: category.imageUrl.trim().isEmpty
                      ? Icon(Icons.category_rounded, size: 16, color: ink)
                      : AppNetworkImage(
                          url: category.imageUrl,
                          width: 30,
                          height: 30,
                          fallbackIcon: Icons.category_rounded,
                        ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    category.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                      color: const Color(0xFF111827),
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: Color(0xFF9CA3AF),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Up to four photos in a 2×2 grid, filling the space it is given.
///
/// Fewer than four is normal for a thin catalogue, so the grid collapses rather
/// than padding itself out with repeats of the same picture.
class _Collage extends StatelessWidget {
  const _Collage({required this.photos});

  final List<String> photos;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.photo_outlined,
          size: 20,
          color: Color(0xFF9CA3AF),
        ),
      );
    }

    if (photos.length == 1) return _cell(photos.first);

    return Column(
      children: [
        Expanded(child: _rowOf(photos[0], photos.length > 1 ? photos[1] : null)),
        if (photos.length > 2) ...[
          const SizedBox(height: 4),
          Expanded(
            child: _rowOf(photos[2], photos.length > 3 ? photos[3] : null),
          ),
        ],
      ],
    );
  }

  Widget _rowOf(String left, String? right) => Row(
        children: [
          Expanded(child: _cell(left)),
          if (right != null) ...[
            const SizedBox(width: 4),
            Expanded(child: _cell(right)),
          ],
        ],
      );

  Widget _cell(String url) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: AppNetworkImage(
          url: url,
          width: double.infinity,
          height: double.infinity,
          fallbackIcon: Icons.shopping_basket_outlined,
        ),
      );
}
