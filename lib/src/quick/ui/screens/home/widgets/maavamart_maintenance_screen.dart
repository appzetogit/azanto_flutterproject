import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../presentation/mode/app_mode.dart';

/// Screen displayed when no MaavaMart store is available in the user's current
/// zone, or when the admin has disabled the whole Mart section. Matches the
/// official MaavaMart maintenance / store unavailable design; [title],
/// [subtitle] and [body] let the admin-disabled case use different copy from
/// the empty-zone default without a second near-identical screen.
class MaavaMartMaintenanceScreen extends ConsumerStatefulWidget {
  const MaavaMartMaintenanceScreen({
    super.key,
    this.title = 'AzantoMART',
    this.subtitle = 'CURRENT UNDER MAINTENANCE',
    this.body =
        "WE'RE CURRENTLY REFRESHING OUR STORE WITH SOME AMAZING NEW PRODUCTS. STAY TUNED!",
    this.onRetry,
  });

  final String title;
  final String subtitle;
  final String body;

  /// When set, shows a "Try Again" action — for the admin-disabled case,
  /// where the flag can flip back on while the shopper is sitting on this
  /// exact screen and there's otherwise nothing that would re-check it.
  final VoidCallback? onRetry;

  @override
  ConsumerState<MaavaMartMaintenanceScreen> createState() =>
      _MaavaMartMaintenanceScreenState();
}

class _MaavaMartMaintenanceScreenState
    extends ConsumerState<MaavaMartMaintenanceScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  Timer? _recheckTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    // Nothing else re-checks the admin flag while the shopper just sits on
    // this screen — without this, flipping it back on in the admin panel
    // goes unnoticed until they manually retry or leave and re-enter Mart.
    if (widget.onRetry != null) {
      _recheckTimer = Timer.periodic(
        const Duration(seconds: 12),
        (_) => widget.onRetry?.call(),
      );
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _recheckTimer?.cancel();
    super.dispose();
  }

  void _goBackToFood() {
    ref.read(appModeProvider.notifier).set(AppMode.food);
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    // Rich purple background matching reference image
    const backgroundColor = Color(0xFF6B52D1);
    const logoCircleColor = Color(0xFFECEAEF);
    const mLogoColor = Color(0xFF6B52D1);
    const badgeColor = Color(0xFFE5B82C);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // 1. Subtle Floating Sparkles / Stars Background Animation
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return CustomPaint(
                painter: _SparkleBackgroundPainter(
                  progress: _pulseController.value,
                ),
                size: Size.infinite,
              );
            },
          ),

          // 2. Main Content
          SafeArea(
            child: Column(
              children: [
                // Top Navigation Row with Back Button
                Padding(
                  padding: const EdgeInsets.only(left: 16, top: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _goBackToFood,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.20),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const Spacer(flex: 2),

                // Center Illustration Logo
                Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // White / Light Grey Outer Logo Circle
                      Container(
                        width: 140,
                        height: 140,
                        decoration: const BoxDecoration(
                          color: logoCircleColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x22000000),
                              blurRadius: 20,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            'M',
                            style: GoogleFonts.caveat(
                              fontSize: 78,
                              fontWeight: FontWeight.w900,
                              color: mLogoColor,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),

                      // Golden-Yellow Sparkle Badge at Top-Right
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: badgeColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x33000000),
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.auto_awesome_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 36),

                // Title
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),

                const SizedBox(height: 12),

                // Subtitle
                Text(
                  widget.subtitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withValues(alpha: 0.92),
                    letterSpacing: 1.0,
                  ),
                ),

                const SizedBox(height: 18),

                // Description
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    widget.body,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.75),
                      height: 1.45,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

                if (widget.onRetry != null) ...[
                  const SizedBox(height: 28),
                  Material(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(24),
                    child: InkWell(
                      onTap: widget.onRetry,
                      borderRadius: BorderRadius.circular(24),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 12,
                        ),
                        child: Text(
                          'TRY AGAIN',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],

                const Spacer(flex: 3),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter rendering delicate background sparkles
class _SparkleBackgroundPainter extends CustomPainter {
  _SparkleBackgroundPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15 + 0.10 * math.sin(progress * math.pi * 2))
      ..style = PaintingStyle.fill;

    final particles = [
      Offset(size.width * 0.20, size.height * 0.25),
      Offset(size.width * 0.80, size.height * 0.22),
      Offset(size.width * 0.15, size.height * 0.55),
      Offset(size.width * 0.85, size.height * 0.58),
      Offset(size.width * 0.35, size.height * 0.78),
      Offset(size.width * 0.72, size.height * 0.82),
    ];

    for (var i = 0; i < particles.length; i++) {
      final radius = 2.0 + (i % 3) * 1.0;
      canvas.drawCircle(particles[i], radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkleBackgroundPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
