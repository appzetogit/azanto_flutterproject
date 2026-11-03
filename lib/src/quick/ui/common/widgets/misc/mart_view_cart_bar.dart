import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../presentation/cart/widgets/floating_view_cart_bar.dart';
import '../../../../di/app_providers.dart';
import '../../../../navigation/route_paths.dart';

/// Mart's "View Cart" bar.
///
/// Deliberately *not* a new widget: it feeds Mart's cart figures into the food
/// module's [FloatingViewCartBar], so both verticals show the identical bar —
/// same elastic slide-in, bump-on-add, glow sweep, thumbnail stack and
/// count-up. Only the numbers come from a different cart.
class MartViewCartBar extends ConsumerStatefulWidget {
  const MartViewCartBar({super.key, this.bottomOffset = 24.0});

  final double bottomOffset;

  /// Where an add-to-cart flight should land, or null when no Mart bar is on
  /// screen.
  ///
  /// A plain registry rather than one shared GlobalKey: seven screens mount
  /// this bar and two are briefly alive together during a route transition,
  /// which the same key attached twice would crash on. The most recently
  /// mounted bar wins, which is the visible one.
  static GlobalKey? get activeFlightAnchor =>
      _active?.currentState?.flightAnchorKey;

  static GlobalKey<FloatingViewCartBarState>? _active;

  @override
  ConsumerState<MartViewCartBar> createState() => _MartViewCartBarState();
}

class _MartViewCartBarState extends ConsumerState<MartViewCartBar> {
  final _barKey = GlobalKey<FloatingViewCartBarState>();

  @override
  void initState() {
    super.initState();
    MartViewCartBar._active = _barKey;
  }

  @override
  void dispose() {
    // Only clear it if a newer bar has not already claimed the slot, or
    // leaving one screen would blind the flight on the next.
    if (identical(MartViewCartBar._active, _barKey)) {
      MartViewCartBar._active = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider.select((s) => s.cart));

    return FloatingViewCartBar(
      key: _barKey,
      // `go`, not `push`: push stacks the cart *over* the shell, leaving
      // currentIndex on Home, so the shell's "hide on the cart branch" guard
      // never fires and this bar floats on top of the cart it points at.
      onTap: () => context.go(RoutePaths.cart),
      bottomOffset: widget.bottomOffset,
      // Distinct lines drive visibility and the "N items" label; total quantity
      // drives the bump so bumping an existing line still animates.
      itemCount: cart.lineCount,
      // Server-calculated total when /calculate has run, provisional subtotal
      // until then — never a client-invented figure.
      subtotal: cart.effectiveTotal,
      quantity: cart.itemCount,
      imageUrls: cart.items.map((i) => i.product.imageUrl).toList(),
      // Clears Mart's cart server-side as well as locally, which is what
      // `clear()` does — `clearLocal()` would leave the mirrored cart behind and
      // it would come back on the next sync.
      onRemove: () => unawaited(ref.read(cartProvider.notifier).clear()),
    );
  }
}
