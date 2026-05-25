# Glance — Live-Photo Sharing App & Home Screen Widget

Glance is a live-photo sharing application and widget (a Locket Widget clone) designed to let users share real-time photo captures directly to their friends' home screens. It features custom camera sizing, multi-platform stubs for Web compatibility, Firestore write timeouts, image moderation tools (Report / Block), and an offline-sync queue.

---

## 🚀 Key Features

* **Instant Camera Capture & Compression**: Resizes photos to `1080x1080` JPEG under `200KB` locally to conserve bandwidth and conform to iOS/Android background memory limits.
* **Native Home Screen Widgets**: 
  * **Android AppWidget** (`GlanceWidgetProvider`): Caches latest images locally to prevent blank states, includes dynamic "Tap to retry" layouts, and supports deep-linking.
  * **iOS WidgetKit Extension**: Shares updates via iOS App Groups (`group.com.glance.app`).
* **Offline-First Synchronization**: Queues posts taken offline in a local SQLite database, scheduling a `Workmanager` background service to sync them once connection is restored.
* **UGC Compliance & Moderation**: Built-in onboarding EULA agreement, and in-feed User Blocking and Content Reporting (complying with Apple App Store Guideline 1.2).
* **FCM Silent Updates**: Real-time push updates delivering widgets payload synchronously.

---

## 🛠️ Prerequisites

* **Flutter SDK**: `>=3.3.0 <4.0.0`
* **Java Development Kit (JDK)**: Version 17
* **Android Gradle Plugin (AGP)**: Version 8.9.1
* **Gradle Wrapper**: Version 8.11.1

---

## 📁 Project Structure

* `/lib`: Core Flutter source code.
  * `lib/core/services`: Backend wrappers for Firebase Auth, Firestore, Cloud Storage, FCM, and background sync.
  * `lib/core/utils`: Web/Mobile stubs (`sqflite_stub.dart`, `workmanager_stub.dart`, etc.) to prevent compile errors.
  * `lib/features`: UI pages (Auth, Onboarding, Camera preview, Group Feed, settings/profile, group join/create).
* `/android`: Native Android module including `GlanceWidgetProvider.kt` widget layout.
* `/ios`: Native iOS module containing runner and widget targets.
* `/functions`: Node.js cloud functions to handle background notification fan-out.

---

## 🔥 Firebase Setup Guide

Follow these steps to link your own Firebase project with Glance:

### Step 1: Create a Firebase Project
1. Go to the [Firebase Console](https://console.firebase.google.com/).
2. Click **Add project** and name it (e.g. `glance-app`).

### Step 2: Set up Database & Storage
1. **Cloud Firestore**:
   * Click **Build ➜ Firestore Database** in the left sidebar.
   * Click **Create database**. Start in test mode or production, selecting a location close to your users.
   * Copy the rules from the project's root `firestore.rules` and paste them into the console's **Rules** tab, then click **Publish**.
2. **Firebase Storage**:
   * Click **Build ➜ Storage** in the left sidebar.
   * Click **Get started**. Select test/production, match your Firestore location, and click **Done**.
   * Copy the rules from the project's root `storage.rules` and paste them into the console's **Rules** tab, then click **Publish**.

### Step 3: Register Apps & Generate Configs
1. **Web App Setup**:
   * Click the web icon (`</>`) in the console homepage to add an app.
   * Copy the configuration values into [lib/firebase_options.dart](file:///c:/V/Glance/lib/firebase_options.dart) inside the `web` and `windows` blocks.
2. **Android App Setup**:
   * Click the Android icon to add an app.
   * Package Name **MUST** be: `com.glance.app`
   * Download `google-services.json` and place it in your local workspace at `android/app/google-services.json`.
   * Also, copy the `apiKey`, `appId`, and `messagingSenderId` from the config into the `android` block in [lib/firebase_options.dart](file:///c:/V/Glance/lib/firebase_options.dart).
3. **iOS App Setup**:
   * Click the iOS icon to add an app.
   * Bundle ID **MUST** be: `com.glance.app`
   * Download `GoogleService-Info.plist` and drag it into your Xcode project's `Runner/` directory.
   * Copy the keys into the `ios` block in [lib/firebase_options.dart](file:///c:/V/Glance/lib/firebase_options.dart).

---

## 📡 Push Notifications & Functions Setup

To push photos instantly to friends' home screen widgets when someone posts:

1. **Deploy Cloud Functions**:
   * Navigate to `/functions` directory.
   * Initialize Firebase CLI: `firebase init functions` (choose TypeScript, link to your project).
   * Overwrite `/functions/src/index.ts` with the file provided in this repository.
   * Install functions dependencies: `npm install` inside `/functions`.
   * Deploy to your Firebase project: `firebase deploy --only functions`.
2. **FCM Key Handshakes**:
   * On iOS, configure APNs credentials in Firebase Project Settings ➜ Cloud Messaging.
   * Ensure APNs background headers match the silent push formatting defined in [fcm_service.dart](file:///c:/V/Glance/lib/core/services/fcm_service.dart).

---

## 🏃 Running the Project

### Running Locally
```bash
# Fetch flutter packages
flutter pub get

# Run on an emulator, device, or web browser
flutter run
```

### Compiling Release APK
```bash
flutter build apk --release
```
The compiled release binary will be generated at `build/app/outputs/flutter-apk/app-release.apk`.
