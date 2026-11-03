import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/order_model.dart';
import '../../../di/order_providers.dart';
import '../../../di/socket_providers.dart';
import '../../../platform/realtime/socket_service.dart';
import '../../../quick/di/repository_providers.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';

class ActiveOrderState {
  final OrderModel? activeOrder;
  final bool isLoading;

  const ActiveOrderState({
    this.activeOrder,
    this.isLoading = false,
  });

  ActiveOrderState copyWith({
    OrderModel? activeOrder,
    bool? isLoading,
    bool clearActiveOrder = false,
  }) {
    return ActiveOrderState(
      activeOrder: clearActiveOrder ? null : (activeOrder ?? this.activeOrder),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

final activeOrderViewModelProvider =
    NotifierProvider<ActiveOrderViewModel, ActiveOrderState>(ActiveOrderViewModel.new);

class ActiveOrderViewModel extends Notifier<ActiveOrderState> {
  Timer? _pollingTimer;
  StreamSubscription<OrderSocketMessage>? _socketSub;
  StreamSubscription? _quickSocketSub;
  String? _joinedOrderId;

  @override
  ActiveOrderState build() {
    ref.onDispose(() {
      _pollingTimer?.cancel();
      _socketSub?.cancel();
      _quickSocketSub?.cancel();
      final id = _joinedOrderId;
      if (id != null) ref.read(socketServiceProvider).leaveTracking(id);
    });

    final user = ref.watch(authViewModelProvider).value;

    if (user != null) {
      unawaited(Future.microtask(fetchActiveOrder));
      _socketSub ??= ref.read(socketServiceProvider).orderEvents.listen((message) {
        if (kDebugMode) debugPrint('[TRACKING] Socket Event Received: ${message.event}');
        unawaited(fetchActiveOrder());
      });
      _quickSocketSub ??= ref.read(realtimeSocketProvider).orderStatusUpdates.listen((event) {
        if (kDebugMode) debugPrint('[TRACKING] Quick Socket Event Received: ${event.status}');
        unawaited(fetchActiveOrder());
      });
    } else {
      _stopPolling();
      _leaveRoom();
    }

    return const ActiveOrderState();
  }

  Future<void> fetchActiveOrder({bool isRefresh = false}) async {
    try {
      if (kDebugMode) debugPrint('[HOME] Loading active order');

      final activeList = <OrderModel>[];

      try {
        final result = await ref.read(orderRemoteDataSourceProvider).getOrderModels(page: 1);
        activeList.addAll(result.orders.where((o) => o.isActive));
      } catch (e) {
        if (kDebugMode) debugPrint('[HOME] Fetch food active order failed: $e');
      }

      try {
        final quickPage = await ref.read(orderRepositoryProvider).list(page: 1);
        for (final q in quickPage.items) {
          if (q.status.isActive) {
            activeList.add(OrderModel(
              id: q.id,
              orderNumber: q.displayId,
              orderStatus: q.status.wireValue,
              restaurantName: q.sellerName,
              restaurantImage: q.sellerImageUrl,
              total: q.pricing.total,
              createdAt: q.placedAt,
              eta: OrderEta(minutes: q.etaMinutes),
              items: q.lines
                  .map((l) => OrderItem(
                        itemId: l.itemId,
                        name: l.name,
                        price: l.price,
                        quantity: l.quantity,
                        imageUrl: l.imageUrl,
                        isVeg: l.isVeg,
                      ))
                  .toList(),
            ));
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[HOME] Fetch quick active order failed: $e');
      }

      activeList.sort((a, b) {
        final at = a.createdAt, bt = b.createdAt;
        if (at == null && bt == null) return 0;
        if (at == null) return 1;
        if (bt == null) return -1;
        return bt.compareTo(at);
      });

      if (activeList.isNotEmpty) {
        final latestActive = activeList.first;
        if (kDebugMode) {
          debugPrint('[HOME] Active order found: ID ${latestActive.id}');
          debugPrint('[HOME] Current status: ${latestActive.orderStatus}');
        }

        state = state.copyWith(activeOrder: latestActive, isLoading: false);

        _joinRoom(latestActive.id);
        _startPolling();
      } else {
        if (kDebugMode) debugPrint('[HOME] Widget visible = false');
        if (state.activeOrder != null) {
          if (kDebugMode) {
            debugPrint(
              '[HOME] Active order completed/cancelled. Clearing floating widget.',
            );
          }
          state = const ActiveOrderState();
        }
        _leaveRoom();
        _stopPolling();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[HOME] Fetch active order failed: $e');
    }
  }

  /// Joins the shared socket's tracking room for [orderId], switching rooms
  /// if a different order just became the active one.
  void _joinRoom(String orderId) {
    if (_joinedOrderId == orderId) return;
    final service = ref.read(socketServiceProvider);
    final previous = _joinedOrderId;
    if (previous != null) service.leaveTracking(previous);
    service.joinTracking(orderId);
    _joinedOrderId = orderId;
    if (kDebugMode) debugPrint('[TRACKING] Joined tracking room for $orderId');
  }

  void _leaveRoom() {
    final id = _joinedOrderId;
    if (id == null) return;
    ref.read(socketServiceProvider).leaveTracking(id);
    _joinedOrderId = null;
  }

  void _startPolling() {
    _pollingTimer ??= Timer.periodic(const Duration(seconds: 10), (_) {
      fetchActiveOrder();
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }
}
