import 'dart:async';

import 'package:flutter/material.dart';
import '../../shared/celebration/free_delivery_celebration.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/haptics.dart';
import '../navigation/route_names.dart';
import '../branding/app_colors.dart';
import '../common_widgets/app_snackbar.dart';
import '../common_widgets/smart_image.dart';
import '../../data/models/cart_item_model.dart';
import '../../data/models/food_variant.dart';
import '../../data/models/order_pricing.dart';
import '../../data/models/restaurant_model.dart';
import '../auth/viewmodels/auth_viewmodel.dart';
import '../address/viewmodels/address_viewmodel.dart';
import '../../data/models/address_model.dart';
import '../../shared/address/global_address.dart';
import '../../di/catalog_providers.dart';
import 'viewmodels/cart_viewmodel.dart';
import '../checkout/viewmodels/checkout_viewmodel.dart';
import '../wallet/viewmodels/wallet_viewmodel.dart';
import '../restaurant/widgets/auto_scrolling_offers.dart';
import '../restaurant/widgets/food_detail_sheet.dart';
import 'widgets/cart_recommendations_section.dart';
import '../../shared/celebration/coupon_celebration.dart';
import 'widgets/coupon_sheet.dart';
import 'widgets/empty_cart_view.dart';
import '../../di/fee_settings_providers.dart';
import '../../shared/widgets/tip_your_driver_card.dart';
import '../../shared/widgets/free_delivery_progress.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  /// Where the free-delivery bar sits, so the unlock celebration can scroll
  /// the page to it before showing its card.
  final GlobalKey _freeDeliveryKey = GlobalKey();

  final GlobalKey _cartItemsCardKey = GlobalKey();

  // State for interactive UI elements
  String? _cookingRequest;
  bool _isBillExpanded = false;
  bool _isProcessing = false;
  // Values are the API's own payment method strings, so they can be sent as-is.
  // This used to be 'cod', which the backend never accepted -- the enum is
  // razorpay | razorpay_qr | card | wallet | cash -- so the COD button always failed.
  String _selectedPaymentMethod = 'razorpay'; // 'razorpay' | 'cash' | 'wallet'

  /// The delivery address is global to Azanto, not local to this screen: an
  /// address picked (or defaulted) while shopping groceries is the one food
  /// checkout starts from, and vice versa.
  /// The address the cart will actually use (what the radio shows as picked).
  String? get _selectedAddressId => _resolveSelectedAddress()?.id;

  void _selectAddress(String? addressId) =>
      ref.read(selectedAddressIdProvider.notifier).select(addressId ?? '');

  /// Orders go to a saved address: the unsaved "Current location" (id '')
  /// only scopes browsing, so the cart asks the user to pick or add one.
  AddressModel? _resolveSelectedAddress() {
    final a = ref.read(globalSelectedAddressProvider);
    return (a == null || a.id.isEmpty) ? null : a;
  }

  String get _customerName =>
      ref.read(authViewModelProvider).value?.displayName ?? 'Customer';

  Future<String> _restaurantNameForCart(List<CartItemModel> items) async {
    if (items.isEmpty) return '';
    final id = items.first.food.restaurantId;
    final restaurant = await ref.read(restaurantByIdProvider(id).future);
    return restaurant?.name ?? '';
  }


  Future<void> _proceedToPayment() async {
    // Guard set immediately (before any await) so a fast double-tap can't
    // launch a second overlapping submission while the first is still
    // resolving address/pricing — that race left a stale `context` behind
    // for the error SnackBar and crashed with "deactivated widget's ancestor".
    if (_isProcessing) return;
    Haptics.light();
    setState(() => _isProcessing = true);
    try {
      final isLoggedIn = ref.read(authViewModelProvider).value != null;
      if (!isLoggedIn) {
        context.push(
          '${RouteNames.login}?from=${Uri.encodeComponent(RouteNames.cart)}',
        );
        return;
      }

      var address = _resolveSelectedAddress();
      if (address == null) {
        // Empty could mean "genuinely no saved address" or "the last load
        // attempt failed" (e.g. a timeout) — retry once so a transient
        // failure doesn't get mistaken for having no address at all.
        final addressNotifier = ref.read(addressViewModelProvider.notifier);
        if (addressNotifier.error != null) {
          await addressNotifier.load();
          address = _resolveSelectedAddress();
        }
      }
      if (address == null) {
        final addressNotifier = ref.read(addressViewModelProvider.notifier);
        final loadFailed = addressNotifier.error != null;
        final hasSavedAddress = ref.read(addressViewModelProvider).isNotEmpty;
        if (!mounted) return;
        AppSnackbar.error(
          context,
          loadFailed
              ? 'Could not load your saved address. Check your connection and try again.'
              : hasSavedAddress
                  ? 'Please select a delivery address to proceed.'
                  : 'Add a delivery address to place your order.',
        );
        // With nothing saved, the picker would just be an empty list.
        if (!loadFailed && !hasSavedAddress) {
          unawaited(_openAddAddressScreen());
        } else {
          _showAddressSelectionBottomSheet(context);
        }
        return;
      }

      var checkoutState = ref.read(checkoutViewModelProvider);
      if (checkoutState.addressId != address.id) {
        await ref
            .read(checkoutViewModelProvider.notifier)
            .setAddress(address.id);
        checkoutState = ref.read(checkoutViewModelProvider);
      }

      if (checkoutState.pricing == null || checkoutState.isCalculating) {
        await ref.read(checkoutViewModelProvider.notifier).recalculate();
        checkoutState = ref.read(checkoutViewModelProvider);
      }

      final pricing = checkoutState.pricing;
      if (pricing == null) {
        if (!mounted) return;
        AppSnackbar.error(
          context,
          checkoutState.error ?? 'Could not calculate bill. Please try again.',
        );
        return;
      }

      if (checkoutState.needsPriceConfirmation) {
        await ref.read(checkoutViewModelProvider.notifier).acceptPriceChanges();
      }

      // Azanto Wallet balance validation
      if (_selectedPaymentMethod == 'wallet') {
        final walletState = ref.read(walletViewModelProvider);
        final walletBalance = walletState.wallet.balance;
        final totalToPay = pricing.total;
        if (walletBalance < totalToPay) {
          if (!mounted) return;
          AppSnackbar.warning(
            context,
            'Insufficient wallet balance (₹${walletBalance.toStringAsFixed(2)}). Need ₹${totalToPay.toStringAsFixed(2)}.',
            action: SnackBarAction(
              label: 'Add Money',
              textColor: Colors.white,
              onPressed: () {
                context.push(RouteNames.wallet);
              },
            ),
          );
          return;
        }
      }

      final cartItems = ref.read(cartViewModelProvider).items;
      if (cartItems.isEmpty) return;

      final result = await ref
          .read(checkoutViewModelProvider.notifier)
          .payAndPlaceOrder(
            address: address.toOrderPayload(customerName: _customerName),
            restaurantName: await _restaurantNameForCart(cartItems),
            paymentMethod: _selectedPaymentMethod,
          );

      if (!mounted) return;

      if (result.isPlaced) {
        Haptics.success();
        final orderId = result.orderId;
        if (orderId != null && orderId.isNotEmpty) {
          context.go('/orders/success/$orderId');
        } else {
          context.push(RouteNames.orders);
        }
        return;
      }

      AppSnackbar.error(context, result.message);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }



  void _showCookingRequestDialog(BuildContext context) {
    final textController = TextEditingController(text: _cookingRequest ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Cooking requests',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? Colors.white
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: textController,
                  maxLines: 3,
                  autofocus: true,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. Make it less spicy, no onions...',
                    hintStyle: TextStyle(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark
                            ? AppColors.borderDark
                            : AppColors.borderLight,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _cookingRequest = textController.text.trim().isEmpty
                            ? null
                            : textController.text.trim();
                      });
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Save Request',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartViewModelProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final secondaryColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    if (cartState.items.isEmpty) {
      return const EmptyCartView();
    }

    // Group cart items by restaurant
    final groupOrder = <String>[];
    final groups = <String, List<CartItemModel>>{};
    for (final item in cartState.items) {
      final rid = item.food.restaurantId;
      groups
          .putIfAbsent(rid, () {
            groupOrder.add(rid);
            return [];
          })
          .add(item);
    }

    final cartRestaurant = groupOrder.isNotEmpty
        ? ref.watch(restaurantByIdProvider(groupOrder.first)).asData?.value
        : null;

    // Fees and the payable total come from POST /food/orders/calculate.
    final checkoutState = ref.watch(checkoutViewModelProvider);
    final pricing = checkoutState.pricing;
    final totalDeliveryFee = pricing?.deliveryFee ?? 0.0;
    final platformFee = pricing?.platformFee ?? 0.0;
    final itemTotal = pricing?.subtotal ?? cartState.subtotal;
    final savings = pricing?.discount ?? cartState.totalSavings;
    final toPay = pricing?.total ?? cartState.subtotal;
    final packingCharges = pricing?.packagingFee ?? 0.0;

    // Driven from here rather than the bar itself: the bar is below the fold
    // in a lazily-built list, so on open it does not exist yet to notice
    // anything. Idempotent — it celebrates once per unlock, not per build.
    final freeDeliveryThreshold =
        ref.watch(foodFreeDeliveryThresholdProvider).value ?? 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      celebrateFreeDeliveryUnlock(
        context,
        scope: 'food',
        unlocked: itemTotal >= freeDeliveryThreshold,
        threshold: freeDeliveryThreshold,
        sectionKey: _freeDeliveryKey,
      );
    });

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1B1B1B) : AppColors.primary,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top Header Bar with Watermark
            _buildHeader(context, cartRestaurant, isDark),

            // The restaurant's live offer, on the cart it applies to.
            //
            // Same server-built summary the card and detail screens show, read
            // from the restaurant the cart already resolved — so it cannot
            // disagree with what the customer saw on the way in, and it
            // vanishes when the restaurant withdraws the offer.
            if (cartRestaurant != null && cartRestaurant.offerBadges.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: AutoScrollingOffers(
                  offers: cartRestaurant.offerBadges,
                  height: 20,
                  itemBuilder: (context, offer) => Row(
                    children: [
                      Icon(
                        Icons.local_offer_rounded,
                        size: 15,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          offer,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Main Content Area with Curved Top
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.backgroundDark
                      : const Color(0xFFF4F5F7),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                    // Deep enough to build the free-delivery section on open.
                    // A lazy list leaves it unbuilt below the fold, and an
                    // unbuilt bar cannot scroll itself into view to celebrate.
                    cacheExtent: 2000,
                    children: [
                      // Card 1: Cart Items & Action Chips
                      _buildCartItemsCard(
                        cartState,
                        textColor,
                        secondaryColor,
                        isDark,
                      ),

                      const SizedBox(height: 12),

                      // Recommendation Section: Complete your meal with
                      CartRecommendationsSection(
                        restaurantId: groupOrder.isNotEmpty
                            ? groupOrder.first
                            : '1',
                        targetCartKey: _cartItemsCardKey,
                      ),

                      const SizedBox(height: 12),

                      // Free-delivery progress, below the recommendations as in
                      // the reference. Threshold from the admin panel, spend
                      // from the live cart, so it moves on every quantity
                      // change without this screen computing anything.
                      Consumer(
                        builder: (context, ref, _) {
                          // Prompting to spend more for free delivery reads as
                          // broken when it's already free via the new-customer
                          // welcome offer, so this hides in that case.
                          if (pricing?.isNewCustomerFreeDelivery ?? false) {
                            return const SizedBox.shrink();
                          }
                          final threshold = ref
                                  .watch(foodFreeDeliveryThresholdProvider)
                                  .value ??
                              0;
                          return FreeDeliveryProgress(
                            key: _freeDeliveryKey,
                            spent: itemTotal,
                            threshold: threshold,
                            formatAmount: (a) => '₹${a.toStringAsFixed(0)}',
                          );
                        },
                      ),

                      const SizedBox(height: 12),

                      // Card 3: Payment Offers & More Card
                      _buildPaymentOffersCard(
                        pricing,
                        checkoutState.couponCode,
                        textColor,
                        secondaryColor,
                        isDark,
                      ),

                      const SizedBox(height: 12),

                      // Card 3b: Tip your delivery partner
                      TipYourDriverCard(
                        selected: checkoutState.deliveryTip,
                        presets:
                            ref.watch(foodTipPresetsProvider).value ??
                                kDefaultTipPresets,
                        onSelect: (amount) => unawaited(
                          ref
                              .read(checkoutViewModelProvider.notifier)
                              .setDeliveryTip(amount),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Card 4: To Pay / Bill Details Card
                      _buildBillDetailsCard(
                        itemTotal,
                        totalDeliveryFee,
                        platformFee,
                        packingCharges,
                        savings,
                        pricing?.hasCouponApplied ?? false,
                        toPay,
                        textColor,
                        secondaryColor,
                        isDark,
                        pricing,
                        checkoutState,
                        freeDeliveryThreshold,
                      ),

                      const SizedBox(height: 12),

                      // Card 5: Delivery Address Selection Card
                      _buildDeliveryAddressCard(
                        textColor,
                        secondaryColor,
                        isDark,
                      ),

                      const SizedBox(height: 16),

                      // Cancellation Policy Section
                      _buildCancellationPolicy(secondaryColor),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      // bottomNavigationBar, not bottomSheet: the body is laid out above it,
      // so the last section (cancellation policy) can never slide under it.
      bottomNavigationBar: _buildBottomDeliveryFooter(
        context,
        toPay,
        isDark,
        textColor,
      ),
    );
  }

  /// Header with Back Button and the restaurant every cart line belongs to.
  Widget _buildHeader(
    BuildContext context,
    RestaurantModel? restaurant,
    bool isDark,
  ) {
    final restaurantName = restaurant?.name ?? '';

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 12, 16),
      color: isDark ? const Color(0xFF1B1B1B) : AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Back arrow
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                onPressed: () {
                  Haptics.light();
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(RouteNames.home);
                  }
                },
              ),
            ],
          ),

          // Row 2: Optional restaurant logo + restaurant name
          if (restaurantName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 52),
              child: Row(
                children: [
                  if (restaurant?.imageUrl.isNotEmpty == true) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SmartImage(
                        url: restaurant!.imageUrl,
                        category: ImageCategory.restaurant,
                        width: 28,
                        height: 28,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      restaurantName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Card 1: Items list with Veg indicator, image, stepper, price, delete, and Action Chips
  Widget _buildCartItemsCard(
    CartState cartState,
    Color textColor,
    Color secondaryColor,
    bool isDark,
  ) {
    return Container(
      key: _cartItemsCardKey,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
              ],
        border: Border.all(
          color: isDark ? AppColors.borderDark : const Color(0xFFF3F4F6),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Items List
          for (int i = 0; i < cartState.items.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Divider(
                  height: 24,
                  thickness: 1,
                  color: isDark
                      ? AppColors.borderDark
                      : const Color(0xFFF0F2F5),
                ),
              ),
            _buildCartItemRow(
              cartState.items[i],
              textColor,
              secondaryColor,
              isDark,
            ),
          ],

          const SizedBox(height: 20),

          // Action Chips Row (Add Items, Cooking requests, Cutlery)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Add Items Chip
                _buildActionChip(
                  icon: Icons.add_rounded,
                  label: 'Add Items',
                  isDark: isDark,
                  onTap: () {
                    Haptics.light();
                    if (cartState.items.isNotEmpty) {
                      final restaurantId =
                          cartState.items.first.food.restaurantId;
                      if (restaurantId.isNotEmpty) {
                        context.push(
                          '${RouteNames.restaurantDetail}/$restaurantId',
                        );
                        return;
                      }
                    }
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go(RouteNames.home);
                    }
                  },
                ),
                const SizedBox(width: 10),

                // Cooking Requests Chip
                _buildActionChip(
                  icon: Icons.edit_note_rounded,
                  label: _cookingRequest == null
                      ? 'Cooking requests'
                      : 'Request: $_cookingRequest',
                  isDark: isDark,
                  isSelected: _cookingRequest != null,
                  onTap: () {
                    Haptics.light();
                    _showCookingRequestDialog(context);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItemRow(
    CartItemModel item,
    Color textColor,
    Color secondaryColor,
    bool isDark,
  ) {
    final food = item.food;
    final stepperBg = isDark
        ? const Color(0xFF2A2A2A)
        : AppColors.primaryTint;
    final stepperBorder = isDark
        ? const Color(0xFF3D3D3D)
        : AppColors.primary.withValues(alpha: 0.3);
    final stepperTextColor = isDark ? Colors.white : AppColors.primary;

    // Resolve selected add-on details (name & individual price)
    List<FoodAddon> resolvedAddons = item.selectedAddonDetails;
    if (resolvedAddons.isEmpty && item.selectedAddons.isNotEmpty) {
      final catalogAddons =
          ref.watch(restaurantAddonsProvider(food.restaurantId)).value ??
              const <FoodAddon>[];
      resolvedAddons = item.selectedAddons.map((idOrName) {
        final match = catalogAddons
            .where((a) => a.id == idOrName || a.name == idOrName)
            .firstOrNull;
        if (match != null) return match;
        return FoodAddon(
          id: idOrName,
          name: idOrName,
          price: item.selectedAddons.length == 1 ? item.selectedAddonsPrice : 0.0,
        );
      }).toList();
    }

    final hasVariant =
        item.selectedVariant != null && item.selectedVariant!.isNotEmpty;
    final hasAddons = resolvedAddons.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Product image + Item Name (Tap opens FoodDetailSheet)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Haptics.light();
                FoodDetailSheet.show(context, food, existingCartItem: item);
              },
              child: Row(
                crossAxisAlignment: (hasVariant || hasAddons)
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? AppColors.borderDark : const Color(0xFFE5E7EB),
                        width: 1,
                      ),
                      boxShadow: isDark
                          ? []
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: food.imageUrl.isNotEmpty
                            ? SmartImage(
                                url: food.imageUrl,
                                category: ImageCategory.food,
                                fit: BoxFit.cover,
                                width: 48,
                                height: 48,
                              )
                            : Container(
                                color: isDark
                                    ? AppColors.darkContainer
                                    : AppColors.lightContainer,
                                child: Icon(
                                  Icons.fastfood_rounded,
                                  size: 22,
                                  color: secondaryColor.withValues(alpha: 0.5),
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          food.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                            letterSpacing: -0.2,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (hasVariant) ...[
                          const SizedBox(height: 3),
                          Text(
                            'Variant: ${item.selectedVariant}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: secondaryColor,
                            ),
                          ),
                        ],
                        if (hasAddons) ...[
                          const SizedBox(height: 3),
                          Text(
                            'Add-ons:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: secondaryColor,
                            ),
                          ),
                          for (final addon in resolvedAddons)
                            Padding(
                              padding: const EdgeInsets.only(top: 1.5),
                              child: Text(
                                '• ${addon.name} (+₹${addon.price % 1 == 0 ? addon.price.toStringAsFixed(0) : addon.price.toStringAsFixed(2)})',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: secondaryColor.withValues(alpha: 0.85),
                                  height: 1.2,
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Orange stepper pill
          Container(
            height: 36,
            decoration: BoxDecoration(
              color: stepperBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: stepperBorder, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(18),
                  ),
                  onTap: () {
                    Haptics.light();
                    ref
                        .read(cartViewModelProvider.notifier)
                        .updateQuantity(item.id, item.quantity - 1);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    child: Text(
                      '−',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: stepperTextColor,
                      ),
                    ),
                  ),
                ),
                Container(
                  constraints: const BoxConstraints(minWidth: 24),
                  alignment: Alignment.center,
                  child: Text(
                    '${item.quantity}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: stepperTextColor,
                    ),
                  ),
                ),
                InkWell(
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(18),
                  ),
                  onTap: () {
                    Haptics.light();
                    ref
                        .read(cartViewModelProvider.notifier)
                        .updateQuantity(item.id, item.quantity + 1);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    child: Text(
                      '+',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: stepperTextColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Item total price
          Text(
            '₹${item.totalPrice.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required bool isDark,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    final chipBg = isSelected
        ? (isDark
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.primaryTint)
        : (isDark ? const Color(0xFF222222) : Colors.white);
    final chipBorder = isSelected
        ? AppColors.primary.withValues(alpha: 0.6)
        : (isDark ? const Color(0xFF333333) : const Color(0xFFE5E7EB));
    final chipIconColor = isSelected
        ? AppColors.primary
        : (isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280));
    final chipLabelColor = isSelected
        ? (isDark ? AppColors.primary : AppColors.primaryDeep)
        : (isDark ? Colors.white : const Color(0xFF374151));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: chipBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: chipBorder, width: 1.2),
          boxShadow: isSelected || isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: chipIconColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: chipLabelColor,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }



  /// Card 3: Payment Offers & More Card
  Widget _buildPaymentOffersCard(
    OrderPricing? pricing,
    String? couponCode,
    Color textColor,
    Color secondaryColor,
    bool isDark,
  ) {
    final applied = pricing?.hasCouponApplied ?? false;
    final label = applied
        ? '$couponCode applied · You saved ₹${pricing!.discount.toStringAsFixed(0)}'
        : 'Payment offers & more';

    return InkWell(
      onTap: () async {
        Haptics.light();
        final win = await CouponSheet.show(context);
        if (win == null || !mounted) return;
        await showCouponCelebration(
          context,
          code: win.code,
          savings: win.savings,
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          children: [
            // Tag Icon in rounded square
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF00875A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.local_offer_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),

            // Text Label
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: applied ? const Color(0xFF00875A) : textColor,
                ),
              ),
            ),

            // Chevron Right Icon
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? AppColors.textSecondaryDark : Colors.black87,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  /// Card 4: To Pay / Bill Details Accordion Card
  /// "GST (5%)" when the server sent the rate, plain "GST" when it did not —
  /// never a guessed percentage.
  static String _gstLabel(String name, double rate, {double defaultRate = 5.0}) {
    final effectiveRate = rate > 0 ? rate : defaultRate;
    final shown = effectiveRate == effectiveRate.roundToDouble()
        ? effectiveRate.toStringAsFixed(0)
        : effectiveRate.toStringAsFixed(1);
    return '$name ($shown%)';
  }

  Widget _buildBillDetailsCard(
    double itemTotal,
    double deliveryFee,
    double platformFee,
    double packingCharges,
    double savings,
    bool couponApplied,
    double toPay,
    Color textColor,
    Color secondaryColor,
    bool isDark,
    OrderPricing? pricing,
    CheckoutState checkoutState,
    double freeDeliveryThreshold,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
              ],
        border: Border.all(
          color: isDark ? AppColors.borderDark : const Color(0xFFF3F4F6),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Accordion Header
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Haptics.light();
              setState(() => _isBillExpanded = !_isBillExpanded);
            },
            child: Row(
              children: [
                // Receipt icon in a premium rounded square
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF2A2A2A)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? AppColors.borderDark
                          : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.receipt_long_rounded,
                    color: isDark ? Colors.white : const Color(0xFF334155),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),

                // Title & To Pay amount
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bill Details',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: secondaryColor,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'To Pay  ₹${toPay.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                            ),
                          ),
                          // Recalculating after a tip/coupon/address change hits
                          // the server again, and until that reply lands, every
                          // figure below falls back to null-safe defaults —
                          // delivery fee reads as "—", tax rows disappear, the
                          // total quietly reverts to the raw subtotal. Silently
                          // rendering that fallback looked like a broken bill
                          // instead of one still loading, which is what this is
                          // actually saying.
                          if (checkoutState.isCalculating) ...[
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (checkoutState.error != null &&
                          !checkoutState.isCalculating) ...[
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () => ref
                              .read(checkoutViewModelProvider.notifier)
                              .recalculate(),
                          // The server's own reason -- "Mozza Italia is closed
                          // right now. It opens at 1:00 PM." -- instead of a
                          // generic line that read as a wrong bill.
                          child: Text(
                            '${checkoutState.error} Tap to retry.',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Incl. taxes badge + chevron
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Incl. taxes',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF059669),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Icon(
                      _isBillExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : const Color(0xFF94A3B8),
                      size: 24,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Expanded Bill Details Breakdown
          if (_isBillExpanded) ...[
            const SizedBox(height: 20),
            Divider(
              height: 1,
              thickness: 1,
              color: isDark ? AppColors.borderDark : const Color(0xFFF1F5F9),
            ),
            const SizedBox(height: 16),

            _buildBillRow(
              'Item Total',
              '₹${itemTotal.toStringAsFixed(0)}',
              secondaryColor,
              textColor,
            ),
            const SizedBox(height: 12),

            _buildBillRow(
              'Delivery Fee',
              pricing == null
                  ? '—'
                  : deliveryFee == 0
                      ? 'FREE'
                      : '₹${deliveryFee.toStringAsFixed(0)}',
              secondaryColor,
              pricing != null && deliveryFee == 0 ? const Color(0xFF059669) : textColor,
            ),
            if (deliveryFee == 0 && pricing != null)
              _deliveryFeeReasonLine(pricing, freeDeliveryThreshold, secondaryColor)
            else if (pricing?.deliveryFeeBreakdown != null)
              _deliveryFeeBreakdownLine(pricing!.deliveryFeeBreakdown!, secondaryColor),
            const SizedBox(height: 12),

            _buildBillRow(
              'Platform Fee',
              '₹${platformFee.toStringAsFixed(0)}',
              secondaryColor,
              textColor,
              originalAmount: null,
            ),

            if (packingCharges > 0) ...[
              const SizedBox(height: 12),
              _buildBillRow(
                'Packing Charges',
                '₹${packingCharges.toStringAsFixed(0)}',
                secondaryColor,
                textColor,
              ),
            ],

            // Two rows rather than one merged "Taxes": the item GST and the
            // delivery-fee GST are charged at different rates, so a single
            // figure cannot be labelled with the rate behind it.
            if ((pricing?.tax ?? 0) > 0) ...[
              const SizedBox(height: 12),
              _buildBillRow(
                _gstLabel('Item GST', pricing?.gstRate ?? 5.0, defaultRate: 5.0),
                '₹${pricing!.tax.toStringAsFixed(2)}',
                secondaryColor,
                textColor,
              ),
            ],

            if ((pricing?.deliveryFeeGst ?? 0) > 0) ...[
              const SizedBox(height: 12),
              _buildBillRow(
                // Deliberately not "Delivery Fee GST" — that starts with the
                // same two words as the "Delivery Fee" row right above it,
                // which read as the fee being listed twice. No percentage in
                // the label itself; the rate is still real and admin-set
                // (deliveryFeeGstRate), it's just not spelled out here.
                'GST fees',
                '₹${pricing!.deliveryFeeGst.toStringAsFixed(2)}',
                secondaryColor,
                textColor,
              ),
            ],

            if ((pricing?.deliveryTip ?? 0) > 0) ...[
              const SizedBox(height: 12),
              _buildBillRow(
                'Delivery Partner Tip',
                '₹${pricing!.deliveryTip.toStringAsFixed(0)}',
                secondaryColor,
                textColor,
              ),
            ],

            if (savings > 0) ...[
              const SizedBox(height: 12),
              _buildBillRow(
                couponApplied ? 'Coupon Discount' : 'Discount',
                '−₹${savings.toStringAsFixed(0)}',
                const Color(0xFF059669),
                const Color(0xFF059669),
              ),
            ],

            const SizedBox(height: 16),
            Divider(
              height: 1,
              thickness: 1,
              color: isDark ? AppColors.borderDark : const Color(0xFFF1F5F9),
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Grand Total',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                Text(
                  '₹${toPay.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBillRow(
    String label,
    String value,
    Color labelColor,
    Color valueColor, {
    String? originalAmount,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: labelColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        Row(
          children: [
            if (originalAmount != null) ...[
              Text(
                originalAmount,
                style: TextStyle(
                  fontSize: 12,
                  color: labelColor.withValues(alpha: 0.6),
                  decoration: TextDecoration.lineThrough,
                  decorationColor: labelColor.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              value,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Explains a free delivery fee: the new-customer welcome offer, or the
  /// spend threshold — whichever the server/local state says applies.
  Widget _deliveryFeeReasonLine(
    OrderPricing pricing,
    double freeDeliveryThreshold,
    Color secondaryColor,
  ) {
    String? text;
    if (pricing.isNewCustomerFreeDelivery) {
      final maxOrders = (pricing.newCustomerFreeDelivery?['maxOrders'] as num?)?.toInt();
      final left = pricing.freeDeliveriesLeft;
      text = maxOrders != null && left != null
          ? 'Free delivery on your first $maxOrders orders · $left left'
          : 'Free delivery on your first orders';
    } else if (freeDeliveryThreshold > 0) {
      text = 'Free delivery on orders over ₹${freeDeliveryThreshold.toStringAsFixed(0)}';
    }
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        style: TextStyle(fontSize: 11.5, color: secondaryColor.withValues(alpha: 0.8)),
      ),
    );
  }

  /// Small grey line spelling out the distance-based delivery fee math.
  Widget _deliveryFeeBreakdownLine(Map<String, dynamic> breakdown, Color secondaryColor) {
    final baseKm = (breakdown['baseDeliveryKm'] as num?)?.toDouble();
    final extraKm = (breakdown['extraKm'] as num?)?.toDouble();
    final perKmFee = (breakdown['perKmFee'] as num?)?.toDouble();
    if (baseKm == null || extraKm == null || perKmFee == null || extraKm <= 0) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        '${baseKm.toStringAsFixed(0)} km included, ${extraKm.toStringAsFixed(0)} km extra × ₹${perKmFee.toStringAsFixed(0)}',
        style: TextStyle(fontSize: 11.5, color: secondaryColor.withValues(alpha: 0.7)),
      ),
    );
  }

  /// Cancellation Policy Text Section
  Widget _buildCancellationPolicy(Color secondaryColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cancellation policy:',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: secondaryColor.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Please double-check your order and address details. Orders are non-refundable once placed.',
            style: TextStyle(
              fontSize: 12,
              color: secondaryColor.withValues(alpha: 0.8),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  /// Opens the add-address screen and selects whatever it saved.
  ///
  /// AddAddressScreen already persists through addressViewModelProvider before
  /// popping, so the newly appended entry is the one to select.
  Future<void> _openAddAddressScreen() async {
    final result = await context.push<dynamic>(RouteNames.addAddress);
    if (result == null || !mounted) return;

    final saved = ref.read(addressViewModelProvider);
    if (saved.isEmpty) return;
    _selectAddress(saved.last.id);
    Haptics.medium();
    // The bill is priced against the chosen address, so it is now stale.
    unawaited(ref.read(checkoutViewModelProvider.notifier).setAddress(saved.last.id));
  }

  void _showAddressSelectionBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
        final secondaryColor = isDark
            ? AppColors.textSecondaryDark
            : AppColors.textSecondaryLight;

        // Consumer so the list rebuilds itself once addAddress/deleteAddress
        // updates the real backend-driven addressViewModelProvider state.
        return Consumer(
          builder: (context, ref, _) {
            final addresses = ref.watch(addressViewModelProvider);
            return Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row: Choose a delivery address + Close Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Choose a delivery address',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      InkWell(
                        onTap: () => Navigator.pop(sheetContext),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF2E2E2E)
                                : const Color(0xFFF2F4F7),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close,
                            size: 18,
                            color: isDark ? Colors.white : Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),
                  Divider(
                    height: 1,
                    color: isDark
                        ? AppColors.borderDark
                        : AppColors.dividerLight,
                  ),
                  const SizedBox(height: 12),

                  // Item 1: Add new Address
                  InkWell(
                    onTap: () {
                      Haptics.light();
                      Navigator.pop(sheetContext);
                      unawaited(_openAddAddressScreen());
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 4,
                      ),
                      child: Row(
                        children: [
                          // Square Primary Theme Box with + Icon
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark
                                    ? AppColors.primary
                                    : const Color(0xFFD0D5DD),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              Icons.add,
                              color: AppColors.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            'Add new Address',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),
                  Divider(
                    height: 1,
                    color: isDark
                        ? AppColors.borderDark
                        : AppColors.dividerLight,
                  ),
                  const SizedBox(height: 8),

                  // Dynamic Saved Addresses List — sourced from the real,
                  // backend-driven addressViewModelProvider.
                  if (addresses.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'No saved addresses yet. Add one to continue.',
                        style: TextStyle(fontSize: 13.5, color: secondaryColor),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: addresses.length,
                        separatorBuilder: (context, index) => Column(
                          children: [
                            const SizedBox(height: 8),
                            Divider(
                              height: 1,
                              color: isDark
                                  ? AppColors.borderDark
                                  : AppColors.dividerLight,
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                        itemBuilder: (context, index) {
                          final addr = addresses[index];
                          final resolvedId =
                              _selectedAddressId ??
                              (addresses.firstWhere(
                                (a) => a.isDefault,
                                orElse: () => addresses.first,
                              )).id;
                          final isSelected = addr.id == resolvedId;

                          IconData icon = Icons.navigation_outlined;
                          if (addr.type == 'Home' ||
                              addr.title.toLowerCase().contains('home')) {
                            icon = Icons.home_outlined;
                          } else if (addr.type == 'Office' ||
                              addr.title.toLowerCase().contains('office')) {
                            icon = Icons.work_outline;
                          }

                          return _buildSavedAddressTile(
                            sheetContext: sheetContext,
                            addressId: addr.id,
                            title: addr.title,
                            address: addr.fullAddress,
                            icon: icon,
                            isSelected: isSelected,
                            isDark: isDark,
                            textColor: textColor,
                            secondaryColor: secondaryColor,
                            onDelete: () {
                              _showDeleteConfirmationDialog(
                                context: sheetContext,
                                title: addr.title,
                                onConfirm: () async {
                                  Haptics.medium();
                                  final deleted = await ref
                                      .read(addressViewModelProvider.notifier)
                                      .deleteAddress(addr.id);
                                  if (!deleted) return;
                                  if (_selectedAddressId == addr.id) {
                                    _selectAddress(null);
                                  }
                                  if (!context.mounted) return;
                                  AppSnackbar.success(
                                    context,
                                    '"${addr.title}" deleted',
                                    duration: const Duration(seconds: 2),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmationDialog({
    required BuildContext context,
    required String title,
    required VoidCallback onConfirm,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Delete Address',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: Text(
            'Are you sure you want to delete "$title"?',
            style: TextStyle(
              fontSize: 14,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.pop(dialogContext);
                onConfirm();
              },
              child: const Text(
                'Delete',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSavedAddressTile({
    required BuildContext sheetContext,
    required String addressId,
    required String title,
    required String address,
    required IconData icon,
    required bool isSelected,
    required bool isDark,
    required Color textColor,
    required Color secondaryColor,
    required VoidCallback onDelete,
  }) {
    return InkWell(
      onTap: () {
        Haptics.light();
        _selectAddress(addressId);
        Navigator.pop(sheetContext);
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon Container
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1)
                    : (isDark
                          ? const Color(0xFF2A2A2A)
                          : const Color(0xFFF2F4F7)),
                borderRadius: BorderRadius.circular(10),
                border: isSelected
                    ? Border.all(color: AppColors.primary, width: 1.2)
                    : null,
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? Colors.white : Colors.black87),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? AppColors.primary : textColor,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Selected',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    address,
                    style: TextStyle(
                      fontSize: 12,
                      color: secondaryColor,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Delete Icon Button
            IconButton(
              onPressed: onDelete,
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.redAccent,
                size: 20,
              ),
              tooltip: 'Delete address',
            ),
          ],
        ),
      ),
    );
  }

  String _getPaymentButtonLabel(double toPay) {
    final amount = toPay.toStringAsFixed(0);
    switch (_selectedPaymentMethod) {
      case 'cash':
        return 'PLACE COD ORDER (₹$amount)';
      case 'wallet':
        return 'PAY WITH WALLET (₹$amount)';
      case 'razorpay':
      default:
        return 'PROCEED TO PAYMENT (₹$amount)';
    }
  }

  /// Card 5: Delivery Address Selection Card
  Widget _buildDeliveryAddressCard(
    Color textColor,
    Color secondaryColor,
    bool isDark,
  ) {
    final resolvedAddress = _resolveSelectedAddress();
    // Nothing saved yet: offering to "change" or "select" an address points at
    // an empty list. Send these customers straight to the add screen instead.
    final hasSavedAddress = ref.watch(addressViewModelProvider).isNotEmpty;
    final addressTitle = resolvedAddress?.title ??
        (hasSavedAddress ? 'Delivery Address' : 'No address added yet');
    final addressDisplay = resolvedAddress != null
        ? (resolvedAddress.city.isNotEmpty
            ? '${resolvedAddress.title} · ${resolvedAddress.city}, ${resolvedAddress.fullAddress}'
            : '${resolvedAddress.title} · ${resolvedAddress.fullAddress}')
        : (hasSavedAddress
            ? 'Select a delivery address'
            : 'Add a delivery address to see the delivery fee and place your order');

    void openAddressPicker() {
      Haptics.light();
      if (hasSavedAddress) {
        _showAddressSelectionBottomSheet(context);
      } else {
        unawaited(_openAddAddressScreen());
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? []
            : [
                const BoxShadow(
                  color: AppColors.shadow2,
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Delivery Address',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: openAddressPicker,
                child: Text(
                  hasSavedAddress ? 'CHANGE' : '+ ADD',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: openAddressPicker,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.surfaceDark
                    : AppColors.secondarySurfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.location_on_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          addressTitle,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          addressDisplay,
                          style: TextStyle(fontSize: 12, color: secondaryColor),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: secondaryColor,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }



  /// Payment Method Selection Bottom Sheet
  void _showPaymentMethodBottomSheet(
    BuildContext context,
    double toPay,
    double walletBalance,
    bool isDark,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final modalTextColor = isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight;
            final modalSecondaryColor = isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.borderDark
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Select Payment Method',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: modalTextColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total Payable Amount: ₹${toPay.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: modalSecondaryColor,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Option 1: Online Payment (Razorpay / UPI / Cards)
                    _paymentOptionTile(
                      ctx: modalCtx,
                      methodKey: 'razorpay',
                      icon: Icons.credit_card_rounded,
                      title: 'Online Payment (UPI, Cards, NetBanking)',
                      subtitle: 'Pay securely via Razorpay payment gateway',
                      isDark: isDark,
                      modalTextColor: modalTextColor,
                      modalSecondaryColor: modalSecondaryColor,
                    ),

                    const SizedBox(height: 10),

                    // Option 2: Cash on Delivery (COD)
                    _paymentOptionTile(
                      ctx: modalCtx,
                      methodKey: 'cash',
                      icon: Icons.payments_outlined,
                      title: 'Cash on Delivery (COD)',
                      subtitle: 'Pay in cash when your food is delivered',
                      isDark: isDark,
                      modalTextColor: modalTextColor,
                      modalSecondaryColor: modalSecondaryColor,
                    ),

                    const SizedBox(height: 10),

                    // Option 3: Azanto Wallet
                    _paymentOptionTile(
                      ctx: modalCtx,
                      methodKey: 'wallet',
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Go Azanto Wallet',
                      subtitle: walletBalance >= toPay
                          ? 'Available balance: ₹${walletBalance.toStringAsFixed(2)}'
                          : 'Balance: ₹${walletBalance.toStringAsFixed(2)} (Insufficient balance)',
                      badgeText: walletBalance < toPay
                          ? 'LOW BALANCE'
                          : 'INSTANT',
                      badgeColor: walletBalance < toPay
                          ? AppColors.error
                          : AppColors.success,
                      isDark: isDark,
                      modalTextColor: modalTextColor,
                      modalSecondaryColor: modalSecondaryColor,
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _paymentOptionTile({
    required BuildContext ctx,
    required String methodKey,
    required IconData icon,
    required String title,
    required String subtitle,
    String? badgeText,
    Color? badgeColor,
    required bool isDark,
    required Color modalTextColor,
    required Color modalSecondaryColor,
  }) {
    final isSelected = _selectedPaymentMethod == methodKey;

    return InkWell(
      onTap: () {
        Haptics.light();
        setState(() => _selectedPaymentMethod = methodKey);
        Navigator.pop(ctx);
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.08)
              : (isDark ? AppColors.cardDark : AppColors.secondarySurfaceLight),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: modalTextColor,
                          ),
                        ),
                      ),
                      if (badgeText != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: (badgeColor ?? AppColors.primary).withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: badgeColor ?? AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: modalSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? AppColors.primary : modalSecondaryColor,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  /// Bottom Delivery / Payment Sticky Bar Footer
  Widget _buildBottomDeliveryFooter(
    BuildContext context,
    double toPay,
    bool isDark,
    Color textColor,
  ) {
    final walletState = ref.watch(walletViewModelProvider);
    final walletBalance = walletState.wallet.balance;

    IconData paymentIcon;
    String paymentDisplay;

    switch (_selectedPaymentMethod) {
      case 'cash':
        paymentIcon = Icons.payments_outlined;
        paymentDisplay = 'Cash on Delivery (COD)';
        break;
      case 'wallet':
        paymentIcon = Icons.account_balance_wallet_outlined;
        paymentDisplay = 'Go Azanto Wallet (₹${walletBalance.toStringAsFixed(0)})';
        break;
      case 'razorpay':
      default:
        paymentIcon = Icons.credit_card_rounded;
        paymentDisplay = 'Online Payment (UPI/Cards)';
        break;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.borderDark : const Color(0xFFF3F4F6),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Payment Method row — tapping opens payment method bottom sheet
            InkWell(
              onTap: () {
                Haptics.light();
                _showPaymentMethodBottomSheet(
                  context,
                  toPay,
                  walletBalance,
                  isDark,
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF262626)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? AppColors.borderDark
                        : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        paymentIcon,
                        color: AppColors.primary,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        paymentDisplay,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                          letterSpacing: 0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Change',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Proceed to Payment Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shadowColor: AppColors.primary.withValues(alpha: 0.6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                onPressed: _isProcessing ? null : _proceedToPayment,
                child: _isProcessing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _getPaymentButtonLabel(toPay),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
