import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/service/deep_link_service.dart';

/// Receives incoming links and turns them into app state.
///
/// [DeepLinkService] could already *build* and *parse* links, but nothing ever
/// called the parsers: there was no listener, so the manifest's VIEW filters
/// opened the app and dropped the URL. Shared dish and restaurant links landed
/// on the home screen, and a referral code was simply lost. This is the
/// missing receiving end.
///
/// Lives in core/services rather than domain/service on purpose -- it depends on
/// plugins and platform channels, and domain is kept framework-free.
class DeepLinkListener {
  DeepLinkListener._();

  static final DeepLinkListener instance = DeepLinkListener._();

  static const String _referralKey = 'pending_referral_code';

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;

  /// A link that arrived before anything was listening for it.
  ///
  /// Cold start races the UI: the URI is available before the first route is
  /// built, so a product link handled immediately would navigate into a
  /// widget tree that does not exist yet. Parked here and drained by
  /// [takePendingLink] once the app is ready.
  Uri? _pendingLink;

  /// Start listening. Safe to call more than once.
  ///
  /// Cold-start and warm links are fetched separately because they are
  /// genuinely different cases: `getInitialLink` returns the URI that launched
  /// a dead process, while the stream only fires at an already-running app.
  /// Handling one and not the other is the usual reason a link works from the
  /// app switcher but not from cold.
  Future<void> initialize() async {
    if (_subscription != null) return;

    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) await _handle(initial);
    } catch (e) {
      debugPrint('[DeepLink] initial link failed: $e');
    }

    _subscription = _appLinks.uriLinkStream.listen(
      _handle,
      onError: (Object e) => debugPrint('[DeepLink] stream error: $e'),
    );
  }

  Future<void> _handle(Uri uri) async {
    debugPrint('[DeepLink] received: $uri');

    final code = DeepLinkService.parseReferralCode(uri);
    if (code != null) {
      await _storeReferralCode(code);
      return;
    }

    // Product and restaurant links need navigation, which this service does not
    // own. Parked for the widget layer to drain via takePendingLink(); cold
    // start and warm arrival are handled identically because in both cases the
    // navigator may not be ready at this instant.
    _pendingLink = uri;
  }

  /// A referral code is stored rather than applied immediately.
  ///
  /// The recipient taps the invite, but signing up is a later, separate act --
  /// they may browse first, or close the app and come back tomorrow. Holding
  /// the code in storage is what makes the referral survive that gap; applying
  /// it to a form that is not on screen would lose it.
  Future<void> _storeReferralCode(String code) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Never overwrite. The first invite accepted is the one that should be
      // credited; a later link -- often the user revisiting their own share --
      // must not steal it.
      final existing = prefs.getString(_referralKey);
      if (existing != null && existing.isNotEmpty) {
        debugPrint('[DeepLink] referral code already stored, keeping "$existing"');
        return;
      }

      await prefs.setString(_referralKey, code);
      debugPrint('[DeepLink] stored referral code "$code"');
    } catch (e) {
      debugPrint('[DeepLink] could not store referral code: $e');
    }
  }

  /// The stored referral code, if an invite brought this user here.
  static Future<String?> pendingReferralCode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_referralKey);
      return (code == null || code.isEmpty) ? null : code;
    } catch (_) {
      return null;
    }
  }

  /// Clear the stored code once it has been submitted with a signup.
  static Future<void> clearReferralCode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_referralKey);
    } catch (_) {
      // A stale code is harmless: the server rejects a second referral for the
      // same account, so failing to clear it cannot double-credit anyone.
    }
  }

  /// Takes the last non-referral link, clearing it. Returns null if none.
  Uri? takePendingLink() {
    final uri = _pendingLink;
    _pendingLink = null;
    return uri;
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
