import 'package:flutter/material.dart';

import '../../core/utils/haptics.dart';
import '../../presentation/branding/app_colors.dart';
import 'confetti.dart';

// Re-exported: callers and tests reached the confetti through this file before
// it moved out into its own.
export 'confetti.dart';

/// The coupon-applied celebration, shared by both verticals.
///
/// Shown only once the server has actually accepted the coupon — the caller
/// passes the code and saving it echoed back, so nothing here is invented.
///
/// The confetti runs once and settles; the card stays until dismissed, which is
/// what leaves the user back on the cart/checkout they came from.
Future<void> showCouponCelebration(
  BuildContext context, {
  required String code,
  required double savings,
}) {
  final saved = savings % 1 == 0
      ? savings.toStringAsFixed(0)
      : savings.toStringAsFixed(2);

  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) => _Celebration(
      icon: Icons.local_offer_rounded,
      headline: 'You saved ₹$saved',
      badge: code.toUpperCase(),
      message: 'Coupon applied to your order 🎉',
      seed: code.hashCode,
    ),
  );
}

/// The free-delivery unlock, celebrated exactly as an applied coupon is.
///
/// Same card, same burst: crossing the threshold is the same kind of win as a
/// coupon landing, and it earned the same moment.
Future<void> showFreeDeliveryCelebration(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) => const _Celebration(
      icon: Icons.electric_bolt_rounded,
      headline: 'FREE delivery unlocked',
      badge: 'NO DELIVERY FEE',
      message: 'No delivery charge on this order 🎉',
      seed: 0x0FEED,
    ),
  );
}

class _Celebration extends StatefulWidget {
  const _Celebration({
    required this.icon,
    required this.headline,
    required this.badge,
    required this.message,
    required this.seed,
  });

  final IconData icon;
  final String headline;
  final String badge;
  final String message;

  /// Fixes the chip layout, so the same win always bursts the same way.
  final int seed;

  @override
  State<_Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<_Celebration>
    with SingleTickerProviderStateMixin {
  static const _burst = Duration(milliseconds: 2600);

  late final AnimationController _confetti = AnimationController(
    vsync: this,
    duration: _burst,
  )..forward();

  @override
  void initState() {
    super.initState();
    Haptics.success();
  }

  late final List<ConfettiParticle> _particles = ConfettiParticle.burst(
    count: 85,
    seed: widget.seed,
  );

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Confetti sits behind and around the card, and ignores pointers
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _confetti,
                builder: (context, _) => CustomPaint(
                  painter: ConfettiPainter(
                    particles: _particles,
                    progress: _confetti.value,
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: ScaleTransition(
                scale: CurvedAnimation(
                  parent: _confetti,
                  curve: const Interval(0.0, 0.4, curve: Curves.easeOutBack),
                ),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  elevation: 12,
                  shadowColor: Colors.black.withValues(alpha: 0.2),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedBuilder(
                          animation: _confetti,
                          builder: (context, child) {
                            final scale = 0.8 + 0.2 * CurvedAnimation(
                              parent: _confetti,
                              curve: const Interval(0.1, 0.5, curve: Curves.elasticOut),
                            ).value;
                            return Transform.scale(
                              scale: scale,
                              child: child,
                            );
                          },
                          child: Container(
                            height: 68,
                            width: 68,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.25),
                                  blurRadius: 16,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              widget.icon,
                              size: 34,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          widget.headline,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            height: 1.15,
                            color: Color(0xFF16211A),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.25),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            widget.badge,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          widget.message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13.5,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF6B7A70),
                          ),
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () {
                              Haptics.light();
                              Navigator.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Continue',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// What a coupon screen hands back to the cart that opened it, so the cart can
/// celebrate on its own context once the picker has closed.
class CouponWin {
  const CouponWin({required this.code, required this.savings});

  final String code;
  final double savings;
}
