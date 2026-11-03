import 'package:flutter/material.dart';
import '../celebration/confetti.dart';

/// "Get FREE delivery" with a bar showing how close the cart is to the
/// threshold, or a success line once it is cleared.
///
/// Shared by both carts so Mart and Food cannot drift apart on the same
/// promise. Every number is passed in — the threshold comes from the backend's
/// fee settings and the spend from the live cart, so the bar moves on every
/// add, remove and quantity change without this widget knowing where either
/// came from.
class FreeDeliveryProgress extends StatefulWidget {
  const FreeDeliveryProgress({
    super.key,
    required this.spent,
    required this.threshold,
    required this.formatAmount,
    this.onTap,
  });

  /// Cart value counted toward free delivery.
  final double spent;

  /// The backend's free-delivery threshold. Zero or less means the shop does
  /// not run the offer, and the section hides itself entirely.
  final double threshold;

  /// Currency formatting belongs to the host app, which already has one.
  final String Function(double amount) formatAmount;

  final VoidCallback? onTap;

  @override
  State<FreeDeliveryProgress> createState() => _FreeDeliveryProgressState();
}

class _FreeDeliveryProgressState extends State<FreeDeliveryProgress>
    with SingleTickerProviderStateMixin {
  static const _blue = Color(0xFF1A6DD9);
  static const _blueSoft = Color(0xFFEAF2FE);
  static const _track = Color(0xFFD6E4F7);

  late final AnimationController _confettiController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  late List<ConfettiParticle> _particles = [];
  bool _wasUnlocked = false;

  bool get _unlocked => widget.spent >= widget.threshold;

  double get _fraction =>
      widget.threshold <= 0 ? 0 : (widget.spent / widget.threshold).clamp(0.0, 1.0);

  @override
  void initState() {
    super.initState();
    _wasUnlocked = _unlocked;
    if (_unlocked) {
      _triggerCelebration();
    }
  }

  @override
  void didUpdateWidget(FreeDeliveryProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_unlocked && !_wasUnlocked) {
      _triggerCelebration();
    }
    _wasUnlocked = _unlocked;
  }

  void _triggerCelebration() {
    _particles = ConfettiParticle.pop(
      count: 45,
      seed: DateTime.now().millisecondsSinceEpoch,
    );
    _confettiController.forward(from: 0);
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.threshold <= 0) return const SizedBox.shrink();
    final remaining = (widget.threshold - widget.spent).clamp(0.0, double.infinity);

    return Material(
      color: _blueSoft,
      child: InkWell(
        onTap: widget.onTap,
        child: ClipRect(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        AnimatedBuilder(
                          animation: _confettiController,
                          builder: (context, child) {
                            final scale = _unlocked
                                ? 1.0 + 0.2 * CurvedAnimation(
                                    parent: _confettiController,
                                    curve: const Interval(0.0, 0.4, curve: Curves.elasticOut),
                                  ).value
                                : 1.0;
                            return Transform.scale(scale: scale, child: child);
                          },
                          child: const Icon(
                            Icons.electric_bolt_rounded,
                            size: 18,
                            color: _blue,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _unlocked
                                ? 'You unlocked FREE delivery'
                                : 'Get FREE delivery',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: _blue,
                            ),
                          ),
                        ),
                        if (widget.onTap != null)
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: _blue,
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Padding(
                      padding: const EdgeInsets.only(left: 26),
                      child: Text(
                        _unlocked
                            ? 'No delivery charge on this order'
                            : 'Add products worth ${widget.formatAmount(remaining)} more',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF4B5563),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: TweenAnimationBuilder<double>(
                        // Animated so a quantity change slides the bar rather than
                        // snapping it, which is what makes the progress readable.
                        tween: Tween(begin: 0, end: _fraction),
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOut,
                        builder: (context, value, _) => LinearProgressIndicator(
                          value: value,
                          minHeight: 5,
                          backgroundColor: _track,
                          valueColor: const AlwaysStoppedAnimation<Color>(_blue),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_unlocked)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _confettiController,
                      builder: (context, _) => CustomPaint(
                        painter: ConfettiPainter(
                          particles: _particles,
                          progress: _confettiController.value,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
