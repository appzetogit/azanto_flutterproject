/// Every quick-commerce route path and name. All module-owned screens live
/// under the `/quick` prefix so they can coexist with the food vertical in the
/// single Azanto router; auth and splash resolve to the shared app screens.
abstract final class RoutePaths {
  // Shared Azanto screens (owned by the app shell, not this module).
  static const splash = '/';
  static const onboarding = '/';
  static const login = '/login';
  static const otp = '/otp';

  static const locationPermission = '/quick/location';
  static const addressSelection = '/quick/address/select';

  // Shell tabs
  static const home = '/quick/home';
  static const categories = '/quick/categories';
  static const cart = '/quick/cart';
  static const orders = '/quick/orders';
  static const profile = '/quick/profile';

  static const search = '/quick/search';
  static const subCategory = '/quick/category/:id';
  static const brands = '/quick/brands';
  static const productListing = '/quick/products';
  static const productDetails = '/quick/product/:id';
  static const wishlist = '/quick/wishlist';
  static const wallet = '/quick/wallet';
  static const checkout = '/quick/checkout';
  static const coupons = '/quick/coupons';
  static const payment = '/quick/payment';
  static const addresses = '/quick/addresses';
  static const notifications = '/quick/notifications';
  static const orderSuccess = '/quick/order/:id/success';
  static const orderTracking = '/quick/order/:id/track';
  static const orderChat = '/quick/order/:id/chat';
  static const orderDetails = '/quick/order/:id';
  static const editProfile = '/quick/profile/edit';
  static const help = '/quick/profile/help';
  static const settings = '/quick/profile/settings';
  static const privacyPolicy = '/quick/profile/privacy';
  static const terms = '/quick/profile/terms';
  static const about = '/quick/profile/about';

  /// Shared login, returning to [path] inside the quick vertical after OTP.
  static String loginFrom(String path) => '/login?from=$path';

  static String subCategoryOf(String categoryId) => '/quick/category/$categoryId';
  static String productDetailsOf(String productId) => '/quick/product/$productId';
  static String orderDetailsOf(String orderId) => '/quick/order/$orderId';
  static String orderSuccessOf(String orderId) => '/quick/order/$orderId/success';
  static String orderTrackingOf(String orderId) => '/quick/order/$orderId/track';
  static String orderChatOf(String orderId) => '/quick/order/$orderId/chat';
}

abstract final class RouteNames {
  static const locationPermission = 'quickLocationPermission';
  static const addressSelection = 'quickAddressSelection';
  static const home = 'quickHome';
  static const categories = 'quickCategories';
  static const cart = 'quickCart';
  static const orders = 'quickOrders';
  static const profile = 'quickProfile';
  static const search = 'quickSearch';
  static const subCategory = 'quickSubCategory';
  static const brands = 'quickBrands';
  static const productListing = 'quickProductListing';
  static const productDetails = 'quickProductDetails';
  static const wishlist = 'quickWishlist';
  static const wallet = 'quickWallet';
  static const checkout = 'quickCheckout';
  static const coupons = 'quickCoupons';
  static const payment = 'quickPayment';
  static const addresses = 'quickAddresses';
  static const notifications = 'quickNotifications';
  static const orderSuccess = 'quickOrderSuccess';
  static const orderTracking = 'quickOrderTracking';
  static const orderChat = 'quickOrderChat';
  static const orderDetails = 'quickOrderDetails';
  static const editProfile = 'quickEditProfile';
  static const help = 'quickHelp';
  static const settings = 'quickSettings';
  static const privacyPolicy = 'quickPrivacyPolicy';
  static const terms = 'quickTerms';
  static const about = 'quickAbout';
}
