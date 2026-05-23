
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:glance_app/core/constants/app_constants.dart';

// Conditional import: home_widget is native-only
import 'package:home_widget/home_widget.dart'
    if (dart.library.html) 'package:glance_app/core/utils/home_widget_stub.dart';

/// Handles FCM token management, foreground/background notifications,
/// and native widget wake-up triggers.
class FCMService {
  final FirebaseMessaging? _messaging;

  FCMService({FirebaseMessaging? messaging})
      : _messaging = kIsWeb ? null : (messaging ?? FirebaseMessaging.instance);

  /// Initialize FCM, request permissions, and return the push token
  Future<String?> initialize() async {
    if (kIsWeb || _messaging == null) {
      return null;
    }
    try {
      // Request permission (iOS requires explicit ask)
      final settings = await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        criticalAlert: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return null;
      }

      // Get the FCM token
      final token = await _messaging!.getToken();

      // Configure foreground notification presentation (iOS only, no-op on web)
      await _messaging!.setForegroundNotificationPresentationOptions(
        alert: false, // We handle in-app display ourselves
        badge: true,
        sound: false,
      );

      return token;
    } catch (e) {
      return null;
    }
  }

  /// Stream of token refreshes
  Stream<String> get onTokenRefresh =>
      kIsWeb || _messaging == null ? const Stream.empty() : _messaging!.onTokenRefresh;

  /// Stream of foreground messages
  Stream<RemoteMessage> get onMessage =>
      kIsWeb || _messaging == null ? const Stream.empty() : FirebaseMessaging.onMessage;

  /// Stream of messages opened from notification tap
  Stream<RemoteMessage> get onMessageOpenedApp =>
      kIsWeb || _messaging == null ? const Stream.empty() : FirebaseMessaging.onMessageOpenedApp;

  /// Check if app was opened from a terminated-state notification
  Future<RemoteMessage?> getInitialMessage() =>
      kIsWeb || _messaging == null ? Future.value(null) : _messaging!.getInitialMessage();

  /// Subscribe to a topic (e.g., group-specific)
  Future<void> subscribeToGroup(String groupId) async {
    if (kIsWeb || _messaging == null) return;
    await _messaging!.subscribeToTopic('group_$groupId');
  }

  /// Unsubscribe from a group topic
  Future<void> unsubscribeFromGroup(String groupId) async {
    if (kIsWeb || _messaging == null) return;
    await _messaging!.unsubscribeFromTopic('group_$groupId');
  }

  /// Handle an incoming data message — update native widgets
  Future<void> handleDataMessage(RemoteMessage message) async {
    final data = message.data;
    final type = data['type'];

    if (type == AppConstants.fcmTypeNewPhoto) {
      await _updateNativeWidget(
        photoUrl: data['photoUrl'] ?? '',
        senderName: data['senderName'] ?? '',
        timestamp: data['timestamp'] ?? '',
        groupId: data['groupId'] ?? '',
        photoId: data['photoId'] ?? '',
      );
    }
  }

  /// Push latest photo data to native home screen widgets
  Future<void> _updateNativeWidget({
    required String photoUrl,
    required String senderName,
    required String timestamp,
    required String groupId,
    required String photoId,
  }) async {
    // HomeWidget is native-only — skip on web
    if (kIsWeb) return;

    try {
      await HomeWidget.saveWidgetData<String>(
          AppConstants.widgetKeyPhotoUrl, photoUrl);
      await HomeWidget.saveWidgetData<String>(
          AppConstants.widgetKeySenderName, senderName);
      await HomeWidget.saveWidgetData<String>(
          AppConstants.widgetKeyTimestamp, timestamp);
      await HomeWidget.saveWidgetData<String>(
          AppConstants.widgetKeyGroupId, groupId);
      await HomeWidget.saveWidgetData<String>(
          AppConstants.widgetKeyPhotoId, photoId);

      // Trigger widget refresh on both platforms
      await HomeWidget.updateWidget(
        name: AppConstants.widgetKindHome,
        iOSName: AppConstants.widgetKindHome,
        androidName: 'GlanceWidgetProvider',
      );
    } catch (e) {
      // Widget update is non-critical — don't crash the app
    }
  }

  /// Save latest photo data for widget display (called after successful upload)
  Future<void> saveLatestPhotoForWidget({
    required String photoUrl,
    required String senderName,
    required String groupId,
    required String photoId,
  }) async {
    await _updateNativeWidget(
      photoUrl: photoUrl,
      senderName: senderName,
      timestamp: DateTime.now().toIso8601String(),
      groupId: groupId,
      photoId: photoId,
    );
  }
}

// ─── FCM Data Payload Blueprint ──────────────────────────────────────
/// This is the exact JSON payload format that Cloud Functions sends
/// to trigger silent/background push notifications for widget updates.
///
/// ```json
/// {
///   "message": {
///     "topic": "group_{groupId}",
///     "data": {
///       "type": "new_photo",
///       "photoId": "abc123",
///       "photoUrl": "https://firebasestorage.googleapis.com/...",
///       "senderName": "Viraj",
///       "senderId": "uid_xyz",
///       "groupId": "group_456",
///       "groupName": "Best Friends",
///       "timestamp": "2026-05-20T18:30:00Z",
///       "caption": "Sunset vibes"
///     },
///     "android": {
///       "priority": "high",
///       "ttl": "86400s",
///       "restricted_package_name": "com.glance.app"
///     },
///     "apns": {
///       "headers": {
///         "apns-priority": "10",
///         "apns-push-type": "background"
///       },
///       "payload": {
///         "aps": {
///           "content-available": 1,
///           "mutable-content": 1,
///           "sound": ""
///         }
///       }
///     }
///   }
/// }
/// ```
///
/// Key design decisions:
/// - Uses `data` only (no `notification`) for silent/background delivery
/// - `content-available: 1` wakes the iOS app in background
/// - `apns-push-type: background` ensures iOS processes this silently
/// - `mutable-content: 1` allows Notification Service Extension to modify
/// - Android `priority: high` ensures immediate delivery via FCM
/// - The app's background handler calls `WidgetCenter.shared.reloadAllTimelines()`
///   on iOS and broadcasts an intent to `GlanceWidgetProvider` on Android
