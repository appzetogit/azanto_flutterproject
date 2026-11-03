/// Mirrors the backend order model's status enum exactly.
///
/// (`src/constants/orderStatus.js` is empty upstream; the enum lives on the
/// Mongoose model, which is what these wire values are copied from.)
enum OrderStatus {
  pendingPayment('pending_payment', 'Awaiting payment'),
  created('created', 'Order placed'),
  confirmed('confirmed', 'Order confirmed'),
  preparing('preparing', 'Packing your order'),
  readyForPickup('ready_for_pickup', 'Ready for pickup'),
  reachedPickup('reached_pickup', 'Rider at the store'),
  pickedUp('picked_up', 'Out for delivery'),
  reachedDrop('reached_drop', 'Rider has arrived'),
  delivered('delivered', 'Delivered'),
  cancelledByUser('cancelled_by_user', 'Cancelled by you'),
  cancelledByRestaurant('cancelled_by_restaurant', 'Cancelled by the store'),
  cancelledByAdmin('cancelled_by_admin', 'Cancelled by support');

  const OrderStatus(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static OrderStatus fromWire(String? value) {
    if (value == null || value.trim().isEmpty) return OrderStatus.created;
    final normalized = value.trim().toLowerCase();

    for (final s in OrderStatus.values) {
      if (s.wireValue == normalized) return s;
    }

    if (normalized.contains('restaurant') ||
        normalized.contains('seller') ||
        normalized.contains('store') ||
        normalized.contains('vendor')) {
      return OrderStatus.cancelledByRestaurant;
    }
    if (normalized.contains('user') || normalized.contains('customer')) {
      return OrderStatus.cancelledByUser;
    }
    if (normalized.startsWith('cancel') ||
        normalized.startsWith('reject') ||
        normalized == 'failed' ||
        normalized == 'expired') {
      return OrderStatus.cancelledByRestaurant;
    }

    return OrderStatus.created;
  }

  bool get isCancelled => const {
        OrderStatus.cancelledByUser,
        OrderStatus.cancelledByRestaurant,
        OrderStatus.cancelledByAdmin,
      }.contains(this);

  bool get isTerminal => this == OrderStatus.delivered || isCancelled;

  bool get isActive => !isTerminal && this != OrderStatus.pendingPayment;

  /// Cancellable by the customer until the kitchen is done — accepted orders
  /// included — while the 90-second window is open (backend rule).
  bool get isCancellable => const {
        OrderStatus.created,
        OrderStatus.confirmed,
        OrderStatus.preparing,
      }.contains(this);

  bool get isOutForDelivery => const {
        OrderStatus.pickedUp,
        OrderStatus.reachedDrop,
      }.contains(this);
}

/// The five customer-facing tracking milestones. Several backend statuses
/// collapse into one step so the timeline stays readable.
enum TrackingStep {
  placed('Order placed'),
  confirmed('Order confirmed'),
  packing('Packing your order'),
  outForDelivery('Out for delivery'),
  delivered('Delivered');

  const TrackingStep(this.label);

  final String label;

  static TrackingStep forStatus(OrderStatus status) => switch (status) {
        OrderStatus.pendingPayment || OrderStatus.created => TrackingStep.placed,
        OrderStatus.confirmed => TrackingStep.confirmed,
        OrderStatus.preparing ||
        OrderStatus.readyForPickup ||
        OrderStatus.reachedPickup =>
          TrackingStep.packing,
        OrderStatus.pickedUp || OrderStatus.reachedDrop => TrackingStep.outForDelivery,
        OrderStatus.delivered => TrackingStep.delivered,
        _ => TrackingStep.placed,
      };
}
