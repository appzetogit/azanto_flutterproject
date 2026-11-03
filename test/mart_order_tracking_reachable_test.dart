import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:azanto/src/quick/core/local_storage/local_storage.dart';
import 'package:azanto/src/quick/di/repository_providers.dart';
import 'package:azanto/src/quick/di/usecase_providers.dart';
import 'package:azanto/src/quick/domain/model/address.dart';
import 'package:azanto/src/quick/domain/model/cart.dart';
import 'package:azanto/src/quick/domain/model/order.dart';
import 'package:azanto/src/quick/domain/model/order_status.dart';
import 'package:azanto/src/quick/domain/model/paged_result.dart';
import 'package:azanto/src/quick/domain/model/payment_method.dart';
import 'package:azanto/src/quick/domain/repository/order_repository.dart';
import 'package:azanto/src/quick/di/service_providers.dart';
import 'package:azanto/src/quick/domain/service/checkout_validation_service.dart';
import 'package:azanto/src/quick/domain/usecase/place_order_usecase.dart';
import 'package:azanto/src/quick/ui/screens/checkout/checkout_provider.dart';
import 'package:azanto/src/quick/ui/screens/order/orders_list/orders_provider.dart';

/// Dismissing the Mart "order placed" screen left tracking unreachable.
///
/// Home's active-order card is the only way back to tracking once that screen
/// is gone, and it reads `ordersProvider`. The list is loaded once, and the
/// card's poll timer refreshes only when it ALREADY knows about an active order
/// — a guard that stops it hammering /quick/orders for every signed-in shopper,
/// but which therefore can never discover an order placed after the last load.
/// The card stayed hidden and the shopper was stranded on home.
Order _order(String id, OrderStatus status) => Order(
      id: id,
      displayId: 'FOD-$id',
      status: status,
      lines: const [],
      pricing: const CartPricing(),
      placedAt: DateTime(2026, 8, 23),
    );

/// The cart persists itself; nothing here cares where.
class _MemoryStorage implements LocalStorage {
  final _values = <String, Object>{};
  @override
  String? getString(String key) => _values[key] as String?;
  @override
  Future<void> setString(String key, String value) async => _values[key] = value;
  @override
  bool? getBool(String key) => _values[key] as bool?;
  @override
  Future<void> setBool(String key, bool value) async => _values[key] = value;
  @override
  List<String> getStringList(String key) =>
      (_values[key] as List<String>?) ?? const [];
  @override
  Future<void> setStringList(String key, List<String> value) async =>
      _values[key] = value;
  @override
  Future<void> remove(String key) async => _values.remove(key);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

/// Stands in for the server, counting how often the list is fetched.
class _FakeOrderRepository implements OrderRepository {
  int listCalls = 0;
  List<Order> serverOrders = const [];

  @override
  Future<PagedResult<Order>> list({int page = 1, int pageSize = 15}) async {
    listCalls++;
    return PagedResult(
      items: serverOrders,
      total: serverOrders.length,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

/// Passes every checkout precondition. This test is about what happens after a
/// successful placement, not about the validation that precedes it.
class _AlwaysValid implements CheckoutValidationService {
  const _AlwaysValid();

  @override
  List<CheckoutIssue> validate({
    required Cart cart,
    required Address? address,
    PaymentMethod? method,
    bool requirePayment = false,
  }) =>
      const [];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

class _FakePlaceOrder implements PlaceOrderUseCase {
  _FakePlaceOrder(this.placed, this.repository);

  final Order placed;
  final _FakeOrderRepository repository;

  @override
  Future<PlaceOrderOutcome> call({
    required Cart cart,
    required Address? address,
    required PaymentMethod method,
    String? customerName,
    String? customerPhone,
    String? instructions,
    bool sendCutlery = false,
    DateTime? scheduledAt,
  }) async {
    // The order now exists server-side — exactly the state the stale list misses.
    repository.serverOrders = [placed, ...repository.serverOrders];
    return OrderPlaced(PlacedOrder(order: placed));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

void main() {
  // The api client hydrates its cache from SharedPreferences on construction,
  // which needs the binding even though nothing here goes near the network.
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late _FakeOrderRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = _FakeOrderRepository();
    container = ProviderContainer(
      overrides: [
        localStorageProvider.overrideWithValue(_MemoryStorage()),
        orderRepositoryProvider.overrideWithValue(repo),
        placeOrderUseCaseProvider.overrideWithValue(
          _FakePlaceOrder(_order('o1', OrderStatus.created), repo),
        ),
        checkoutValidationServiceProvider
            .overrideWithValue(const _AlwaysValid()),
      ],
    );
    addTearDown(container.dispose);
  });

  test('a placed order reaches the list the tracking card reads', () async {
    // The shopper's list was loaded before they ordered, so it holds nothing.
    await container.read(ordersProvider.notifier).load(reset: true);
    expect(container.read(ordersProvider).active, isEmpty);
    final callsBeforeOrder = repo.listCalls;

    await container
        .read(checkoutProvider.notifier)
        .placeOrder(name: 'Tanu', phone: '9999900001');
    // The refresh is fired without awaiting, so let it land.
    await Future<void>.delayed(Duration.zero);

    expect(repo.listCalls, greaterThan(callsBeforeOrder),
        reason: 'placing an order must refresh the stale list');
    expect(
      container.read(ordersProvider).active.map((o) => o.id),
      ['o1'],
      reason: 'home\'s card needs the new order, or tracking is unreachable',
    );
  });

  test('a freshly created order counts as active', () {
    // The card renders nothing unless the order is `active`; `created` is the
    // status every order starts in, so this is the case that matters most.
    expect(_order('o2', OrderStatus.created).status.isActive, isTrue);
  });
}
