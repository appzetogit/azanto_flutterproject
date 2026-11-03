import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class LocaleLanguageList {
  final String name;
  final String lang;
  final String? flag;

  const LocaleLanguageList({required this.name, required this.lang, this.flag});
}

/// Central App Constants for Azanto User Application.
class AppConstants {
  const AppConstants._();

  static const String title = 'Go Azanto';
  static const String appName = 'Go Azanto';

  /// Merchant name shown on the Razorpay checkout sheet.
  ///
  /// Without this Razorpay falls back to the legal entity registered on the
  /// account ("SWITCHEATS PRIVATE LIMITED"), which is not our consumer brand.
  static const String brandName = 'Go Azanto';

  /// Public logo URL for the Razorpay sheet. Razorpay fetches this over the
  /// network, so a bundled asset cannot be used — it must be a hosted URL.
  /// Falls back to the backend's configured business logo when set.
  static const String brandLogoUrl = String.fromEnvironment('BRAND_LOGO_URL');
  static const String appVersion = '1.0.0';

  /// The user app's Play Store listing — what "Share App" and Refer & Earn
  /// send, so a friend lands on the install page rather than the website.
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.maava.user';

  /// Backend REST API host domain — the merged Azanto backend (maava-new),
  /// served by nginx on maava.in: /api → :5100, /socket.io → :5101, /uploads
  /// static. The vertical (/v1/food vs /v1/quick) is chosen per path.
  static const String hostUrl = String.fromEnvironment(
    'API_HOST',
    defaultValue: 'https://azanto.buytogetherindia.com',
  );

  /// Backend REST API base URL (all endpoints mounted under `/api/v1`).
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '$hostUrl/api/v1',
  );

  /// Socket.IO server URL.
  static const String socketUrl = String.fromEnvironment(
    'SOCKET_URL',
    defaultValue: hostUrl,
  );

  // ---------------------------------------------------------------- Firebase
  //
  // The single source of Firebase config in Dart (project maava-7ddea, app
  // com.maava.user). Must match android/app/google-services.json — the native
  // file the Android build still reads; iOS reads ios/Runner/
  // GoogleService-Info.plist, which still points at the old project.

  /// Firebase project configuration for User App (com.maava.user).
  static final String firebaseApiKey = (kIsWeb || Platform.isAndroid)
      ? "AIzaSyAk816xWLpXOSF4KFW4ms59acIN5mO_Z_U"
      : "ios firebase api key";

  static final String firebaseAppId = (kIsWeb || Platform.isAndroid)
      ? "1:595117846778:android:1cf7944223f646b1b41943"
      : "ios firebase app id";

  static final String firebaseMessagingSenderId =
      (kIsWeb || Platform.isAndroid) ? "595117846778" : "ios firebase sender id";

  static final String firebaseProjectId = (kIsWeb || Platform.isAndroid)
      ? "maava-7ddea"
      : "ios firebase project id";

  /// Realtime Database used for live order tracking (`active_orders/...`).
  static const String firebaseDatabaseUrl =
      "https://maava-7ddea-default-rtdb.asia-southeast1.firebasedatabase.app";

  /// Options for `Firebase.initializeApp` when the native config is missing.
  static FirebaseOptions get firebaseOptions => FirebaseOptions(
        apiKey: firebaseApiKey,
        appId: firebaseAppId,
        messagingSenderId: firebaseMessagingSenderId,
        projectId: firebaseProjectId,
        databaseURL: firebaseDatabaseUrl,
      );

  /// Google Maps API key (Maps SDK + Geocoding API).
  ///
  /// Overridable via `--dart-define-from-file=config/keys.env` (key
  /// `MAPS_API_KEY`) — same pattern as [hostUrl]/[baseUrl]/[socketUrl] above.
  /// The literal default only exists so old builds keep working; once this
  /// key is rotated in Google Cloud Console, put the new one in keys.env
  /// instead of committing it here.
  static const String mapKey = String.fromEnvironment(
    'MAPS_API_KEY',
    defaultValue: 'AIzaSyBbtwNQfVuTpYXe5IUv-g6ZJZMcjgbDul0',
  );

  /// Payment Gateway keys.
  static const String stripePublishKey = '';
  static const String stripPublishKey = stripePublishKey;
  static String razorpayKey = '';

  /// Supported App Languages.
  static List<LocaleLanguageList> languageList = const [
    LocaleLanguageList(name: 'English', lang: 'en'),
  ];

  static String packageName = 'com.maava.user';
  static String signKey = '';
}
