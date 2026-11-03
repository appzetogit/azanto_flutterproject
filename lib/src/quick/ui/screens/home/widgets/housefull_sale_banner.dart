import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../presentation/branding/app_colors.dart';
import '../../../../domain/model/category.dart';
import '../../../../domain/model/product.dart';
import '../../../../domain/model/sale_campaign.dart';
import '../../../common/widgets/misc/app_network_image.dart';
import 'bouncing_heading.dart';

/// Housefull Sale Banner matching the reference layout & structure:
///
/// - Deep Midnight Contrast Background for high 3D pop against header.
/// - Top 3D Text: "HOUSEFULL SALE" with Gold Sparkle Icons ⚡
/// - Date Sub-label Pill: "30TH NOV, 2025 - 7TH DEC, 2025"
/// - Left Side CRAZY DEALS Card: High-contrast gradient card with Gold border,
///   dark strikethrough price pill, red deal price pill & white image box.
/// - Right Side Grid (2x2): Pure white rounded cards with vibrant discount badges.
/// - Bottom Wavy / Scalloped Edge transitioning into the white content area.
class HousefullSaleBanner extends StatelessWidget {
  const HousefullSaleBanner({
    super.key,
    this.dealProducts = const [],
    this.campaign,
    this.categories = const [],
    this.onCrazyDealsTap,
    this.onCategoryCardTap,
  });

  /// Fallback deals, used when the admin has curated none on the campaign.
  ///
  /// A list rather than a single product: the card is a carousel, and handing it
  /// one item leaves it static — which is what it was, because the campaign has
  /// no products configured and the caller passed only the first of these.
  final List<Product> dealProducts;

  /// Admin-configured promotion. Null means none is scheduled, and every label
  /// below falls back to what the app shipped with — the layout is identical
  /// either way.
  final SaleCampaign? campaign;

  final List<Category> categories;
  final VoidCallback? onCrazyDealsTap;
  final ValueChanged<String>? onCategoryCardTap;


  /// The campaign headline, exactly as the admin wrote it.
  ///
  /// One string, rendered as ONE [Text]. It used to be split on whitespace into
  /// a big top line and a smaller last word — 'GROCERY' over 'SALE' — which
  /// made the two halves read as separate elements and animate as though only
  /// 'SALE' was alive. Whatever the backend sends now bounces as a single unit.
  String get _headline {
    final title = (campaign?.title ?? '').trim();
    return title.isEmpty ? 'HOUSEFULL SALE' : title;
  }

  /// Formatted by the backend from the campaign window, so it cannot go stale
  /// the way the compiled-in range did.
  String get _dateLabel => campaign?.dateLabel ?? '';

  String get _dealLabelTop {
    final words = (campaign?.dealLabel ?? 'CRAZY DEALS').trim().split(RegExp(r'\s+'));
    return words.first;
  }

  String get _dealLabelBottom {
    final words = (campaign?.dealLabel ?? 'CRAZY DEALS').trim().split(RegExp(r'\s+'));
    return words.length > 1 ? words.sublist(1).join(' ') : '';
  }

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.primary;
    final primaryDeep = AppColors.primaryDeep;

    // The campaign's theme drives the plate so the banner matches the header
    // the category just painted. Falling back to the brand colour keeps the
    // default 'All' banner exactly as it was.
    final themed = parseHexColor(campaign?.themeColor ?? '');
    final accent = parseHexColor(campaign?.accentColor ?? '');
    final Color plateBase = themed == null ? primary : Color(themed);

    // Cards and badges follow the campaign's accent so they sit in the same
    // family as the plate; without a campaign they stay brand-coloured.
    final Color cardAccent = accent != null ? Color(accent) : primary;

    // High-contrast deep gradient for 3D separation from the header. Derived
    // from the plate, so a pale category theme still yields a readable banner
    // instead of white-on-white.
    final HSLColor hsl = HSLColor.fromColor(
      accent != null ? Color(accent) : plateBase,
    );
    final Color deepMidnight = hsl
        .withLightness((hsl.lightness * 0.28).clamp(0.06, 0.22))
        .withSaturation((hsl.saturation * 0.95).clamp(0.5, 0.95))
        .toColor();
    final Color richDeepBrand = hsl
        .withLightness((hsl.lightness * 0.42).clamp(0.15, 0.35))
        .toColor();
    final Color midBrand = hsl
        .withLightness((hsl.lightness * 0.58).clamp(0.32, 0.52))
        .toColor();

    return ClipPath(
      clipper: const _ScallopedEdgeClipper(),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              deepMidnight,
              richDeepBrand,
              midBrand,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 28),
        child: Column(
          children: [
            // TOP SALE TITLE & DECORATIVE SPARKLES
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Anchored to the Stack's own edges rather than a fixed offset,
                // so they stay put whatever height the headline resolves to.
                const Positioned(
                  left: 20,
                  top: -4,
                  child: Icon(Icons.flash_on_rounded, color: Color(0xFFFFD700), size: 28),
                ),
                const Positioned(
                  right: 20,
                  top: -4,
                  child: Icon(Icons.flash_on_rounded, color: Color(0xFFFFD700), size: 28),
                ),
                const Positioned(
                  left: 4,
                  bottom: -4,
                  child: Icon(Icons.auto_awesome_rounded, color: Color(0xFFFDE68A), size: 16),
                ),
                const Positioned(
                  right: 4,
                  bottom: -4,
                  child: Icon(Icons.auto_awesome_rounded, color: Color(0xFFFDE68A), size: 16),
                ),

                Padding(
                  // Keeps the longest headings clear of the sparkle bolts.
                  padding: const EdgeInsets.symmetric(horizontal: 52),
                  child: FittedBox(
                    // Headings come from the admin and vary from 'GROCERY SALE'
                    // to 'BEAUTY & PERSONAL CARE SALE'. Scaling down to fit
                    // keeps every one of them on a single line and whole —
                    // wrapping or ellipsis would break the wave mid-word.
                    fit: BoxFit.scaleDown,
                    child: BouncingHeading(
                      text: _headline,
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                        letterSpacing: 1.5,
                        color: Colors.white,
                        shadows: const [
                          Shadow(offset: Offset(0, 3), blurRadius: 0, color: Color(0x99000000)),
                          Shadow(offset: Offset(0, 6), blurRadius: 6, color: Color(0x4D000000)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Outside the animation on purpose: the bounce is the headline's,
            // and a date strip drifting with it made the whole block look loose.
            if (_dateLabel.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: Text(
                  _dateLabel,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFFDE68A),
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 18),

            // MAIN CONTENT GRID: CRAZY DEALS CARD (LEFT) + 2x2 CATEGORIES GRID (RIGHT)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // LEFT: CRAZY DEALS CARD
                  Expanded(
                    flex: 4,
                    child: _buildCrazyDealsCard(context, cardAccent, primaryDeep),
                  ),

                  const SizedBox(width: 10),

                  // RIGHT: 2x2 CATEGORY OFFER CARDS GRID
                  Expanded(
                    flex: 7,
                    child: _buildCategoryGrid(context, cardAccent, primaryDeep),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// How many products the card falls back to when the campaign curates none.
  static const _fallbackDealCount = 6;

  Widget _buildCrazyDealsCard(BuildContext context, Color primary, Color primaryDeep) {
    // The campaign's own products, in the admin's order. The card used to show
    // whichever product the flash-sale section happened to rank first, which
    // had nothing to do with the promotion the admin had configured.
    final featured = campaign?.products ?? const <SaleCampaignProduct>[];
    final deals = featured.isNotEmpty
        ? featured
        : [
            // Enough to be worth rotating, not so many that the card cycles
            // for a minute before repeating.
            for (final p in dealProducts.take(_fallbackDealCount))
              SaleCampaignProduct(
                id: p.id,
                name: p.name,
                imageUrl: p.imageUrl,
                price: p.price,
                mrp: p.strikePrice,
              ),
          ];

    return GestureDetector(
      onTap: onCrazyDealsTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [primary, primaryDeep],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFFBBF24), // Vibrant Gold border matching reference
            width: 1.8,
          ),
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 3)),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              children: [
                Text(
                  _dealLabelTop,
                  style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.1,
                    shadows: const [
                      Shadow(offset: Offset(0, 2), blurRadius: 0, color: Color(0x8C000000)),
                    ],
                  ),
                ),
                Text(
                  _dealLabelBottom,
                  style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.1,
                    shadows: const [
                      Shadow(offset: Offset(0, 2), blurRadius: 0, color: Color(0x8C000000)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(child: _DealCarousel(deals: deals)),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryGrid(BuildContext context, Color primary, Color primaryDeep) {
    // Tiles come from the campaign, including the category each one opens —
    // the app used to ship placeholder ids ('wellness', 'meals') that matched
    // no category, so every tile was a dead link.
    final List<_CategoryCardData> cards = (campaign?.tiles ?? const [])
        .map((t) => _CategoryCardData(
              title: t.title,
              badgeText: t.badgeText,
              emojis: t.emojis,
              categoryId: t.categoryId ?? '',
            ))
        .toList();

    // Whatever the admin configured, not exactly four. This indexed cards[0]
    // through cards[3] unconditionally and threw RangeError on any campaign
    // with fewer tiles — which is every campaign created through the admin
    // panel, since tiles start empty. A short campaign now renders the tiles it
    // has and an untiled one renders nothing at all.
    if (cards.isEmpty) return const SizedBox.shrink();

    Widget rowOf(_CategoryCardData left, _CategoryCardData? right) => Row(
          children: [
            Expanded(child: _buildCategoryCard(context, left, primary, primaryDeep)),
            const SizedBox(width: 8),
            Expanded(
              child: right == null
                  // Holds the column width so a lone tile does not stretch to
                  // double the width of its neighbours.
                  ? const SizedBox.shrink()
                  : _buildCategoryCard(context, right, primary, primaryDeep),
            ),
          ],
        );

    return Column(
      children: [
        Expanded(child: rowOf(cards[0], cards.length > 1 ? cards[1] : null)),
        if (cards.length > 2) ...[
          const SizedBox(height: 8),
          Expanded(
            child: rowOf(cards[2], cards.length > 3 ? cards[3] : null),
          ),
        ],
      ],
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    _CategoryCardData data,
    Color primary,
    Color primaryDeep,
  ) {
    return GestureDetector(
      onTap: () => onCategoryCardTap?.call(data.categoryId),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(6, 7, 6, 9),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Discount Badge Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primary,
                    primaryDeep,
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                data.badgeText,
                style: GoogleFonts.inter(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 4),

            // Card Title
            Text(
              data.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF111827),
                height: 1.15,
              ),
            ),

            const SizedBox(height: 4),

            // Category Emojis / Graphics Row
            Text(
              data.emojis,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryCardData {
  const _CategoryCardData({
    required this.title,
    required this.badgeText,
    required this.emojis,
    required this.categoryId,
  });

  final String title;
  final String badgeText;
  final String emojis;
  final String categoryId;
}

class _ScallopedEdgeClipper extends CustomClipper<Path> {
  const _ScallopedEdgeClipper();

  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 12);

    const scallopWidth = 18.0;
    final count = (size.width / scallopWidth).ceil();

    for (int i = 0; i < count; i++) {
      final x = i * scallopWidth;
      path.quadraticBezierTo(
        x + scallopWidth / 2,
        size.height,
        x + scallopWidth,
        size.height - 12,
      );
    }

    path.lineTo(size.width, size.height - 12);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

/// The deal card's rotating product: prices, name and picture, one after
/// another, in the order the admin arranged them.
///
/// Each product slides up out of the way as the next slides in, so the card
/// reads as scrolling rather than blinking between states.
///
/// A [PageView] would have been swipeable, but this card lives inside an
/// [IntrinsicHeight] and a viewport cannot report intrinsic dimensions — it
/// throws during layout. A switcher measures like an ordinary box.
class _DealCarousel extends StatefulWidget {
  const _DealCarousel({required this.deals});

  final List<SaleCampaignProduct> deals;

  /// How long each product holds before the next slides in.
  static const _dwell = Duration(seconds: 3);
  static const _slide = Duration(milliseconds: 550);

  @override
  State<_DealCarousel> createState() => _DealCarouselState();
}

class _DealCarouselState extends State<_DealCarousel> {
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  @override
  void didUpdateWidget(_DealCarousel old) {
    super.didUpdateWidget(old);
    // A category switch swaps the whole product list under us.
    if (old.deals.length == widget.deals.length) return;
    _index = 0;
    _restartTimer();
  }

  void _restartTimer() {
    _timer?.cancel();
    // Nothing to rotate through: one product, or none. A timer ticking against
    // a single slide would rebuild the card forever for no visible reason.
    if (widget.deals.length < 2) return;
    _timer = Timer.periodic(_DealCarousel._dwell, (_) {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % widget.deals.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.deals.isEmpty) return const SizedBox.shrink();
    final deal = widget.deals[_index % widget.deals.length];

    return ClipRect(
      child: AnimatedSwitcher(
        duration: _DealCarousel._slide,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        // Both children are laid out on top of each other mid-transition;
        // aligning them to the same box keeps the prices from jumping.
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.center,
          children: [...previous, ?current],
        ),
        transitionBuilder: (child, animation) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.4),
            end: Offset.zero,
          ).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: _DealSlide(key: ValueKey(deal.id), deal: deal),
      ),
    );
  }
}

/// One product inside the deal card.
class _DealSlide extends StatelessWidget {
  const _DealSlide({super.key, required this.deal});

  final SaleCampaignProduct deal;

  @override
  Widget build(BuildContext context) {
    final mrp = deal.mrp;

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          children: [
            // Only when there is a real MRP above the selling price — a struck
            // price equal to what you pay advertises a saving that is not there.
            if (mrp != null && mrp > deal.price)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2937),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '₹${mrp.toStringAsFixed(0)}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white70,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: Colors.white70,
                  ),
                ),
              ),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
                ],
              ),
              child: Text(
                '₹${deal.price.toStringAsFixed(0)}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              deal.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
        Container(
          width: 64,
          height: 64,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 5, offset: Offset(0, 2)),
            ],
          ),
          alignment: Alignment.center,
          child: AppNetworkImage(
            url: deal.imageUrl,
            width: 54,
            height: 54,
            fit: BoxFit.contain,
            fallbackIcon: null,
          ),
        ),
      ],
    );
  }
}
