import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:glance_app/core/theme/glance_theme.dart';
import 'package:glance_app/core/providers/providers.dart';
import 'package:glance_app/core/constants/app_constants.dart';
import 'package:glance_app/features/auth/screens/auth_wrapper.dart';
import 'package:glance_app/core/services/background_service.dart';
import 'package:glance_app/firebase_options.dart';

// Conditional import: home_widget is native-only
import 'package:home_widget/home_widget.dart'
    if (dart.library.html) 'package:glance_app/core/utils/home_widget_stub.dart';

/// Top-level FCM background handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // HomeWidget is native-only — skip on web
  if (kIsWeb) return;

  final data = message.data;
  if (data['type'] == AppConstants.fcmTypeNewPhoto) {
    await HomeWidget.saveWidgetData<String>(
        AppConstants.widgetKeyPhotoUrl, data['photoUrl'] ?? '');
    await HomeWidget.saveWidgetData<String>(
        AppConstants.widgetKeySenderName, data['senderName'] ?? '');
    await HomeWidget.saveWidgetData<String>(
        AppConstants.widgetKeyTimestamp, data['timestamp'] ?? '');
    await HomeWidget.saveWidgetData<String>(
        AppConstants.widgetKeyPhotoId, data['photoId'] ?? '');

    await HomeWidget.updateWidget(
      name: AppConstants.widgetKindHome,
      iOSName: AppConstants.widgetKindHome,
      androidName: 'GlanceWidgetProvider',
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait (mobile only — no-op on web)
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    // System UI style (mobile only)
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: GlanceTheme.backgroundDark,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('[Firebase] Initialization error: $e');
  }

  // Enable Firestore persistence on Web so .get() can use cached data
  // while the WebSocket connection is being established.
  if (kIsWeb) {
    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (e) {
      debugPrint('[Firestore] Persistence settings failed: $e');
    }
  }

  // Register background message handler (not supported on web)
  if (!kIsWeb) {
    try {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint('[FCM] Background handler registration failed: $e');
    }
  }

  // Initialize Background Service — Workmanager (native only)
  if (!kIsWeb) {
    BackgroundService.initialize().catchError((e) {
      debugPrint('[BackgroundService] Failed to initialize background service: $e');
    });
  }

  runApp(const ProviderScope(child: GlanceApp()));
}

class GlanceApp extends ConsumerStatefulWidget {
  const GlanceApp({super.key});

  @override
  ConsumerState<GlanceApp> createState() => _GlanceAppState();
}

class _GlanceAppState extends ConsumerState<GlanceApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeFCM();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref.read(appLifecycleStateProvider.notifier).state = state;
  }

  Future<void> _initializeFCM() async {
    if (kIsWeb) return;
    try {
      final fcmService = ref.read(fcmServiceProvider);
      final token = await fcmService.initialize();

      if (token != null) {
        final authService = ref.read(authServiceProvider);
        await authService.updatePushToken(token);
      }

      // Listen for token refreshes
      fcmService.onTokenRefresh.listen((newToken) async {
        final authService = ref.read(authServiceProvider);
        await authService.updatePushToken(newToken);
      });

      // Handle foreground messages
      fcmService.onMessage.listen((message) {
        fcmService.handleDataMessage(message);
      });
    } catch (e, stack) {
      debugPrint('[FCM] Error initializing FCM: $e\n$stack');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: GlanceTheme.darkTheme,
      home: const AuthWrapper(),
    );
  }
}
