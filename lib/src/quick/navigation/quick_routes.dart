import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_durations.dart';
import '../core/theme/quick_theme_scope.dart';
import '../domain/model/address.dart';
import '../domain/model/category.dart';
import '../domain/model/order.dart';
import '../domain/model/product.dart';
import '../platform/location/location_service.dart';
import '../ui/screens/address/addresses_screen.dart';
import '../ui/screens/brand/brand_listing_screen.dart';
import '../ui/screens/cart/cart_screen.dart';
import '../ui/screens/chat/chat_screen.dart';
import '../ui/screens/category/categories/categories_screen.dart';
import '../ui/screens/category/sub_category/sub_category_screen.dart';
import '../ui/screens/checkout/checkout_screen.dart';
import '../ui/screens/coupons/coupons_screen.dart';
import '../ui/screens/home/home_screen.dart';
import '../ui/screens/location/address_selection/address_selection_screen.dart';
import '../ui/screens/location/location_permission/location_permission_screen.dart';
import '../ui/screens/notifications/notifications_screen.dart';
import '../ui/screens/order/order_details/order_details_screen.dart';
import '../ui/screens/order/order_success/order_success_screen.dart';
import '../ui/screens/order/order_tracking/order_tracking_screen.dart';
import '../ui/screens/order/orders_list/orders_screen.dart';
import '../ui/screens/payment/payment_screen.dart';
import '../ui/screens/product/product_details/product_details_screen.dart';
import '../ui/screens/product/product_listing/product_listing_args.dart';
import '../ui/screens/product/product_listing/product_listing_screen.dart';
import '../ui/screens/profile/settings/settings_screen.dart';
// Global Azanto screens — one implementation, shared by both verticals.
import '../../presentation/about/screens/about_screen.dart';
import '../../presentation/profile/profile_screen.dart';
import '../../presentation/profile/screens/edit_profile_screen.dart';
import '../../presentation/profile/screens/help_support_screen.dart';
import '../../presentation/profile/screens/privacy_policy_screen.dart';
import '../../presentation/profile/screens/terms_conditions_screen.dart';
import '../../presentation/wallet/screens/wallet_screen.dart';
import '../ui/screens/search/search_screen.dart';
import '../ui/screens/wishlist/wishlist_screen.dart';
import '../ui/shell/app_shell.dart';
import 'route_paths.dart';

final _quickShellKey = GlobalKey<NavigatorState>(debugLabel: 'quickShell');

/// The quick-commerce route table, registered inside the single Azanto router.
///
/// Top-level tabs live in a [StatefulShellRoute] so each keeps its own
/// navigation stack and scroll position; everything else is pushed on the root
/// navigator (passed in from the app router) so it covers the bottom bar.
/// Splash/login/OTP are shared Azanto routes and deliberately absent here.
///
/// Every screen is wrapped in [QuickThemeScope]: the app-level MaterialApp is
/// themed for the food vertical, and quick screens require this module's
/// ThemeData (component themes + the AppSemanticColors extension).
List<RouteBase> quickRoutes(GlobalKey<NavigatorState> rootKey) => [
      GoRoute(
        path: RoutePaths.locationPermission,
        name: RouteNames.locationPermission,
        parentNavigatorKey: rootKey,
        pageBuilder: (context, state) =>
            _fadeThrough(state, const LocationPermissionScreen()),
      ),
      GoRoute(
        path: RoutePaths.addressSelection,
        name: RouteNames.addressSelection,
        parentNavigatorKey: rootKey,
        pageBuilder: (context, state) {
          final extra = state.extra;
          return _slideUp(
            state,
            AddressSelectionScreen(
              existing: extra is Address ? extra : null,
              initialLocation: extra is DeviceLocation ? extra : null,
            ),
          );
        },
      ),

      // ── Tabs ──────────────────────────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            QuickThemeScope(child: AppShell(navigationShell: navigationShell)),
        branches: [
          StatefulShellBranch(
            navigatorKey: _quickShellKey,
            routes: [
              GoRoute(
                path: RoutePaths.home,
                name: RouteNames.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.categories,
                name: RouteNames.categories,
                builder: (context, state) =>
                    const CategoriesScreen(showAppBar: false),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.cart,
                name: RouteNames.cart,
                builder: (context, state) => const CartScreen(showAppBar: false),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.orders,
                name: RouteNames.orders,
                builder: (context, state) =>
                    const OrdersScreen(showAppBar: false),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.profile,
                name: RouteNames.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // ── Pushed over the shell ─────────────────────────────────────────────
      GoRoute(
        path: RoutePaths.search,
        name: RouteNames.search,
        parentNavigatorKey: rootKey,
        pageBuilder: (context, state) => _fadeThrough(
          state,
          SearchScreen(
            autoStartVoice: state.uri.queryParameters['voice'] == '1',
          ),
        ),
      ),
      GoRoute(
        path: RoutePaths.subCategory,
        name: RouteNames.subCategory,
        parentNavigatorKey: rootKey,
        builder: (context, state) => QuickThemeScope(
          child: SubCategoryScreen(
            categoryId: state.pathParameters['id']!,
            category: state.extra is Category ? state.extra as Category : null,
          ),
        ),
      ),
      GoRoute(
        path: RoutePaths.brands,
        name: RouteNames.brands,
        parentNavigatorKey: rootKey,
        builder: (context, state) =>
            const QuickThemeScope(child: BrandListingScreen()),
      ),
      GoRoute(
        path: RoutePaths.productListing,
        name: RouteNames.productListing,
        parentNavigatorKey: rootKey,
        builder: (context, state) => QuickThemeScope(
          child: ProductListingScreen(
            args: state.extra is ProductListingArgs
                ? state.extra as ProductListingArgs
                : const ProductListingArgs(title: 'All products'),
          ),
        ),
      ),
      GoRoute(
        path: RoutePaths.productDetails,
        name: RouteNames.productDetails,
        parentNavigatorKey: rootKey,
        builder: (context, state) => QuickThemeScope(
          child: ProductDetailsScreen(
            productId: state.pathParameters['id']!,
            product: state.extra is Product ? state.extra as Product : null,
          ),
        ),
      ),
      GoRoute(
        path: RoutePaths.wishlist,
        name: RouteNames.wishlist,
        parentNavigatorKey: rootKey,
        builder: (context, state) =>
            const QuickThemeScope(child: WishlistScreen()),
      ),
      GoRoute(
        path: RoutePaths.wallet,
        name: RouteNames.wallet,
        parentNavigatorKey: rootKey,
        builder: (context, state) => const WalletScreen(),
      ),
      GoRoute(
        path: RoutePaths.checkout,
        name: RouteNames.checkout,
        parentNavigatorKey: rootKey,
        pageBuilder: (context, state) => _slideUp(state, const CheckoutScreen()),
      ),
      GoRoute(
        path: RoutePaths.coupons,
        name: RouteNames.coupons,
        parentNavigatorKey: rootKey,
        pageBuilder: (context, state) => _slideUp(state, const CouponsScreen()),
      ),
      GoRoute(
        path: RoutePaths.payment,
        name: RouteNames.payment,
        parentNavigatorKey: rootKey,
        pageBuilder: (context, state) => _slideUp(
          state,
          PaymentScreen(placedOrder: state.extra! as PlacedOrder),
        ),
      ),
      GoRoute(
        path: RoutePaths.addresses,
        name: RouteNames.addresses,
        parentNavigatorKey: rootKey,
        builder: (context, state) => const AddressesScreen(),
      ),
      GoRoute(
        path: RoutePaths.notifications,
        name: RouteNames.notifications,
        parentNavigatorKey: rootKey,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: RoutePaths.orderSuccess,
        name: RouteNames.orderSuccess,
        parentNavigatorKey: rootKey,
        pageBuilder: (context, state) => _fadeThrough(
          state,
          OrderSuccessScreen(orderId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: RoutePaths.orderTracking,
        name: RouteNames.orderTracking,
        parentNavigatorKey: rootKey,
        builder: (context, state) => QuickThemeScope(
          child: OrderTrackingScreen(orderId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: RoutePaths.orderChat,
        name: RouteNames.orderChat,
        parentNavigatorKey: rootKey,
        builder: (context, state) {
          final extra = state.extra is ChatArgs ? state.extra as ChatArgs : null;
          return QuickThemeScope(
            child: ChatScreen(
              orderId: state.pathParameters['id']!,
              riderName: extra?.riderName ?? 'Delivery partner',
              riderId: extra?.riderId ?? '',
            ),
          );
        },
      ),
      GoRoute(
        path: RoutePaths.orderDetails,
        name: RouteNames.orderDetails,
        parentNavigatorKey: rootKey,
        builder: (context, state) => QuickThemeScope(
          child: OrderDetailsScreen(orderId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: RoutePaths.editProfile,
        name: RouteNames.editProfile,
        parentNavigatorKey: rootKey,
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: RoutePaths.help,
        name: RouteNames.help,
        parentNavigatorKey: rootKey,
        builder: (context, state) => const HelpSupportScreen(),
      ),
      GoRoute(
        path: RoutePaths.settings,
        name: RouteNames.settings,
        parentNavigatorKey: rootKey,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: RoutePaths.privacyPolicy,
        name: RouteNames.privacyPolicy,
        parentNavigatorKey: rootKey,
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),
      GoRoute(
        path: RoutePaths.terms,
        name: RouteNames.terms,
        parentNavigatorKey: rootKey,
        builder: (context, state) => const TermsConditionsScreen(),
      ),
      GoRoute(
        path: RoutePaths.about,
        name: RouteNames.about,
        parentNavigatorKey: rootKey,
        builder: (context, state) => const AboutScreen(),
      ),
    ];

/// Fade-through: used between top-level contexts that are not a stack push.
/// Wraps in [QuickThemeScope] so every page built through it is themed.
CustomTransitionPage<void> _fadeThrough(GoRouterState state, Widget child) =>
    CustomTransitionPage(
      key: state.pageKey,
      child: QuickThemeScope(child: child),
      transitionDuration: AppDurations.medium,
      transitionsBuilder: (context, animation, secondary, child) => FadeTransition(
        opacity: CurveTween(curve: Curves.easeOut).animate(animation),
        child: ScaleTransition(
          scale: Tween(begin: 0.98, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOut),
          ),
          child: child,
        ),
      ),
    );

/// Slide-up: modal-feeling routes such as checkout, coupons and payment.
/// Wraps in [QuickThemeScope] so every page built through it is themed.
CustomTransitionPage<void> _slideUp(GoRouterState state, Widget child) =>
    CustomTransitionPage(
      key: state.pageKey,
      child: QuickThemeScope(child: child),
      transitionDuration: AppDurations.medium,
      transitionsBuilder: (context, animation, secondary, child) => SlideTransition(
        position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: FadeTransition(opacity: animation, child: child),
      ),
    );
