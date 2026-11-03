import '../../../../core/theme/app_spacing.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/constants/app_durations.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../domain/model/banner.dart';
import '../../../common/widgets/misc/app_network_image.dart';
import '../../../common/widgets/loaders/shimmer_box.dart';
import '../../../../core/theme/app_theme.dart';

/// Auto-scrolling promo carousel with width-animating pagination dots.
class BannerCarousel extends StatefulWidget {
  const BannerCarousel({
    super.key,
    required this.banners,
    required this.onTap,
    this.isLoading = false,
    this.height = AppDimens.bannerHeight,
  });

  final List<PromoBanner> banners;
  final ValueChanged<PromoBanner> onTap;
  final bool isLoading;
  final double height;

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

/// Shape of the promo strip: quick-commerce banner ratio.
const double _cardAspect = 2.35;

/// PageView fraction expanded horizontally to fill almost full screen width.
const double _viewportFraction = 0.98;

/// Gutter between the card and the screen edge, per side.
const double _cardGutter = 4;

/// Height that makes each *card* — not the viewport — exactly [_cardAspect].
double _stripHeight(double viewportWidth) =>
    (viewportWidth * _viewportFraction - _cardGutter * 2) / _cardAspect;

class _BannerCarouselState extends State<BannerCarousel> {
  final _controller = PageController(viewportFraction: _viewportFraction);
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  @override
  void didUpdateWidget(BannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.banners.length != widget.banners.length) _startAutoScroll();
  }

  void _startAutoScroll() {
    _timer?.cancel();
    if (widget.banners.length < 2) return;
    _timer = Timer.periodic(AppDurations.bannerAutoScroll, (_) {
      if (!mounted || !_controller.hasClients) return;
      _controller.animateToPage(
        (_index + 1) % widget.banners.length,
        duration: AppDurations.slow,
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: _cardGutter),
        child: AspectRatio(
          aspectRatio: _cardAspect,
          child: ShimmerBox(
            width: double.infinity,
            height: double.infinity,
            radius: AppRadii.rLg,
          ),
        ),
      );
    }

    // No banners published means no carousel.
    if (widget.banners.isEmpty) return const SizedBox.shrink();

    final bannersToDisplay = widget.banners;

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) => SizedBox(
            height: _stripHeight(constraints.maxWidth),
            child: RepaintBoundary(
              child: PageView.builder(
                controller: _controller,
                itemCount: bannersToDisplay.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, index) {
                  final banner = bannersToDisplay[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: _cardGutter,
                    ),
                    child: GestureDetector(
                      onTap: () => widget.onTap(banner),
                      child: _HeroBannerCard(banner: banner),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Pagination Dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            bannersToDisplay.length,
            (i) => AnimatedContainer(
              duration: AppDurations.fast,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 6,
              width: i == _index ? 18 : 6,
              decoration: BoxDecoration(
                color: i == _index ? context.colors.primary : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroBannerCard extends StatelessWidget {
  const _HeroBannerCard({required this.banner});

  final PromoBanner banner;

  @override
  Widget build(BuildContext context) {
    final hasCustomImage = banner.imageUrl.trim().isNotEmpty;

    // Show full backend banner image edge-to-edge if provided by backend.
    if (hasCustomImage) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: AppNetworkImage(
          url: banner.imageUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
      );
    }

    // Screenshot replica banner card layout with mint green gradient, typography & buttons
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [Color(0xFFEFF7F1), Color(0xFFE2F3E7), context.semantic.brandSurfaceSoft],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: context.semantic.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Background vegetable basket accent icon
          Positioned(
            right: -15,
            bottom: -20,
            child: Opacity(
              opacity: 0.18,
              child: Icon(
                Icons.shopping_basket_rounded,
                size: 190,
                color: context.colors.primary,
              ),
            ),
          ),

          // Top right UP TO 30% OFF circular badge
          Positioned(
            right: 14,
            top: 14,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: context.semantic.accent,
                shape: BoxShape.circle,
                border: Border.all(color: context.colors.surface, width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'UP TO',
                    style: GoogleFonts.inter(
                      fontSize: 7,
                      fontWeight: FontWeight.w800,
                      color: context.semantic.border,
                      height: 1.0,
                    ),
                  ),
                  Text(
                    '30%',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                  Text(
                    'OFF',
                    style: GoogleFonts.inter(
                      fontSize: 7,
                      fontWeight: FontWeight.w800,
                      color: context.semantic.border,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Left Content
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.fromLTRB(AppSpacing.gutter, 8, 68, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'FRESHNESS YOU CAN TRUST',
                    style: GoogleFonts.inter(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: context.semantic.accent,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: RichText(
                      text: TextSpan(
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: context.colors.onSurface,
                          height: 1.1,
                        ),
                        children: [
                          TextSpan(
                            text: banner.title.trim().isNotEmpty
                                ? '${banner.title}\n'
                                : 'Fresh Groceries, ',
                          ),
                          TextSpan(
                            text: 'Better Living',
                            style: TextStyle(color: context.semantic.accent),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Get fresh fruits, vegetables & daily essentials.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF4B5563),
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // SHOP NOW button
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: context.semantic.accent,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              banner.ctaText.trim().isNotEmpty
                                  ? banner.ctaText
                                  : 'SHOP NOW',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 10,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      // EXPLORE DEALS button
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: context.colors.onSurface),
                        ),
                        child: Text(
                          'EXPLORE DEALS',
                          style: GoogleFonts.inter(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            color: context.colors.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
