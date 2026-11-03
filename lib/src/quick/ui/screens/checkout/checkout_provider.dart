import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/utils/logger.dart';
import '../../../di/app_providers.dart';
import '../../../di/service_providers.dart';
import '../../../di/usecase_providers.dart';
import '../../../domain/model/delivery_slot.dart';
import '../../../domain/model/order.dart';
import '../../../domain/model/payment_method.dart';
import '../../../domain/service/checkout_validation_service.dart';
import '../../../domain/usecase/place_order_usecase.dart';
import '../order/orders_list/orders_provider.dart';
import 'checkout_state.dart';

class CheckoutController extends Notifier<CheckoutState> {
  @override
  CheckoutState build() {
    // Re-price whenever the chosen address changes: delivery fee is
    // distance-based, so a new address means a new bill.
    ref.listen(selectedAddressProvider, (previous, next) {
      if (previous?.id != next?.id) ref.read(cartProvider.notifier).priceNow();
    });
    Future.microtask(() => ref.read(cartProvider.notifier).priceNow());
    return const CheckoutState();
  }

  void setSlot(DeliverySlot slot) {
    state = state.copyWith(slot: slot);
    ref.read(cartProvider.notifier).priceNow();
  }

  void setPaymentMethod(PaymentMethod method) =>
      state = state.copyWith(paymentMethod: method);

  void setInstructions(String value) =>
      state = state.copyWith(instructions: value);

  void setSendCutlery(bool value) => state = state.copyWith(sendCutlery: value);

  void toggleSummary() =>
      state = state.copyWith(expandedSummary: !state.expandedSummary);

  void consumeShake() => state = state.copyWith(shakeAddressCard: false);

  /// Validates without placing, so the CTA can reflect readiness live.
  List<CheckoutIssue> currentIssues() =>
      ref.read(checkoutValidationServiceProvider).validate(
            cart: ref.read(cartProvider).cart,
            address: ref.read(selectedAddressProvider),
            method: state.paymentMethod,
            requirePayment: true,
          );

  /// Creates the order server-side. Returns null when blocked or on failure.
  Future<PlacedOrder?> placeOrder({required String? name, required String? phone}) async {
    final issues = currentIssues();
    if (issues.isNotEmpty) {
      state = state.copyWith(
        issues: issues,
        shakeAddressCard: issues.any((i) => i is MissingAddress),
      );
      return null;
    }

    state = state.copyWith(isPlacing: true, issues: const [], clearFailure: true);
    final cart = ref.read(cartProvider).cart;
    AppLogger.debug(
      'placing order: method=${state.paymentMethod.orderWireValue} '
      'seller=${cart.sellerId} items=${cart.items.length} '
      'total=${cart.pricing.total}',
      scope: 'payment',
    );
    try {
      final outcome = await ref.read(placeOrderUseCaseProvider)(
        cart: cart,
        address: ref.read(selectedAddressProvider),
        method: state.paymentMethod,
        customerName: name,
        customerPhone: phone,
        instructions: state.instructions,
        sendCutlery: state.sendCutlery,
        scheduledAt: state.slot.scheduledAt,
      );

      state = state.copyWith(isPlacing: false);
      return switch (outcome) {
        OrderPlaced(:final placedOrder) => () {
            // Pull the new order into the orders list straight away.
            //
            // Home's active-order card — the only way back to tracking once the
            // success screen is dismissed — reads `ordersProvider`, and its poll
            // timer deliberately refreshes ONLY when it already knows about an
            // active order (otherwise it hammered /quick/orders every 8s for
            // every signed-in shopper). That guard cannot discover an order
            // placed after the list was last loaded, so without this the card
            // never appeared and tracking was unreachable until the Orders tab
            // was opened by hand. Placing an order is the event that makes the
            // list stale, so it is the right moment to refresh it.
            unawaited(ref.read(ordersProvider.notifier).load(reset: true));
            return placedOrder;
          }(),
        OrderBlocked(:final issues) => () {
            state = state.copyWith(issues: issues);
            return null;
          }(),
      };
    } catch (e) {
      state = state.copyWith(
        isPlacing: false,
        failure: ErrorMapper.toFailure(e),
      );
      return null;
    }
  }
}

final checkoutProvider =
    NotifierProvider<CheckoutController, CheckoutState>(CheckoutController.new);
