import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presentation/address/viewmodels/address_viewmodel.dart';
import '../../presentation/auth/viewmodels/auth_viewmodel.dart';
import '../../shared/address/global_address.dart';
import '../core/errors/app_exception.dart';
import '../core/errors/error_mapper.dart';
import '../core/errors/failure.dart';
import '../data/repository_impl/quick_auth_repository.dart';
import '../domain/model/address.dart';
import '../domain/model/addon.dart';
import '../domain/model/cart.dart';
import '../domain/model/coupon.dart';
import '../domain/model/product.dart';
import '../domain/model/product_variant.dart';
import '../domain/model/user.dart';
import '../domain/usecase/add_to_cart_usecase.dart';
import '../domain/usecase/apply_coupon_usecase.dart';
import 'repository_providers.dart';
import 'usecase_providers.dart';

// ── Connectivity ────────────────────────────────────────────────────────────

/// Online/offline, used to show the offline banner and gate network actions.
final connectivityProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  final initial = await connectivity.checkConnectivity();
  yield _isOnline(initial);
  yield* connectivity.onConnectivityChanged.map(_isOnline);
});

bool _isOnline(List<ConnectivityResult> results) =>
    results.any((r) => r != ConnectivityResult.none);

final isOfflineProvider = Provider<bool>(
  (ref) => ref.watch(connectivityProvider).value == false,
);

// ── Auth ────────────────────────────────────────────────────────────────────

class AuthState {
  const AuthState({this.user, this.isLoading = false});

  final User? user;
  final bool isLoading;

  bool get isSignedIn => user != null;
}

/// Bridges the shared Azanto session into this module's [AuthState]. The
/// shared auth layer owns login, token restore and FCM registration; this
/// controller only mirrors it, so both verticals always agree on who is
/// signed in.
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    final shared = ref.watch(authViewModelProvider);
    final user = shared.value;
    return AuthState(
      user: user == null ? null : quickUserFromShared(user),
      isLoading: shared.isLoading,
    );
  }

  Future<void> refresh() =>
      ref.read(authViewModelProvider.notifier).refreshProfile();

  void setUser(User user) => state = AuthState(user: user);

  Future<void> signOut() async {
    state = const AuthState(isLoading: true);
    await ref.read(authRepositoryProvider).signOut();
    ref.read(cartProvider.notifier).clearLocal();
    ref.invalidate(wishlistProvider);
    state = const AuthState();
  }
}

final authProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);

// ── Selected delivery address ───────────────────────────────────────────────

class AddressBookState {
  const AddressBookState({
    this.addresses = const [],
    this.selectedId,
    this.isLoading = false,
    this.failure,
  });

  final List<Address> addresses;
  final String? selectedId;
  final bool isLoading;
  final Failure? failure;

  Address? get selected {
    if (addresses.isEmpty) return null;
    for (final a in addresses) {
      if (a.id == selectedId) return a;
    }
    return addresses.first;
  }

  AddressBookState copyWith({
    List<Address>? addresses,
    String? selectedId,
    bool? isLoading,
    Failure? failure,
    bool clearFailure = false,
  }) =>
      AddressBookState(
        addresses: addresses ?? this.addresses,
        selectedId: selectedId ?? this.selectedId,
        isLoading: isLoading ?? this.isLoading,
        failure: clearFailure ? null : (failure ?? this.failure),
      );
}

/// Quick-commerce's view of the ONE Azanto address book.
///
/// This holds no addresses of its own: it projects the global list
/// ([addressViewModelProvider]) into this module's [Address] model and forwards
/// every mutation to it. An address added or made default in either vertical is
/// therefore visible in the other with no sync step — same rows, same selection.
class AddressBookController extends Notifier<AddressBookState> {
  @override
  AddressBookState build() {
    final shared = ref.watch(addressViewModelProvider);
    final selected = ref.watch(globalSelectedAddressProvider);
    return AddressBookState(
      addresses: [for (final a in shared) a.toQuick()],
      selectedId: selected?.id,
      isLoading: ref.watch(addressViewModelProvider.notifier).isLoading,
    );
  }

  Future<void> load() => ref.read(addressViewModelProvider.notifier).load();

  Future<void> select(String addressId) async =>
      ref.read(selectedAddressIdProvider.notifier).select(addressId);

  Future<Address> add(Address address) async {
    final saved = await ref
        .read(addressViewModelProvider.notifier)
        .addAddress(address.toShared());
    if (saved == null) throw _lastAddressFailure(ref);
    await select(saved.id);
    return saved.toQuick();
  }

  Future<Address> update(Address address) async {
    final ok = await ref
        .read(addressViewModelProvider.notifier)
        .editAddress(address.toShared());
    if (!ok) throw _lastAddressFailure(ref);
    await select(address.id);
    return address;
  }

  Future<void> remove(String addressId) async {
    final ok =
        await ref.read(addressViewModelProvider.notifier).deleteAddress(addressId);
    if (!ok) throw _lastAddressFailure(ref);
    if (ref.read(selectedAddressIdProvider) == addressId) {
      await select('');
    }
  }

  Future<void> makeDefault(String addressId) async {
    final ok = await ref
        .read(addressViewModelProvider.notifier)
        .setDefaultAddress(addressId);
    if (!ok) throw _lastAddressFailure(ref);
  }
}

/// The shared view model reports failures on a field rather than by throwing;
/// quick's callers expect an exception, so re-raise it at the boundary.
/// Must be an [AppException] — a bare `Exception` isn't recognised by
/// [ErrorMapper.toFailure] and its message gets replaced with a generic one.
AppException _lastAddressFailure(Ref ref) => UnknownException(
      ref.read(addressViewModelProvider.notifier).error ??
          'Could not save the address. Please try again.',
    );

final addressBookProvider =
    NotifierProvider<AddressBookController, AddressBookState>(
  AddressBookController.new,
);

/// Convenience for the many screens that only need the chosen address.
final selectedAddressProvider =
    Provider<Address?>((ref) => ref.watch(addressBookProvider).selected);

// ── Cart (global: the badge is visible on every tab) ────────────────────────

class CartState {
  const CartState({
    this.cart = Cart.empty,
    this.isPricing = false,
    this.failure,
    this.lastAddedProductId,
  });

  final Cart cart;
  final bool isPricing;
  final Failure? failure;

  /// Drives the fly-to-cart confirmation animation.
  final String? lastAddedProductId;

  CartState copyWith({
    Cart? cart,
    bool? isPricing,
    Failure? failure,
    String? lastAddedProductId,
    bool clearFailure = false,
  }) =>
      CartState(
        cart: cart ?? this.cart,
        isPricing: isPricing ?? this.isPricing,
        failure: clearFailure ? null : (failure ?? this.failure),
        lastAddedProductId: lastAddedProductId ?? this.lastAddedProductId,
      );
}

class CartController extends Notifier<CartState> {
  Timer? _priceDebounce;

  @override
  CartState build() {
    scheduleMicrotask(_restore);
    ref.onDispose(() => _priceDebounce?.cancel());
    return const CartState();
  }

  Future<void> _restore() async {
    final cached = await ref.read(cartRepositoryProvider).loadCached();
    if (cached.isNotEmpty) {
      state = state.copyWith(cart: cached);
      schedulePricing();
    }
  }

  Future<AddToCartOutcome> add(
    Product product, {
    ProductVariant? variant,
    List<Addon> addons = const [],
    int quantity = 1,
    bool replaceSeller = false,
    bool skipVariantPrompt = false,
  }) async {
    final outcome = await ref.read(addToCartUseCaseProvider)(
      state.cart,
      product: product,
      variant: variant,
      addons: addons,
      quantity: quantity,
      replaceSeller: replaceSeller,
      skipVariantPrompt: skipVariantPrompt,
    );

    if (outcome is CartUpdated) {
      state = state.copyWith(
        cart: outcome.cart,
        lastAddedProductId: product.id,
        clearFailure: true,
      );
      schedulePricing();
    }
    return outcome;
  }

  Future<void> setQuantity(String lineId, int quantity) async {
    final cart = await ref
        .read(addToCartUseCaseProvider)
        .setQuantity(state.cart, lineId, quantity);
    state = state.copyWith(cart: cart, clearFailure: true);
    schedulePricing();
  }

  Future<void> increment(String lineId) async {
    final line = state.cart.lineById(lineId);
    if (line == null) return;
    await setQuantity(lineId, line.quantity + 1);
  }

  Future<void> decrement(String lineId) async {
    final line = state.cart.lineById(lineId);
    if (line == null) return;
    await setQuantity(lineId, line.quantity - 1);
  }

  Future<void> removeLine(String lineId) => setQuantity(lineId, 0);

  Future<void> clear() async {
    await ref.read(addToCartUseCaseProvider).clear();
    state = const CartState();
  }

  /// Drops the in-memory cart without touching the server (used on sign-out).
  void clearLocal() => state = const CartState();

  Future<void> setDeliveryMode(String mode) async {
    state = state.copyWith(cart: state.cart.copyWith(deliveryMode: mode));
    await priceNow();
  }

  /// Coalesces the rapid stepper taps that would otherwise fire a pricing call
  /// per tap.
  void schedulePricing() {
    _priceDebounce?.cancel();
    if (state.cart.isEmpty) return;
    _priceDebounce = Timer(const Duration(milliseconds: 450), priceNow);
  }

  Future<void> priceNow() async {
    if (state.cart.isEmpty) return;
    if (!ref.read(authProvider).isSignedIn) return;

    state = state.copyWith(isPricing: true, clearFailure: true);
    try {
      final priced = await ref.read(priceCartUseCaseProvider)(
        state.cart,
        address: ref.read(selectedAddressProvider),
      );
      state = state.copyWith(cart: priced, isPricing: false);
    } catch (e) {
      state = state.copyWith(isPricing: false, failure: ErrorMapper.toFailure(e));
    }
  }

  /// Sets the delivery-partner tip and reprices, so the bill and the pay button
  /// move with the chip the shopper just tapped.
  Future<void> setDeliveryTip(double amount) async {
    final tip = amount < 0 ? 0.0 : amount;
    if (state.cart.deliveryTip == tip) return;
    state = state.copyWith(cart: state.cart.copyWith(deliveryTip: tip));
    await priceNow();
  }

  Future<CouponOutcome> applyCoupon(Coupon coupon) async {
    state = state.copyWith(isPricing: true, clearFailure: true);
    try {
      final outcome = await ref.read(applyCouponUseCaseProvider)(
        state.cart,
        coupon,
        address: ref.read(selectedAddressProvider),
      );
      if (outcome is CouponApplied) {
        state = state.copyWith(cart: outcome.cart, isPricing: false);
      } else {
        state = state.copyWith(isPricing: false);
      }
      return outcome;
    } catch (e) {
      state = state.copyWith(isPricing: false, failure: ErrorMapper.toFailure(e));
      return CouponRejected(ErrorMapper.toFailure(e).message);
    }
  }

  Future<void> removeCoupon() async {
    state = state.copyWith(isPricing: true);
    try {
      final cart = await ref.read(applyCouponUseCaseProvider).remove(
            state.cart,
            address: ref.read(selectedAddressProvider),
          );
      state = state.copyWith(cart: cart, isPricing: false);
    } catch (e) {
      state = state.copyWith(isPricing: false, failure: ErrorMapper.toFailure(e));
    }
  }
}

final cartProvider = NotifierProvider<CartController, CartState>(CartController.new);

/// Scoped so the badge does not rebuild whole screens.
final cartItemCountProvider =
    Provider<int>((ref) => ref.watch(cartProvider.select((s) => s.cart.itemCount)));

// ── Wishlist ────────────────────────────────────────────────────────────────

class WishlistController extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    if (!ref.watch(authProvider).isSignedIn) return {};
    return ref.read(wishlistRepositoryProvider).ids();
  }

  Future<void> toggle(String productId) async {
    final current = state.value ?? {};
    // Optimistic: the heart must respond instantly.
    final optimistic = {...current};
    if (!optimistic.remove(productId)) optimistic.add(productId);
    state = AsyncData(optimistic);

    try {
      final updated = await ref.read(toggleWishlistUseCaseProvider)(current, productId);
      state = AsyncData(updated);
    } catch (_) {
      state = AsyncData(current);
      rethrow;
    }
  }

  bool contains(String productId) =>
      (state.value ?? const <String>{}).contains(productId);
}

final wishlistProvider =
    AsyncNotifierProvider<WishlistController, Set<String>>(WishlistController.new);

final isWishlistedProvider = Provider.family<bool, String>(
  (ref, productId) =>
      ref.watch(wishlistProvider).value?.contains(productId) ?? false,
);
