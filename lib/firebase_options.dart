import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for each platform.
///
/// HOW TO GET THESE VALUES:
/// 1. Go to https://console.firebase.google.com
/// 2. Select your project
/// 3. Click the gear icon → Project Settings
/// 4. Scroll down to "Your apps"
/// 5. If you don't have a web app, click "Add app" → Web (</>)
/// 6. Copy the config values from the Firebase SDK snippet
///
/// Alternatively, install FlutterFire CLI and run:
///   dart pub global activate flutterfire_cli
///   flutterfire configure
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError('macOS is not supported');
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError('Linux is not supported');
      default:
        throw UnsupportedError('${defaultTargetPlatform} is not supported');
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // TODO: Replace all placeholder values below with your actual Firebase
  // project credentials from https://console.firebase.google.com
  // ──────────────────────────────────────────────────────────────────────

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBrSudz-rDYL-osmt4Qdao8HpZfzASFhsw',
    appId: '1:215701464195:web:670c00dee5dfee4fe1a7b6',
    messagingSenderId: '215701464195',
    projectId: 'glance-2f9b3',
    authDomain: 'glance-2f9b3.firebaseapp.com',
    storageBucket: 'glance-2f9b3.firebasestorage.app',
    measurementId: 'G-1S4NBN4YNF',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB53OSG5d9UQNu9oIolSsMUC6TOAS2aBhU',
    appId: '1:215701464195:android:26e9fe231178a8cce1a7b6',
    messagingSenderId: '215701464195',
    projectId: 'glance-2f9b3',
    storageBucket: 'glance-2f9b3.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCOHRel3vgI1o_CdPeZ_AXYX2fDNGFVats',
    appId: '1:215701464195:ios:3dc3af42702a8ccfe1a7b6',
    messagingSenderId: '215701464195',
    projectId: 'glance-2f9b3',
    storageBucket: 'glance-2f9b3.firebasestorage.app',
    iosBundleId: 'com.glance.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBrSudz-rDYL-osmt4Qdao8HpZfzASFhsw',
    appId: '1:215701464195:web:4ca33c333b63c5c0e1a7b6',
    messagingSenderId: '215701464195',
    projectId: 'glance-2f9b3',
    authDomain: 'glance-2f9b3.firebaseapp.com',
    storageBucket: 'glance-2f9b3.firebasestorage.app',
    measurementId: 'G-NZF97LN5C3',
  );

}