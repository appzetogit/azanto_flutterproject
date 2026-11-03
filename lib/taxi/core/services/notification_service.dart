import 'dart:developer' as developer;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'audio_service.dart';

/// Taxi side of push. In Azanto the food module's PushService owns Firebase
/// (background handler, local-notification display), so this only hands out
/// the FCM token for the taxi backend and listens for ride events.
class NotificationService {
  bool _listening = false;

  Future<String?> init({
    required void Function(RemoteMessage message) onForegroundMessage,
    required void Function(RemoteMessage message) onMessageOpened,
  }) async {
    try {
      if (!_listening) {
        _listening = true;
        FirebaseMessaging.onMessage.listen((message) {
          _checkAudioForNotification(message);
          onForegroundMessage(message);
        });
        FirebaseMessaging.onMessageOpenedApp.listen(onMessageOpened);
      }
      return await FirebaseMessaging.instance.getToken();
    } catch (error) {
      if (kDebugMode) {
        developer.log('NotificationService init skipped: $error');
      }
      return null;
    }
  }

  void _checkAudioForNotification(RemoteMessage message) {
    final data = message.data;
    final type = (data['type'] ?? data['event'] ?? '').toString().toLowerCase();
    final status = (data['status'] ?? '').toString().toLowerCase();
    final title = (message.notification?.title ?? '').toLowerCase();
    final body = (message.notification?.body ?? '').toLowerCase();

    // Trip-start deliberately makes no sound — see the note in
    // `RideTrackingController._checkAudioTrigger`. Only completion still plays.
    final combined = '$type $status $title $body';
    if (combined.contains('complete') || combined.contains('end')) {
      AudioService.playRideEnded();
    }
  }
}
