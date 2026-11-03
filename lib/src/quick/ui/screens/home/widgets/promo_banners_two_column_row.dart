import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_spacing.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../domain/model/banner.dart';
import '../../../common/widgets/misc/app_network_image.dart';

/// Full-width single promotional banner section displaying backend banners
/// one at a time with smooth auto-scrolling carousel slider and manual swipe gestures.
class PromoBannersTwoColumnRow extends StatefulWidget {
  const PromoBannersTwoColumnRow({
    super.key,
    this.topBanners = const [],
    this.onBannerTap,
    this.onShopNow,
    this.onOrderNow,
  });

  final List<PromoBanner> topBanners;
  final ValueChanged<PromoBanner>? onBannerTap;
  final VoidCallback? onShopNow;
  final VoidCallback? onOrderNow;

  @override
  State<PromoBannersTwoColumnRow> createState() => _PromoBannersTwoColumnRowState();
}

class _PromoBannersTwoColumnRowState extends State<PromoBannersTwoColumnRow> {
  late final PageController _pageController;
  Timer? _autoScrollTimer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startTimer();
  }

  @override
  void didUpdateWidget(PromoBannersTwoColumnRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.topBanners.length != widget.topBanners.length) {
      _startTimer();
    }
  }

  void _startTimer() {
    _autoScrollTimer?.cancel();
    final count = _slideCount;
    if (count <= 1) return;

    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 3500), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final nextIndex = (_currentIndex + 1) % count;
      _pageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  int get _slideCount =>
      widget.topBanners.isNotEmpty ? widget.topBanners.length : 1;

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = _slideCount;

    // No backend banners -> render nothing. The hand-written "Get Delivery in
    // 30 Minutes!" slide used to fill this gap, which meant the app promised a
    // delivery time no admin controlled and that no API could ever change.
    if (widget.topBanners.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.gutter, vertical: 6),
      child: Container(
        width: double.infinity,
        height: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: context.colors.surface,
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Single Banner Carousel PageView (renders 1 banner at a time across full width)
            PageView.builder(
              controller: _pageController,
              itemCount: count,
              onPageChanged: (i) => setState(() => _currentIndex = i),
              itemBuilder: (context, index) {
                final banner = widget.topBanners[index];
                return _buildBackendBannerSlide(context, banner);
              },
            ),

            // Animated Page Dots Indicator for multiple backend banners
            if (count > 1)
              Positioned(
                bottom: 8,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      count,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        height: 5,
                        width: i == _currentIndex ? 14 : 5,
                        decoration: BoxDecoration(
                          color: i == _currentIndex
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Render individual backend banner slide edge-to-edge
  Widget _buildBackendBannerSlide(BuildContext context, PromoBanner banner) {
    final hasImage = banner.imageUrl.trim().isNotEmpty;

    return GestureDetector(
      onTap: () {
        if (widget.onBannerTap != null) {
          widget.onBannerTap!(banner);
        } else if (widget.onOrderNow != null) {
          widget.onOrderNow!();
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasImage)
            AppNetworkImage(
              url: banner.imageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            )
          else
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [context.semantic.accent, context.colors.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),

          // Text & Button overlay if banner carries custom title/CTA text
          if (banner.title.trim().isNotEmpty || banner.ctaText.trim().isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.75),
                      Colors.transparent,
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (banner.title.trim().isNotEmpty)
                      Text(
                        banner.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    if (banner.ctaText.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.primary,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              banner.ctaText,
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 11,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Default fallback slide if backend returns no banners
}
