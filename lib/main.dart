import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:azanto/src/core/constants/app_constants.dart';
import 'package:azanto/src/food_user_application.dart';
import 'package:azanto/src/platform/notifications/push_service.dart';
import 'package:azanto/src/quick/core/local_storage/shared_prefs_storage.dart';
import 'package:azanto/src/quick/core/network/media_url.dart';
import 'package:azanto/src/core/services/deep_link_listener.dart';
import 'package:azanto/src/quick/di/repository_providers.dart' as quick_di;
import 'package:azanto/taxi/taxi_section.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[APP] App Started');

  // TEMPORARY: a release build's default error widget is a blank grey box —
  // debug shows the exception, release hides it. This puts the exception back
  // on screen so a crash mid-checkout is reportable without adb access.
  // Remove once the release-only order-success crash is found.
  ErrorWidget.builder = (details) => Material(
    color: const Color(0xFFB00020),
    child: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Text(
          details.exceptionAsString(),
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      ),
    ),
  );

  // Started before runApp so a cold-start link -- the URI that launched the
  // process -- is captured rather than lost while the first frame builds.
  unawaited(DeepLinkListener.instance.initialize());

  // Portrait only, whatever the phone's auto-rotate setting says. Awaited
  // before runApp so the first frame is already laid out upright — set after,
  // and a phone held sideways builds one landscape frame and snaps.
  //
  // Belt and braces with the native lock (AndroidManifest screenOrientation,
  // Info.plist UISupportedInterfaceOrientations): this call only governs the
  // Flutter view, so anything drawn by the platform — permission prompts, the
  // share sheet, the Razorpay activity — needs the manifest to stay upright.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final firebaseOk = await ensureFirebaseInitialized();
  if (firebaseOk) {
    debugPrint('[APP] Firebase Initialized');
  }

  try {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    debugPrint('[FCM] Background Handler Registered');
  } catch (e) {
    debugPrint('[FCM] Background Handler Registration failed: $e');
  }

  // Quick-commerce module: resolve relative /uploads/... image paths and give
  // it its key-value store (the food side keeps its own storage tiers).
  MediaUrl.configure(AppConstants.baseUrl);
  final quickStorage = await SharedPrefsStorage.create();
  final taxiOverrides = await TaxiSection.overrides();

  runApp(
    ProviderScope(
      overrides: [
        quick_di.localStorageProvider.overrideWithValue(quickStorage),
        ...taxiOverrides,
      ],
      child: const FoodUserApplication(),
    ),
  );
}
