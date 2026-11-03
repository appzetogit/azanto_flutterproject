/// Every backend path the app calls, relative to `API_BASE_URL` (which already
/// ends in `/api/v1`). Verified against the backend's route files.
abstract final class ApiPaths {
  // Auth — core/auth/auth.routes.js
  static const requestOtp = '/quick/auth/user/request-otp';
  static const verifyOtp = '/quick/auth/user/verify-otp';
  static const refreshToken = '/quick/auth/refresh-token';
  static const logout = '/quick/auth/logout';
  static const me = '/quick/auth/me';

  // User — modules/food/user/routes/user.routes.js
  static const profile = '/quick/user/profile';
  static const wallet = '/quick/user/wallet';
  static const walletTopupOrder = '/quick/user/wallet/topup/order';
  static const walletTopupVerify = '/quick/user/wallet/topup/verify';
  static const addresses = '/quick/user/addresses';
  static String address(String id) => '/quick/user/addresses/$id';
  static String addressDefault(String id) => '/quick/user/addresses/$id/default';
  static const favorites = '/quick/user/favorites';
  static String favoriteFood(String id) => '/quick/user/favorites/foods/$id';
  static const cartSync = '/quick/user/cart';
  static const supportTicket = '/quick/user/support/ticket';

  // Catalog — modules/food/search + modules/food/restaurant
  static const searchProducts = '/quick/search/products';
  /// Is any Mart store serving the zone open right now? Drives the
  /// "store is closed" banner on the home screen.
  static const storeStatus = '/quick/search/store-status';
  static const adminCategories = '/quick/search/categories/admin';
  static String sellerMenu(String id) => '/quick/restaurant/restaurants/$id/menu';
  static String sellerAddons(String id) => '/quick/restaurant/restaurants/$id/addons';
  static const offers = '/quick/restaurant/offers';

  /// The seller list, straight from the backend.
  ///
  /// Sellers used to be inferred from the products in the catalogue, which
  /// meant a store with no products published yet was invisible even though
  /// the backend knew about it. This asks the backend directly.
  static const sellers = '/quick/restaurant/restaurants';

  // Landing — modules/food/landing
  static const heroBanners = '/quick/hero-banners/public';
  static const topBanners = '/quick/top-banners/public';
  static const promotionBanners = '/quick/hero-banners/home-promotion/public';

  /// Admin-configured Mart promotion (the sale banner's title, dates, tiles).
  static const martSaleCampaign = '/quick/mart-sale-campaign/public';

  // CMS pages — modules/food/landing (`/pages/:key`), keys: terms, privacy,
  // refund, shipping, cancellation, support, about.
  static String page(String key) => '/quick/pages/$key';

  // Public settings — modules/food/admin
  static const feeSettings = '/quick/admin/fee-settings/public';

  /// Which delivery zone a coordinate falls in. The polygon test is the
  /// backend's; the app only supplies the point.
  static const zoneDetect = '/quick/zones/detect';

  /// Business identity the admin panel publishes — the storefront name shown
  /// in the app header lives here rather than being compiled in.
  static const businessSettings = '/quick/admin/business-settings/public';

  // Orders — modules/food/orders/routes/order.routes.user.js
  static const orders = '/quick/orders';
  static const calculateOrder = '/quick/orders/calculate';
  static const verifyPayment = '/quick/orders/verify-payment';
  static String order(String id) => '/quick/orders/$id';
  static String orderRoute(String id) => '/quick/orders/$id/route';
  static String orderDropOtp(String id) => '/quick/orders/$id/drop-otp';
  static String orderCancel(String id) => '/quick/orders/$id/cancel';
  static String orderRatings(String id) => '/quick/orders/$id/ratings';
  static String orderInstructions(String id) => '/quick/orders/$id/instructions';
  static String orderPendingPayment(String id) => '/quick/orders/$id/pending-payment';

  // Push tokens — core/notifications/fcm.routes.js. Mounted at `/v1/fcm-tokens`,
  // outside the `/food` namespace the rest of the app lives in.
  static const fcmTokenSave = '/fcm-tokens/mobile/save';
  static const fcmTokenRemove = '/fcm-tokens/remove';

  // Chat — modules/food/chat/routes/chat.routes.js. Customer↔rider threads are
  // keyed on the order id (conversationId == orderId).
  static const chatMessages = '/quick/chat/messages';
  static String chatRead(String conversationId) =>
      '/quick/chat/conversations/$conversationId/read';

  // Notifications — core/notifications/notification.routes.js
  static const notificationInbox = '/quick/notifications/inbox';
  static String notificationRead(String id) => '/quick/notifications/$id/read';
  static String notificationDismiss(String id) => '/quick/notifications/$id';
}
