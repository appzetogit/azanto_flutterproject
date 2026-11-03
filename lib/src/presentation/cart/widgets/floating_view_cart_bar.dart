import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../common_widgets/smart_image.dart';
import '../../branding/app_colors.dart';
import '../viewmodels/cart_viewmodel.dart';

class FloatingViewCartBar extends ConsumerStatefulWidget {
  final VoidCallback onTap;
  // How far from the bottom the bar sits when shown (hidden position follows
  // the same 144px slide-clear distance). Defaults to the Home Screen's
  // original hardcoded 24.0 so existing behavior there is unchanged; screens
  // with their own sticky bottom bar (e.g. Food Details) can raise this so
  // the two don't overlap.
  final double bottomOffset;

  /// Empties the cart this bar summarises. Null hides the Remove button, so a
  /// host that has no safe way to clear its cart simply does not offer one.
  final VoidCallback? onRemove;

  /// Optional data source override.
  ///
  /// Left null the bar reads the food cart, which is what every food screen
  /// does — their behaviour is unchanged. Mart passes its own cart's figures in
  /// so both verticals render this exact bar (same slide, bump, glow sweep and
  /// thumbnail stack) instead of growing a lookalike.
  final int? itemCount;
  final double? subtotal;
  final int? quantity;
  final List<String>? imageUrls;

  bool get _isExternal => itemCount != null;

  /// Height of the pill itself. Used both by the flight anchor and by
  /// [reservedBottomSpace].
  static const double barHeight = 56.0;

  /// Room a scroll view must leave under its last row so this bar does not
  /// come to rest on top of it.
  ///
  /// The bar floats over the content rather than taking a slot in the layout —
  /// that is what keeps it still while the page scrolls — so nothing reserves
  /// the space for it automatically and each scroll view has to ask.
  static double reservedBottomSpace(
    BuildContext context, {
    double bottomOffset = 24.0,
  }) {
    final view = View.of(context);
    final windowBottom = view.viewPadding.bottom / view.devicePixelRatio;
    final safeBottom =
        math.max(MediaQuery.of(context).viewPadding.bottom, windowBottom);
    // A little air under the bar so the last row is clear of it, not touching.
    return bottomOffset + safeBottom + barHeight + 12;
  }

  const FloatingViewCartBar({
    super.key,
    required this.onTap,
    this.bottomOffset = 24.0,
    this.itemCount,
    this.subtotal,
    this.quantity,
    this.imageUrls,
    this.onRemove,
  });

  @override
  ConsumerState<FloatingViewCartBar> createState() =>
      FloatingViewCartBarState();
}

class FloatingViewCartBarState extends ConsumerState<FloatingViewCartBar>
    with TickerProviderStateMixin {
  /// How far the bar is slid aside, 0 (closed) to 1 (Remove fully revealed).
  ///
  /// Driven directly by the drag while a finger is down and animated to one
  /// end or the other on release, so the bar never rests half-open.
  late AnimationController _slideController;

  /// How much of Remove is uncovered at full slide. Fixed rather than measured:
  /// the action behind is a known size, and a width that depended on the bar's
  /// own layout would change as the total counts up.
  static const double _revealWidth = 116.0;

  late AnimationController _bumpController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowPositionAnimation;
  late Animation<double> _amountScaleAnimation;

  // Stable, always-laid-out anchor marking where the bar sits when shown.
  // Add-to-cart flight animations target this (not the animated pill, whose
  // RenderBox is off-screen while the bar is hidden), so the product always
  // lands on the View Cart button even on the very first add.
  final GlobalKey _flightAnchorKey = GlobalKey();

  /// Flight target for the add-to-cart animation on this screen.
  GlobalKey get flightAnchorKey => _flightAnchorKey;

  @override
  void initState() {
    super.initState();
    _bumpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );

    // Smooth settle bounce
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.05,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.05,
          end: 0.97,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.97,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 40,
      ),
    ]).animate(_bumpController);

    // Glow Sweep moving from left (-0.5) to right (1.5)
    _glowPositionAnimation = Tween<double>(begin: -0.5, end: 1.5).animate(
      CurvedAnimation(parent: _bumpController, curve: Curves.easeInOut),
    );

    // Localized 1.0 -> 1.08 -> 1.0 pulse on just the total-amount text,
    // riding the same bump so it fires every time the total changes.
    _amountScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.08,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.08,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_bumpController);
  }

  @override
  void dispose() {
    _slideController.dispose();
    _bumpController.dispose();
    super.dispose();
  }

  /// Plays the settle-bounce + glow-sweep animation once. The bar itself
  /// stays visible as long as the cart has items (see [build]); this only
  /// signals that the cart was just updated.
  void bump() {
    _bumpController.forward(from: 0.0);
  }

  void _onDragUpdate(DragUpdateDetails d) {
    // Dragging left opens, so a negative dx raises the value.
    _slideController.value =
        (_slideController.value - d.primaryDelta! / _revealWidth).clamp(
          0.0,
          1.0,
        );
  }

  void _onDragEnd(DragEndDetails d) {
    // A deliberate flick decides on its own; a slow drag settles to whichever
    // end it is nearer. Without the velocity check a quick short swipe — the
    // natural gesture — would spring shut again.
    final flick = d.velocity.pixelsPerSecond.dx;
    final open = flick < -250 || (flick <= 250 && _slideController.value > 0.4);
    open ? _slideController.forward() : _slideController.reverse();
  }

  /// Tapping the bar opens the cart, unless it is slid aside — then the tap
  /// puts it back, which is the way out of the gesture for anyone who opened
  /// it by accident.
  void _onTapBar() {
    if (_slideController.value > 0) {
      _slideController.reverse();
      return;
    }
    widget.onTap();
  }

  /// Remove, sitting behind the bar and uncovered as it slides left.
  Widget _removeBehind(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // A pale wash of the theme's own error colour rather than a new pink: the
    // plate is a backdrop, and a saturated fill under a purple bar reads as a
    // warning the moment the bar moves at all.
    final plate = Color.alphaBlend(
      AppColors.error.withValues(alpha: 0.13),
      scheme.surface,
    );

    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _slideController.reverse();
          widget.onRemove?.call();
        },
        child: Container(
          width: _revealWidth,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: plate,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            'Remove',
            maxLines: 1,
            style: TextStyle(
              // Dark on the pale plate, as in the reference — the colour of
              // the word is not what makes it destructive, the label is.
              color: scheme.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // Small overlapping stack of the added-item thumbnails, shown on the
  // right end of the bar. Displays up to 3 thumbnails with a "+N" badge for
  // any remaining distinct items.
  Widget _buildItemStack(List<String> urls) {
    const double thumbSize = 34;
    const double step = 24; // horizontal shift per icon (10px overlap)

    final visible = urls.take(3).toList();
    final extra = urls.length - visible.length;
    final int slots = visible.length + (extra > 0 ? 1 : 0);
    final double width = thumbSize + (slots - 1) * step;

    return SizedBox(
      width: width,
      height: thumbSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int i = 0; i < visible.length; i++)
            Positioned(left: i * step, child: _squareThumb(visible[i])),
          if (extra > 0)
            Positioned(left: visible.length * step, child: _extraBadge(extra)),
        ],
      ),
    );
  }

  Widget _squareThumb(String url) {
    return Container(
      width: 34,
      height: 34,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SmartImage(
          url: url,
          category: ImageCategory.food,
          fit: BoxFit.cover,
          width: 30,
          height: 30,
        ),
      ),
    );
  }

  Widget _extraBadge(int extra) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Text(
        '+$extra',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  void didUpdateWidget(covariant FloatingViewCartBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Mart drives the bump through its quantity prop, since it has no food
    // provider to listen to.
    final previous = oldWidget.quantity;
    final next = widget.quantity;
    if (previous != null && next != null && next > previous) {
      _bumpController.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only subscribe to the food cart when this bar is actually driven by it;
    // Mart supplies its own figures and must not rebuild on food cart changes.
    final cartState = widget._isExternal
        ? null
        : ref.watch(cartViewModelProvider);

    // Animate the bar on every cart update (new item OR quantity increase),
    // signalling that the cart changed. The bar is not auto-hidden — it stays
    // up as long as the cart has items and only slides away when it empties.
    if (!widget._isExternal) {
      ref.listen(cartViewModelProvider, (previous, next) {
        final prevQty = previous?.totalQuantity ?? 0;
        if (next.totalQuantity > prevQty) {
          _bumpController.forward(from: 0.0);
        }
      });
    }

    final itemCount = widget.itemCount ?? cartState!.items.length;
    final subtotal = widget.subtotal ?? cartState!.subtotal;
    final urls =
        widget.imageUrls ??
        cartState!.items.map((i) => i.food.imageUrl).toList();
    final shouldShow = itemCount > 0;

    // Clear the system navigation area on every device.
    //
    // The offset a host passes is the gap it wants ABOVE the system bar, not
    // from the physical screen edge. The shells hide their own bottom nav on
    // scroll, and the moment that happens nothing covers the gesture inset any
    // more — so a bare `bottom: 12` dropped the bar into it and the pill came
    // out clipped. viewPadding (not padding) because it reports the inset even
    // while something is overlaying it, so the position does not jump as the
    // nav shows and hides.
    // Read from the view, not from MediaQuery alone.
    //
    // MediaQuery's inset is whatever is LEFT after ancestors have taken theirs:
    // any SafeArea above this bar consumes it and reports zero, and the bar
    // then rests 24px off the raw bottom of the window — behind the gesture
    // bar, which is exactly how it ended up clipped on the Mart screens. The
    // view's own padding is the physical inset and nothing can consume it.
    //
    // The larger of the two wins, so a host that genuinely does sit above the
    // system bar is not pushed up twice.
    final view = View.of(context);
    final windowBottom = view.viewPadding.bottom / view.devicePixelRatio;
    final safeBottom =
        math.max(MediaQuery.of(context).viewPadding.bottom, windowBottom);
    final restingBottom = widget.bottomOffset + safeBottom;

    return Positioned.fill(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Stable invisible flight anchor at the bar's shown position.
          Positioned(
            left: 20,
            right: 20,
            bottom: restingBottom,
            height: 56,
            child: IgnorePointer(child: SizedBox.expand(key: _flightAnchorKey)),
          ),

          AnimatedPositioned(
            duration: const Duration(milliseconds: 500),
            curve: Curves.elasticOut,
            bottom: shouldShow ? restingBottom : restingBottom - 144.0,
            left: 20,
            right: 20,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 500),
              curve: Curves.elasticOut,
              scale: shouldShow ? 1.0 : 0.0, // Grows from 0%
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Stack(
                  children: [
                    // Remove sits behind the bar, uncovered as it slides left — the
                    // same shape as a Dismissible's background, so the gesture reads
                    // the way it does everywhere else.
                    if (widget.onRemove != null)
                      Positioned.fill(child: _removeBehind(context)),

                    AnimatedBuilder(
                      animation: _slideController,
                      builder: (context, child) => Transform.translate(
                        offset: Offset(
                          -_revealWidth * _slideController.value,
                          0,
                        ),
                        child: child,
                      ),
                      child: GestureDetector(
                        onTap: _onTapBar,
                        // Only when there is something to reveal; without onRemove
                        // the bar should not move at all.
                        onHorizontalDragUpdate: widget.onRemove == null
                            ? null
                            : _onDragUpdate,
                        onHorizontalDragEnd: widget.onRemove == null
                            ? null
                            : _onDragEnd,
                        child: AnimatedBuilder(
                          animation: _bumpController,
                          builder: (context, child) {
                            return CustomPaint(
                              foregroundPainter: _GlowSweepPainter(
                                _glowPositionAnimation.value,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primaryAlpha(0.4),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    // Total amount (left) — smooth count-up + a subtle
                                    // 1.0 -> 1.08 -> 1.0 pulse every time it changes.
                                    Expanded(
                                      child: ScaleTransition(
                                        scale: _amountScaleAnimation,
                                        alignment: Alignment.centerLeft,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            TweenAnimationBuilder<double>(
                                              duration: const Duration(
                                                milliseconds: 400,
                                              ),
                                              curve: Curves.easeOut,
                                              tween: Tween(end: subtotal),
                                              builder: (context, val, child) {
                                                return Text(
                                                  '₹${val.toInt()}',
                                                  // Expanded gives this column whatever is
                                                  // left over, which is near zero once the
                                                  // Remove chip is out — without this the
                                                  // amount wrapped one character per line
                                                  // and the bar grew to four times its
                                                  // height.
                                                  maxLines: 1,
                                                  softWrap: false,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 17,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                );
                                              },
                                            ),
                                            TweenAnimationBuilder<double>(
                                              duration: const Duration(
                                                milliseconds: 300,
                                              ),
                                              curve: Curves.easeOutBack,
                                              tween: Tween(
                                                end: itemCount.toDouble(),
                                              ),
                                              builder: (context, val, child) {
                                                return Text(
                                                  '${val.round()} item${val.round() != 1 ? 's' : ''}',
                                                  maxLines: 1,
                                                  softWrap: false,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // Overlapping stack of added-item thumbnails (right end).
                                    //
                                    // Stood down while Remove is showing: three of these
                                    // plus the amount, View Cart AND Remove do not fit
                                    // across a phone, and the thumbnails are the only
                                    // part of that row nobody needs to read.
                                    if (urls.isNotEmpty) ...[
                                      _buildItemStack(urls),
                                      const SizedBox(width: 12),
                                    ],

                                    // View Cart label + chevron (right)
                                    const Text(
                                      'View Cart',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.chevron_right,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowSweepPainter extends CustomPainter {
  final double progress; // -0.5 to 1.5

  _GlowSweepPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= -0.5 || progress >= 1.5) return;

    final xPos = size.width * progress;

    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.6),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTRB(xPos - 40, 0, xPos + 40, size.height))
      ..blendMode = BlendMode.screen;

    // Draw the glow using a rectangle clipped to the rounded border
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(24)),
      );
    canvas.clipPath(path);
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _GlowSweepPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
