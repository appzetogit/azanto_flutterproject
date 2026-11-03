import 'package:flutter/material.dart';

import '../../../src/core/constants/app_constants.dart' as food;

/// Single source of truth for every environment-specific value the app needs
/// (backend host, map/Firebase keys, package identity). Update values here
/// only — nothing else in the codebase should hardcode these.
class AppConstants {
  AppConstants._();

  static const String title = 'Go Azanto';

  /// Backend REST API base URL (all endpoints are mounted under `/api/v1`).
  static const String baseUrl = 'https://azanto.buytogetherindia.com/api/v1/taxi';

  /// Socket.IO server base (same host, root path — see `Backend/socket-server.js`).
  static const String socketUrl = 'https://azanto.buytogetherindia.com';

  /// Origin that server-relative media paths resolve against.
  ///
  /// The CMS stores image paths like `/1_Bike.png` and `/uploads/...`, not full
  /// URLs, so anything rendering them has to prefix this — see
  /// `resolveMediaUrl` in `core/utils/image_utils.dart`.
  ///
  /// Derived from [baseUrl] rather than written out again so a host change in
  /// one place cannot leave the two pointing at different servers.
  static String get mediaBaseUrl {
    final apiIndex = baseUrl.indexOf('/api/');
    return apiIndex > 0 ? baseUrl.substring(0, apiIndex) : baseUrl;
  }

  /// Google Maps key — the same Azanto key the food module and the native
  /// manifests use (Zicab's key and Firebase project are no longer referenced).
  static const String mapKey = food.AppConstants.mapKey;

  /// Release keystore signing key alias/password — not yet provided.
  static const String signKey = '';

  // --- App behaviour constants (unrelated to environment/build config) ---
  static const int otpLength = 4;
  static const int phoneLength = 10;
  static const double defaultZoomLevel = 16;
  static const Duration otpResendCooldown = Duration(seconds: 30);

  // --- Centralized Font Styles (matching Onboarding & App Theme) ---
  static const String fontFamily = 'Roboto';

  static const TextStyle fontStyleHeadline = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w900,
    color: Color(0xFF0F172A),
    letterSpacing: -0.5,
  );

  static const TextStyle fontStyleTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    color: Color(0xFF0F172A),
    letterSpacing: -0.3,
  );

  static const TextStyle fontStyleSubTitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Color(0xFF0F172A),
  );

  static const TextStyle fontStyleBody = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w500,
    color: Color(0xFF64748B),
    height: 1.4,
  );

  static const TextStyle fontStyleCaption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: Color(0xFF94A3B8),
  );
}
