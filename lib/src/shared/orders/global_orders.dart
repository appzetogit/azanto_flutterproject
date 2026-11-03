import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presentation/mode/app_mode.dart';
import '../../presentation/orders/viewmodels/orders_viewmodel.dart';
import '../../quick/domain/model/order_status.dart';
import '../../quick/ui/screens/order/orders_list/orders_provider.dart' as quick;

/// One order history for Azanto.
///
/// The backend keeps orders per vertical — `/food/orders` and `/quick/orders`
/// are separate lists and there is no cross-vertical endpoint — so "All" is
/// assembled here from both, newest first. Each row remembers which vertical it
/// came from, which is what lets a tap open the right details screen.
class OrderSummary {
  const OrderSummary({
    required this.id,
    required this.displayId,
    required this.mode,
    required this.storeName,
    required this.statusLabel,
    required this.total,
    required this.itemCount,
    required this.isActive,
    this.imageUrl = '',
    this.placedAt,
  });

  final String id;
  final String displayId;
  final AppMode mode;
  final String storeName;
  final String statusLabel;
  final double total;
  final int itemCount;
  final bool isActive;
  final String imageUrl;
  final DateTime? placedAt;

  bool get isFood => mode == AppMode.food;

  /// Where a tap goes — each vertical keeps its own details screen because the
  /// information they show genuinely differs (dishes and cutlery vs packs,
  /// stock and per-line GST).
  String get detailsRoute =>
      isFood ? '/orders/details/$id' : '/quick/order/$id';
}

/// Every order the signed-in user has placed, across both verticals.
///
/// Reads the two existing per-vertical view models rather than fetching again,
/// so this list stays in step with whatever each vertical has already loaded
/// (including socket-driven status updates) and costs no extra requests.
final globalOrdersProvider = Provider<List<OrderSummary>>((ref) {
  final food = ref.watch(ordersViewModelProvider).orders.map(
        (o) => OrderSummary(
          id: o.id,
          displayId: o.orderNumber,
          mode: AppMode.food,
          storeName: o.restaurantName,
          statusLabel: o.statusLabel,
          total: o.total,
          itemCount: o.items.length,
          isActive: o.isActive,
          imageUrl: o.restaurantImage,
          placedAt: o.createdAt,
        ),
      );

  final quickOrders = ref.watch(quick.ordersProvider).orders.map(
        (o) => OrderSummary(
          id: o.id,
          displayId: o.displayId,
          mode: AppMode.quick,
          storeName: o.sellerName,
          statusLabel: o.status.label,
          total: o.pricing.total,
          itemCount: o.lines.length,
          isActive:
              !o.status.isCancelled && o.status != OrderStatus.delivered,
          imageUrl: o.sellerImageUrl,
          placedAt: o.placedAt,
        ),
      );

  final all = [...food, ...quickOrders];
  all.sort((a, b) {
    final at = a.placedAt, bt = b.placedAt;
    if (at == null && bt == null) return 0;
    if (at == null) return 1;
    if (bt == null) return -1;
    return bt.compareTo(at);
  });
  return all;
});

/// True while either vertical is still loading its first page.
final globalOrdersLoadingProvider = Provider<bool>((ref) {
  final food = ref.watch(ordersViewModelProvider);
  final q = ref.watch(quick.ordersProvider);
  return (food.isLoading && food.orders.isEmpty) ||
      (q.isLoading && q.orders.isEmpty);
});
