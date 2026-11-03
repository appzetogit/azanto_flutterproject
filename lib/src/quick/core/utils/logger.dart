import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Thin wrapper so log calls are greppable and stripped in release.
abstract final class AppLogger {
  /// `debugPrint` as well as `developer.log`: the latter only reaches the VM
  /// service, so nothing showed up in `adb logcat` or `flutter logs` — which is
  /// where anyone debugging a device build actually looks. Both are stripped
  /// in release by the kDebugMode guard.
  static void debug(String message, {String scope = 'app'}) {
    if (!kDebugMode) return;
    developer.log(message, name: 'maava.$scope');
    debugPrint('[$scope] $message');
  }

  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      developer.log(
        message,
        name: 'suvio.error',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
