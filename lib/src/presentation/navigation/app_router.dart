// App Router Configuration
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'route_names.dart';
import '../../../taxi/taxi_section.dart';
import '../../quick/navigation/quick_routes.dart';
import '../splash/splash_screen.dart';
import '../auth/screens/login_screen.dart';
import '../auth/screens/profile_setup_screen.dart';
import '../auth/viewmodels/auth_viewmodel.dart';
import '../address/screens/add_address_screen.dart';
import '../auth/screens/otp_screen.dart';
import '../main/main_app_shell.dart';
import '../home/home_screen.dart';
import '../cart/cart_screen.dart';
// Global screens whose single implementation lives in the quick module.
import '../../quick/domain/model/address.dart' as quick_address;
import '../../quick/ui/screens/address/addresses_screen.dart';
import '../../quick/ui/screens/location/address_selection/address_selection_screen.dart';
import '../../quick/ui/screens/notifications/notifications_screen.dart';
import '../../quick/ui/screens/profile/settings/settings_screen.dart';
import '../profile/profile_screen.dart';
import '../restaurant/screens/food_detail_loader_screen.dart';
import '../restaurant/screens/food_detail_screen.dart';
import '../restaurant/screens/restaurant_detail_loader_screen.dart';
import '../restaurant/screens/restaurant_screen.dart';
import '../restaurant/screens/store99_screen.dart';
import '../search/screens/search_screen.dart';
import '../offers/screens/all_offers_screen.dart';
import '../favorites/favorites_screen.dart';
import '../orders/screens/unified_orders_screen.dart';
import '../orders/screens/order_details_screen.dart';
import '../orders/screens/order_tracking_screen.dart';
import '../orders/screens/order_success_screen.dart';
import '../orders/screens/order_delivered_screen.dart';
import '../referral/screens/referral_screen.dart';
import '../referral/screens/referral_ticket_result_screen.dart';
import '../wallet/screens/wallet_screen.dart';
import '../chat/screens/chat_screen.dart';
import '../home/screens/home_filter_screen.dart';
import '../common/webview_screen.dart';
import '../about/screens/about_screen.dart';
import '../profile/screens/help_support_screen.dart';
import '../profile/screens/privacy_policy_screen.dart';
import '../profile/screens/terms_conditions_screen.dart';
import '../profile/screens/edit_profile_screen.dart';
import '../../data/models/restaurant_model.dart';
import '../../data/models/food_model.dart';
import '../../data/models/cart_item_model.dart';
import '../cart/viewmodels/cart_viewmodel.dart';
import '../checkout/viewmodels/checkout_viewmodel.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final shellNavigatorKeyHome = GlobalKey<NavigatorState>(
  debugLabel: 'shellHome',
);
final shellNavigatorKeyCart = GlobalKey<NavigatorState>(
  debugLabel: 'shellCart',
);
final shellNavigatorKeyStore99 = GlobalKey<NavigatorState>(
  debugLabel: 'shellStore99',
);
final shellNavigatorKeyProfile = GlobalKey<NavigatorState>(
  debugLabel: 'shellProfile',
);

/// Mart paths reachable from outside the module's own shell/nav (deep links,
/// push notifications, a stale bottom-sheet action) that must keep working
/// even while Mart is admin-disabled: an already-placed order's own pages,
/// and plain account screens that aren't "new Mart shopping".
///
/// Everything else under `/quick/` is shopping surface — home, categories,
/// product browsing, cart, checkout — and is what the toggle is actually for.
const _martDisabledExemptPrefixes = [
  '/quick/order/', // tracking, chat, success, details of an EXISTING order
  '/quick/notifications',
  '/quick/wallet',
  '/quick/addresses',
  '/quick/profile',
  '/quick/location',
  '/quick/address/select',
];

final routerProvider = Provider<GoRouter>((ref) {
  // Re-run the redirects the moment the session flips between signed-in and
  // guest (logout, expired/revoked token), so an authed screen sends the user
  // to login instead of failing every call with 401. Bumped after the frame:
  // Riverpod delivers this synchronously and re-entering the router mid-frame
  // tore the shell down while it was still building.
  var disposed = false;
  final authChanged = ValueNotifier<int>(0);
  ref.listen(authViewModelProvider, (previous, next) {
    if ((previous?.value != null) == (next.value != null)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!disposed) authChanged.value++;
    });
  });
  ref.onDispose(() {
    disposed = true;
    authChanged.dispose();
  });

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    refreshListenable: authChanged,
    initialLocation: RouteNames.splash,
    // Azanto has no Mart: the quick module only still serves the shared
    // account screens (addresses, notifications, settings). Any Mart shopping
    // path — a stale link or push — lands on Food home instead.
    redirect: (context, state) {
      final location = state.uri.path;
      if (!location.startsWith('/quick/')) return null;
      if (_martDisabledExemptPrefixes.any(location.startsWith)) return null;
      return RouteNames.home;
    },
    routes: [
      // Quick-commerce vertical — everything under /quick.
      ...quickRoutes(rootNavigatorKey),
      GoRoute(
        path: RouteNames.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RouteNames.login,
        builder: (context, state) {
          final fromPath =
              state.uri.queryParameters['from'] ??
              (state.extra is String ? state.extra as String : null);
          return LoginScreen(fromPath: fromPath);
        },
      ),
      GoRoute(
        path: RouteNames.otp,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final phone =
              extra?['phone']?.toString() ??
              state.uri.queryParameters['phone'] ??
              '';
          final fromPath =
              extra?['from']?.toString() ?? state.uri.queryParameters['from'];
          // Carried through so an invite link landing on /otp?ref=CODE still
          // credits the referrer.
          final ref =
              extra?['ref']?.toString() ?? state.uri.queryParameters['ref'];
          return OtpScreen(
            phoneNumber: phone,
            name: extra?['name']?.toString(),
            referralCode: ref,
            fromPath: fromPath,
          );
        },
      ),
      GoRoute(
        path: RouteNames.profileSetup,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return ProfileSetupScreen(
            redirectTo: extra?['from']?.toString() ??
                state.uri.queryParameters['from'] ??
                RouteNames.home,
          );
        },
      ),
      // Taxi section: the taxi module runs as its own nested app.
      GoRoute(
        path: RouteNames.taxi,
        builder: (context, state) => const TaxiSection(),
      ),
      GoRoute(
        path: RouteNames.restaurantDetail,
        builder: (context, state) {
          // `extra` is not guaranteed. A shared link carries only the id, and an
          // unconditional cast threw on arrival; the favourites screen also
          // already pushes '/restaurant-detail/<id>', which never matched this
          // route at all. Both now resolve through the loader.
          final restaurant =
              state.extra is RestaurantModel ? state.extra as RestaurantModel : null;
          if (restaurant != null) {
            return RestaurantScreen(restaurant: restaurant);
          }
          return RestaurantDetailLoaderScreen(
            restaurantId: state.uri.queryParameters['id'] ??
                state.uri.queryParameters['restaurantId'] ??
                '',
          );
        },
        routes: [
          GoRoute(
            path: ':id',
            builder: (context, state) {
              final restaurant = state.extra is RestaurantModel
                  ? state.extra as RestaurantModel
                  : null;
              if (restaurant != null) {
                return RestaurantScreen(restaurant: restaurant);
              }
              return RestaurantDetailLoaderScreen(
                restaurantId: state.pathParameters['id'] ?? '',
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: RouteNames.foodDetail,
        builder: (context, state) {
          final extraFood = state.extra is FoodModel ? state.extra as FoodModel : null;
          final foodId = state.uri.queryParameters['id'] ?? state.uri.queryParameters['productId'] ?? '';
          final restaurantId = state.uri.queryParameters['restaurantId'] ?? state.uri.queryParameters['rId'] ?? '';

          if (extraFood != null) {
            return FoodDetailScreen(food: extraFood);
          }
          return FoodDetailLoaderScreen(
            foodId: foodId,
            restaurantId: restaurantId,
          );
        },
      ),
      GoRoute(
        path: '/food',
        builder: (context, state) {
          final extraFood = state.extra is FoodModel ? state.extra as FoodModel : null;
          final foodId = state.uri.queryParameters['id'] ?? state.uri.queryParameters['productId'] ?? '';
          final restaurantId = state.uri.queryParameters['restaurantId'] ?? state.uri.queryParameters['rId'] ?? '';

          if (extraFood != null) {
            return FoodDetailScreen(food: extraFood);
          }
          return FoodDetailLoaderScreen(
            foodId: foodId,
            restaurantId: restaurantId,
          );
        },
      ),
      GoRoute(
        path: RouteNames.search,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final query = state.extra is String
              ? state.extra as String
              : state.uri.queryParameters['q'];
          return SearchScreen(initialQuery: query);
        },
      ),
      GoRoute(
        path: RouteNames.orders,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const UnifiedOrdersScreen(),
      ),
      // ── Global Azanto screens ────────────────────────────────────────────
      // One implementation each, reachable from both verticals. They are
      // deliberately NOT wrapped in QuickThemeScope even where the widget came
      // from the quick module: a global screen wears the app theme so it looks
      // the same whichever mode the user opened it from.
      GoRoute(
        path: RouteNames.notifications,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: RouteNames.addresses,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AddressesScreen(),
      ),
      GoRoute(
        path: RouteNames.settings,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/orders/details/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return OrderDetailsScreen(orderId: id);
        },
      ),
      GoRoute(
        path: '/orders/track/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return OrderTrackingScreen(orderId: id);
        },
      ),
      GoRoute(
        path: '/orders/delivered/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return OrderDeliveredScreen(orderId: id);
        },
      ),
      GoRoute(
        path: RouteNames.chat,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final args = state.extra as ChatArgs? ?? const ChatArgs(
            orderId: '',
            peerName: 'Support',
            peerRole: 'ADMIN',
          );
          return ChatScreen(args: args);
        },
      ),
      GoRoute(
        path: RouteNames.homeFilter,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            HomeFilterScreen(args: state.extra as HomeFilterArgs),
      ),
      GoRoute(
        path: '/orders/success/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return OrderSuccessScreen(orderId: id);
        },
      ),
      GoRoute(
        path: RouteNames.referral,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ReferralScreen(),
      ),
      GoRoute(
        path: RouteNames.referralTicket,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ReferralTicketResultScreen(),
      ),
      GoRoute(
        path: RouteNames.favorites,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const FavoritesScreen(),
      ),
      // The one address editor: handles both add and edit (food's old
      // add-only screen was replaced by it), and writes through the shared
      // address book so either vertical sees the result immediately.
      GoRoute(
        path: RouteNames.addAddress,
        parentNavigatorKey: rootNavigatorKey,
        // Editing a saved address (extra: Address) keeps the address editor;
        // adding one uses the add-address flow. extra: true = for someone
        // else; 'current' = open filled at the phone's position.
        builder: (context, state) => state.extra is quick_address.Address
            ? AddressSelectionScreen(
                existing: state.extra as quick_address.Address,
              )
            : AddAddressScreen(
                forSomeoneElse: state.extra == true,
                startAtCurrentLocation: state.extra == 'current',
              ),
      ),
      GoRoute(
        path: RouteNames.allOffers,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AllOffersScreen(),
      ),
      GoRoute(
        path: RouteNames.wallet,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const WalletScreen(),
      ),
      GoRoute(
        path: RouteNames.webView,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final extraMap = state.extra as Map<String, dynamic>?;
          final title =
              extraMap?['title']?.toString() ??
              state.uri.queryParameters['title'] ??
              'Web View';
          final url =
              extraMap?['url']?.toString() ??
              state.uri.queryParameters['url'] ??
              '';
          return WebViewScreen(title: title, url: url);
        },
      ),
      GoRoute(
        path: RouteNames.about,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AboutScreen(),
      ),
      GoRoute(
        path: RouteNames.helpSupport,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const HelpSupportScreen(),
      ),
      GoRoute(
        path: RouteNames.privacyPolicy,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),
      GoRoute(
        path: RouteNames.termsConditions,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const TermsConditionsScreen(),
      ),
      GoRoute(
        path: RouteNames.editProfile,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: RouteNames.buyAgain,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final items = state.extra as List<CartItemModel>;
          return ProviderScope(
            overrides: [
              cartViewModelProvider.overrideWith(
                () => CartViewModel(initialItems: items, syncEnabled: false),
              ),
              checkoutViewModelProvider.overrideWith(CheckoutViewModel.new),
            ],
            child: const CartScreen(),
          );
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainAppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: shellNavigatorKeyHome,
            routes: [
              GoRoute(
                path: RouteNames.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: shellNavigatorKeyCart,
            routes: [
              GoRoute(
                path: RouteNames.cart,
                builder: (context, state) => const CartScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: shellNavigatorKeyStore99,
            routes: [
              GoRoute(
                path: RouteNames.store99,
                builder: (context, state) => const Store99Screen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: shellNavigatorKeyProfile,
            routes: [
              GoRoute(
                path: RouteNames.profile,
                // Account is personal: a signed-out visitor is sent to log in.
                // Guarded on hasValue so a cold-start session restore is not
                // mistaken for signed out.
                redirect: (context, state) {
                  final auth = ref.read(authViewModelProvider);
                  if (auth.hasValue && auth.value == null) {
                    return Uri(
                      path: RouteNames.login,
                      queryParameters: {'from': state.matchedLocation},
                    ).toString();
                  }
                  return null;
                },
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
