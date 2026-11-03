import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/utils/haptics.dart';
import '../../../../../presentation/auth/viewmodels/auth_viewmodel.dart';
import '../../../../../presentation/branding/app_colors.dart';
import '../../../../domain/model/category.dart';
import '../../../../domain/model/sale_campaign.dart';
import '../../../../di/app_providers.dart';
import '../../../../di/service_providers.dart';
import '../../../../navigation/route_paths.dart';
import '../../../common/smart_scan.dart';
import '../../../common/widgets/inputs/search_bar_widget.dart';
import '../../../common/widgets/misc/app_network_image.dart';

/// The header plate's deep→mid→light ramp for [campaign], top stop first.
///
/// The selected category's campaign repaints the header. A campaign without a
/// colour — or no campaign at all — leaves the brand gradient untouched, so
/// this can only ever add theming, never remove it.
///
/// Structure is preserved, not replaced: the same ramp the brand gradient uses,
/// rebuilt around the category's hue. Painting a single flat colour instead
/// lost the header's depth and made the tint read as "nothing changed".
///
/// Top-level so the screen can ask what colour sits under the status bar
/// without duplicating the ramp — the two used to disagree, and the status bar
/// picked its icon brightness from the brand while sitting on the campaign.
List<Color> martHeaderGradient(SaleCampaign? campaign) {
  final themed = parseHexColor(campaign?.themeColor ?? '');
  if (themed == null) {
    return [AppColors.primaryDeep, AppColors.primary, AppColors.primaryLight];
  }
  final base = HSLColor.fromColor(Color(themed));
  return [
    base.withLightness((base.lightness - 0.14).clamp(0.0, 1.0)).toColor(),
    Color(themed),
    base.withLightness((base.lightness + 0.08).clamp(0.0, 1.0)).toColor(),
  ];
}

/// Which slice of the header to draw.
///
/// The search bar is pinned by the home screen while the rest scrolls, so the
/// header renders in parts. Each part paints its own band of the same top-to-
/// bottom ramp — deep→mid above, mid behind the search field, mid→light below —
/// so the three stacked together look exactly like the single gradient they
/// replaced.
enum MartHeaderSection { all, top, search, categories }

/// Mart's Header section, matching the screenshot spec:
///
/// - Warm Vibrant Orange Gradient background spanning status bar down to tabs.
/// - Top Row:
///   - Subtitle: the storefront name from the admin panel.
///   - Large Bold ETA: the serving store's delivery estimate.
///   - Selected location & address line with dropdown caret `v`
///   - Top Right: Circular badge with pass/wallet/notification icon.
/// - Search Bar Row:
///   - Full-width white capsule container with Search icon, "Search 'dal'" hint, and filter icon.
/// - Category Navigation Bar:
///   - Horizontal scrollable strip of the admin's header categories, each with
///     its own catalogue image, preceded by an 'All' reset control.
///   - The selected tab carries the plate and the pill indicator underneath.

class DeliveryHeader extends ConsumerStatefulWidget {
  const DeliveryHeader({
    super.key,
    this.categories = const [],
    this.campaign,
    this.selectedCategoryId = '',
    this.deliveryMinutes,
    this.isClosed = false,
    this.nextOpeningTimeText,
    this.section = MartHeaderSection.all,
    this.onCategoryTap,
    this.onAllTap,
  });

  final List<Category> categories;

  /// Drives the header's palette and search hint for the selected category.
  final SaleCampaign? campaign;

  /// Empty means 'All'. Held by the page so the strip and the content below it
  /// can never disagree about what is selected.
  final String selectedCategoryId;

  /// Delivery estimate for the store serving this address, in minutes. Null
  /// while the seller list is still loading, or when no seller publishes one.
  final int? deliveryMinutes;

  /// Whether the store in the user's zone is currently closed.
  final bool isClosed;

  /// Reopen message from the backend, e.g. "Please come back at 6:00 am".
  final String? nextOpeningTimeText;

  /// Defaults to the whole header, which is what any caller outside the home
  /// screen wants.
  final MartHeaderSection section;

  final ValueChanged<String>? onCategoryTap;
  final VoidCallback? onAllTap;

  @override
  ConsumerState<DeliveryHeader> createState() => _DeliveryHeaderState();
}

class _DeliveryHeaderState extends ConsumerState<DeliveryHeader> {
  String get _selectedCategoryId =>
      widget.selectedCategoryId.isEmpty ? 'all' : widget.selectedCategoryId;

  /// The curated header set: whatever the admin flagged `showInHeader`.
  ///
  /// Falls back to every core category when nothing is flagged, so an older
  /// backend — or a fresh install before an admin has curated — still renders a
  /// usable strip instead of just 'All'.
  List<Category> get _headerCategories {
    final flagged = widget.categories.where((c) => c.showInHeader).toList();
    return flagged.isNotEmpty ? flagged : widget.categories;
  }

  /// Rotating search-bar hints — always the category names, same as every
  /// other search bar in the app (Food home, Mart categories tab). A selected
  /// category used to collapse this to its single campaign `searchHint`
  /// ('milk' for Grocery, etc.), which froze the animation on one word since
  /// [SearchBarWidget] only rotates when it has more than one item.
  List<String> get _searchHints {
    return widget.categories.map((c) => c.name).toList();
  }

  /// Ink for everything drawn on the header plate.
  ///
  /// Category themes are pale (mint, pink, amber) while the brand gradient is
  /// deep, so a fixed white would vanish the moment a category is selected.
  /// Derived from the plate's own luminance rather than a per-category table.
  Color get _headerInk {
    final themed = parseHexColor(widget.campaign?.themeColor ?? '');
    if (themed == null) return Colors.white;
    // Judged on the campaign colour itself, not the gradient's darkened top
    // stop: these tints are pastels, so the darkened stop sits just under the
    // luminance threshold and flipped the whole header to low-contrast white.
    return Color(themed).computeLuminance() > 0.5
        ? const Color(0xFF1F2937)
        : Colors.white;
  }

  /// Artwork available across the header categories, for the 'All' tile.
  List<String> get _headerImages => _headerCategories
      .map((c) => c.imageUrl.trim())
      .where((url) => url.isNotEmpty)
      .take(4)
      .toList();

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authViewModelProvider).value;
    final avatarUrl = user?.avatarUrl ?? '';
    final address = ref.watch(selectedAddressProvider);
    final topPadding = MediaQuery.of(context).padding.top;

    // An address is shown only when the user actually has one. The fallback
    // used to be a literal Indore address, so a signed-out user was told their
    // order was going to an office none of them had ever set — and tapping it
    // was the only way to find out it was fiction.
    final String? shortLine = address?.shortLine.trim();
    final bool hasAddress = shortLine != null && shortLine.isNotEmpty;
    final String addressLine;
    if (hasAddress) {
      final label = address!.label.wireValue.trim();
      addressLine = label.isNotEmpty ? '$label - $shortLine' : shortLine;
    } else {
      addressLine = 'Tap to save address';
    }

    final gradientColors = martHeaderGradient(widget.campaign);

    // One band of the ramp per section: the pinned search bar has to carry its
    // own background, or it goes transparent over the content scrolling beneath
    // it. Stacked, the three bands reproduce the single gradient exactly —
    // deep→mid, mid, mid→light.
    Widget band(List<Color> colors, Widget child) => AnimatedContainer(
      // Matches the reference's soft cross-fade between category themes rather
      // than snapping to the new colour.
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: child,
    );

    final topBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Only the standalone header reserves the status bar itself. Inside the
        // home screen a fixed strip above the scroll view holds that space, so
        // the pinned search field can stop below the status bar rather than
        // sliding under it.
        SizedBox(
          height: (widget.section == MartHeaderSection.all ? topPadding : 0) + 6,
        ),
      // 1. TOP LOCATION & ETA ROW
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Builder(
                    builder: (context) {
                      final bool isStoreClosed = widget.isClosed;
                      final String topSubtitle = isStoreClosed
                          ? (widget.nextOpeningTimeText ?? 'Please come back at 6:00 am')
                          : (ref.watch(storeNameProvider).value ?? '');
                      final String mainTitle = isStoreClosed
                          ? 'Store closed'
                          : (widget.deliveryMinutes == null
                              ? 'Delivery soon'
                              : '${widget.deliveryMinutes} minutes');

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            topSubtitle,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _headerInk.withValues(alpha: 0.90),
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            mainTitle,
                            style: GoogleFonts.outfit(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              height: 1.05,
                              letterSpacing: -0.5,
                              color: _headerInk,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 3),
                  GestureDetector(
                    onTap: () => context.push(RoutePaths.addresses),
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            addressLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: _headerInk.withValues(alpha: 0.95),
                            ),
                          ),
                        ),
                        const SizedBox(width: 3),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: _headerInk,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Right side circular action badge (Profile icon / Avatar)
            GestureDetector(
              onTap: () {
                Haptics.light();
                context.push(RoutePaths.profile);
              },
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.9),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: avatarUrl.isNotEmpty
                      ? Image.network(
                          avatarUrl,
                          width: 42,
                          height: 42,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Image.asset(
                            'assets/images/user_avatar_3d.webp',
                            width: 42,
                            height: 42,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Image.asset(
                          'assets/images/user_avatar_3d.webp',
                          width: 42,
                          height: 42,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
        const SizedBox(height: 12),
      ],
    );

    final searchBlock = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
      // 2. SEARCH BAR ROW (Original SearchBarWidget with animated hints, mic & barcode scanner)
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SearchBarWidget(
          readOnly: true,
          // A selected category advertises its own example term ('milk',
          // 'chargers'); 'All' keeps cycling the category names.
          categories: _searchHints,
          onTap: () => context.push(RoutePaths.search),
          onScanTap: () => SmartScan.run(context, ref),
          onMicTap: () => context.push('${RoutePaths.search}?voice=1'),
        ),
      ),
      ],
    );

    final categoriesBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 14),
        _buildCategoryTabsRow(context),
        const SizedBox(height: 6),
      ],
    );

    return switch (widget.section) {
      MartHeaderSection.top =>
        band([gradientColors[0], gradientColors[1]], topBlock),
      MartHeaderSection.search =>
        band([gradientColors[1], gradientColors[1]], searchBlock),
      MartHeaderSection.categories =>
        band([gradientColors[1], gradientColors[2]], categoriesBlock),
      MartHeaderSection.all => band(
          gradientColors,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [topBlock, searchBlock, categoriesBlock],
          ),
        ),
    };
  }

    Widget _buildCategoryTabsRow(BuildContext context) {
    // Core categories, from the backend, in the admin's own display order.
    //
    // This used to start from a hardcoded list — Wedding, Winter, Electronics,
    // Beauty, Grocery, Fashion — and merely append whatever the backend
    // returned, so the strip advertised categories that did not exist in the
    // catalogue. 'All' stays because it is a reset control, not a category.
    final items = <_CategoryTabItem>[
      const _CategoryTabItem(id: 'all', label: 'All'),
      for (final cat in _headerCategories)
        _CategoryTabItem(id: cat.id, label: cat.name, imageUrl: cat.imageUrl),
    ];

    return SizedBox(
      height: _tabStripHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: items.length,
        // Tight: the labels wrap inside their own fixed width, so the gap is
        // only separating tiles rather than absorbing a long category name.
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final item = items[index];
          final isSelected = _selectedCategoryId == item.id;

          return GestureDetector(
            onTap: () {
              if (item.id == 'all') {
                widget.onAllTap?.call();
              } else {
                widget.onCategoryTap?.call(item.id);
              }
            },
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              // Fixed, so 'Fruits & Vegetables' wraps to two lines instead of
              // stretching its tile wider than every other one.
              width: _tabWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 42,
                    decoration: BoxDecoration(
                      // Follows the SELECTION, not the 'All' tab. Keying these
                      // on `item.id == 'all'` pinned the highlight there
                      // permanently: picking Grocery re-themed the whole page
                      // while the strip still pointed at All.
                      color: isSelected
                          ? _headerInk.withValues(alpha: 0.25)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(color: _headerInk, width: 1.5)
                          : null,
                    ),
                    clipBehavior: Clip.antiAlias,
                    alignment: Alignment.center,
                    // Photographs only, at one size and one shape for every
                    // tab. There is deliberately no glyph anywhere in this
                    // strip: a lone icon sitting between photographs reads as a
                    // broken image, not as an icon. A category the admin has
                    // not given artwork yet gets the same plate, empty — which
                    // is also what makes the gap visible enough to fix.
                    child: item.id == 'all'
                        ? _AllTabArtwork(
                            images: _headerImages,
                            tint: _headerInk,
                          )
                        : AppNetworkImage(
                            url: item.imageUrl,
                            width: 44,
                            height: 42,
                            fallbackIcon: null,
                          ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      height: 1.15,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: _headerInk,
                    ),
                  ),
                  const SizedBox(height: 3),
                  // Always laid out, transparent when unselected: showing it
                  // only for the selected tab changed the tile's height and
                  // made the whole strip twitch on every tap.
                  Container(
                    width: 26,
                    height: 3.5,
                    decoration: BoxDecoration(
                      color: isSelected ? _headerInk : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Plate + gap + two label lines + gap + indicator.
const double _tabStripHeight = 42 + 3 + 25 + 3 + 3.5;
const double _tabWidth = 64;

class _CategoryTabItem {
  const _CategoryTabItem({
    required this.id,
    required this.label,
    this.imageUrl = '',
  });

  final String id;
  final String label;

  /// The category's own catalogue image. Empty renders the fallback glyph —
  /// the app never invents artwork the admin has not uploaded.
  final String imageUrl;
}

/// The 'All' tab's plate: a mosaic of the header categories' own artwork.
///
/// 'All' is a reset control with no catalogue row behind it, so it has no image
/// of its own — but the strip is photographs only, and a home glyph sitting
/// among them was the odd one out. Showing what "all" contains is both truer
/// and made of the same real images as its neighbours.
class _AllTabArtwork extends StatelessWidget {
  const _AllTabArtwork({required this.images, required this.tint});

  final List<String> images;

  /// Wash used when the catalogue has no artwork to show yet.
  final Color tint;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return ColoredBox(color: tint.withValues(alpha: 0.18));
    }
    if (images.length == 1) return _cell(images.first);

    return Column(
      children: [
        Expanded(child: _row(images[0], images.length > 1 ? images[1] : null)),
        if (images.length > 2)
          Expanded(child: _row(images[2], images.length > 3 ? images[3] : null)),
      ],
    );
  }

  Widget _row(String left, String? right) => Row(
        children: [
          Expanded(child: _cell(left)),
          if (right != null) Expanded(child: _cell(right)),
        ],
      );

  Widget _cell(String url) => AppNetworkImage(
        url: url,
        width: double.infinity,
        height: double.infinity,
        fallbackIcon: null,
      );
}
