# Project Name: Glance — Share Moments Instantly

Glance is a live-photo sharing application and widget (a Locket clone) enabling real-time media sharing within a private circle. This document serves as the master checklist, architecture outline, and production validation roadmap for the Glance system.

---

## Phase 1: Environment Setup & Cross-Platform Hardening

Ensure the compilation and runtime dependencies are correctly configured across iOS, Android, and Web platforms.

- [x] **Configure Project Firebase Credentials** `[High]`
  - Setup Web, Android, and iOS projects in the Firebase Console.
  - Download and configure native credentials files:
    - Android: `android/app/google-services.json`
    - iOS: `ios/Runner/GoogleService-Info.plist`
  - Replace the placeholder options in [firebase_options.dart](file:///c:/V/Glance/lib/firebase_options.dart) with the live API keys, App IDs, and Sender IDs.
  - *Verification*: Run `flutter run -d chrome` and ensure the white screen is resolved, transitioning into the login/splash screen without throwing the "FirebaseOptions cannot be null" initialization exception.
- [x] **Restore Project Assets & Custom Fonts** `[High]`
  - Re-create the missing directories: `assets/images/`, `assets/icons/`, and `assets/fonts/`.
  - Add the custom font files: `SF-Pro-Display-Regular.otf`, `SF-Pro-Display-Medium.otf`, and `SF-Pro-Display-Bold.otf`.
  - Uncomment the assets and fonts block in [pubspec.yaml](file:///c:/V/Glance/pubspec.yaml).
  - *Verification*: Execute `flutter build web` or `flutter build apk` to confirm that the asset-bundler finds all specified assets and fonts without asset load errors.
- [x] **Verify Platform Conditional Compilation & Stubs** `[Medium]`
  - Review all platform stubs in [lib/core/utils/](file:///c:/V/Glance/lib/core/utils/) including:
    - [home_widget_stub.dart](file:///c:/V/Glance/lib/core/utils/home_widget_stub.dart)
    - [image_compress_stub.dart](file:///c:/V/Glance/lib/core/utils/image_compress_stub.dart)
    - [sqflite_stub.dart](file:///c:/V/Glance/lib/core/utils/sqflite_stub.dart)
    - [workmanager_stub.dart](file:///c:/V/Glance/lib/core/utils/workmanager_stub.dart)
  - Ensure all `kIsWeb` conditional guards properly divert native-only operations (like starting `Workmanager` or reading from `sqflite`) to no-ops.
  - *Verification*: Run code analyzer `flutter analyze` to ensure there are no compilation errors or runtime imports conflicts on web target platforms.

---

## Phase 2: Core Logic & High-Performance Media Pipeline

Optimize media captured from the camera to respect tight mobile memory limits, minimize storage cost, and ensure visual quality.

- [x] **Enforce Client-Side Compression Guidelines** `[High]`
  - Intercept the image file path in the preprocessing pipeline.
  - Resize raw photo captures to fit within a `1080x1080` bounding box while preserving the original aspect ratio.
  - Re-encode the image to `JPEG` with a target compression quality of 75%.
  - Verify that final files sent to Firebase Storage do not exceed the strict `200KB` budget.
  - *Verification*: Capture a photo in-app, retrieve its size from local cache, and verify it is under 200KB and formatted as JPEG.
- [x] **Implement Widget-Side Native Caching** `[High]`
  - **iOS WidgetKit Extension**:
    - Configure `URLCache.shared` inside Swift extension code with a `10MB` memory and `50MB` disk cap.
    - Write the downloaded image data to the App Group shared directory (`group.com.glance.app`) to make it instantly accessible offline.
  - **Android AppWidget**:
    - Configure local file caching inside Android's `GlanceWidgetProvider.kt`.
    - Save downloaded image bitmaps into a dedicated cache folder in the application's external/internal cache directory.
  - *Verification*: Turn off network access on the device/simulator, trigger a widget repaint, and check if the widget successfully renders the cached image fallback.
- [x] **Establish Network Timeout limits & Fallback State UI** `[Medium]`
  - Inject a strict `10-second` connection timeout when requesting widget image payload updates.
  - Implement fallback UI displays for both platforms:
    - iOS: Display camera icon, sender's name, and a "Weak connection" warning.
    - Android: Provide a "Tap to retry" layout with a `PendingIntent` trigger.
  - Ensure deep-linking works, redirecting user clicks on fallback screens directly back to the app's camera interface.
  - *Verification*: Simulate high latency/network loss, verify that the fallback widget interface is visible within 10 seconds, and verify that tapping the fallback opens the camera page.

---

## Phase 3: Database/Storage, Offline Sync & Push Channels

Develop robust background channels to deliver real-time widget updates and queue offline uploads during connectivity drops.

- [x] **Configure Silent Push Notifications (FCM)** `[High]`
  - Set up FCM server integrations to issue data-only notification payloads.
  - Ensure APNs background headers are declared:
    - `"apns-priority": "5"`
    - `"apns-push-type": "background"`
    - `"content-available": 1`
  - Ensure Android payload properties declare high execution priority: `priority: "high"`.
  - *Verification*: Send a test data payload via Firebase Console to a backgrounded device and verify that the system wakes the native background worker without displaying a visible system notification banner.
- [x] **Establish Native App-to-Widget IPC Bridge** `[High]`
  - **iOS App Group Shared Cache**:
    - Add the App Group entitlement to both the host application `Runner` and `GlanceWidgetExtension` targets.
    - Set the identifier identifier to `group.com.glance.app`.
    - Write data key-value pairs (URL, sender, timestamp) to `UserDefaults(suiteName: "group.com.glance.app")`.
  - **Android SharedPreferences**:
    - Save variables to the shared preference space matching the name `"FlutterSharedPreferences"`.
    - Prefix keys with `"flutter."` (e.g., `flutter.photoUrl`) to allow Dart and Java/Kotlin platforms to share storage state.
  - *Verification*: Inspect logs to confirm that the native widget target is able to read the shared preferences written by the Flutter application.
- [x] **Offline Queue System (SQLite Database)** `[High]`
  - Create the SQLite database table `offline_queue` via `QueueService` with fields: `id`, `imagePath`, `groupId`, `caption`, and `retryCount`.
  - Register a `Workmanager` one-off task constrainted to `NetworkType.connected` to process the queue in the background.
  - Retry failed uploads up to 3 times before dropping the item to prevent perpetual queue blocks.
  - *Verification*: Disable cellular/Wi-Fi connection, take a photo in-app, verify that an entry is added to `offline_queue` SQLite database, then re-enable network connection and verify that the photo uploads automatically in the background.
- [x] **Manage Firestore Stream Connections Lifecycle** `[Medium]`
  - Integrate a `WidgetsBindingObserver` in [main.dart](file:///c:/V/Glance/lib/main.dart) to listen to state changes.
  - Detach active Firestore stream listeners when the app enters `AppLifecycleState.paused` or `AppLifecycleState.detached`.
  - Re-establish Firestore subscriptions and pull updates when the app transitions back to `AppLifecycleState.resumed`.
  - *Verification*: Switch the app to background, observe logs to ensure Firestore stream listeners are closed, then restore the app to the foreground and verify listeners are refreshed.

---

## Phase 4: UI/Interface & Moderation Compliance

Design an interface with micro-animations, custom typography, and strict user-generated content controls.

- [x] **Onboarding Flow & UGC Consent EULA** `[High]`
  - Build onboarding pages using Outfit or SF-Pro modern typography.
  - Create a mandatory End User License Agreement (EULA) screen with an explicit consent checkbox.
  - Block application access if the user rejects the terms of service (ToS).
  - *Verification*: Install app fresh, verify the onboarding screen displays, and verify that the user cannot proceed to register or create groups without accepting the terms.
- [x] **Implement Image Moderation Tools (Report / Block)** `[High]`
  - Add a "Report Image" action icon on the feed items.
    - Save reports to a `reports` collection in Firestore containing `photoId`, `senderId`, `reporterId`, and `timestamp`.
  - Add a "Block User" action on the user details view.
    - Append the blocked user's UID to a `blockedUsers` array inside the current user's profile document.
    - Filter feed queries on the client side to instantly hide any photo published by blocked users.
  - *Verification*: Tap "Report" on a feed photo, verify that a corresponding Firestore entry is created. Tap "Block User", and verify that all current and subsequent photos from that user disappear from the feed.
- [x] **Group Registration and Invite System** `[Medium]`
  - Develop a screen allowing users to create groups and generate a unique alphanumeric invite code.
  - Enable joining existing groups by entering the invite code.
  - Add smooth micro-animations during invite code validation and group joins.
  - *Verification*: Create a group, copy the code, login as another user, enter the code, and confirm successful membership.

---

## Phase 5: Store Compliance & Native Deployments

Hardening configurations, properties, permissions, and app metadata for App Store and Google Play Console compliance.

- [x] **Apple iOS App Store Configuration** `[Medium]`
  - Configure `Info.plist` usage descriptions with clear context explanations:
    - `NSCameraUsageDescription`: *"Glance needs camera access so you can capture moments and send them instantly to your friends' widgets."*
    - `NSPhotoLibraryUsageDescription`: *"Glance needs gallery access to let you select photos for sharing."*
  - Control iOS widget timeline reload policy:
    - Set the timeline reload to `.atEnd` or schedule it with dynamic cooldowns.
    - Restrict calls to `WidgetCenter.shared.reloadAllTimelines()` to prevent hitting the daily reload limit (40–70 updates/day).
  - *Verification*: Confirm that App Store deployment logs show zero compliance warnings regarding permissions or API usages.
- [x] **Google Play Console Compliance** `[Medium]`
  - Declare `<uses-permission android:name="android.permission.CAMERA" />` in `AndroidManifest.xml`.
  - Include push notification permission requests for Android 13+ devices (`android.permission.POST_NOTIFICATIONS`).
  - *Verification*: Perform runtime permission checks in the app, and verify that the app prompts users with standard dialog overlays on initial camera visits.
- [x] **Generate Custom Icons & Splash Screens** `[Low]`
  - Use `flutter_launcher_icons` to generate adaptive icon assets for iOS and Android formats.
  - Build native launch screens using the Glance theme brand colors to replace the default white screen.
  - *Verification*: Launch the app on a physical device, and verify that the custom splash screen and application icons are displayed correctly.

---

## Phase 6: Testing & Security Audits

Verify system functionality, database access permissions, and overall application reliability.

- [x] **Database & Storage Security Audits** `[High]`
  - Audit `firestore.rules` and `storage.rules`.
  - Confirm security rules restrict unauthorized reads and writes:
    - Ensure users can only read/write photos inside groups they are active members of.
    - Prevent modifying structural group fields or sender metadata.
  - *Verification*: Write integration tests or manually verify that requests from an unauthenticated user or a user not in the group are rejected by Firestore with a permission-denied error.
- [x] **Unit and Widget Test Execution** `[Medium]`
  - Run `flutter test` on the command line.
  - Write test specs verifying Riverpod states, stub responses, and image compression behaviors.
  - *Verification*: Confirm that all unit tests pass with zero failure exit codes.

---

## Phase 7: Group Creation & Join UI Entries

Enable group management page navigations and empty-state guides.

- [x] **Add homePageIndexProvider** `[High]`
- [x] **Implement global navigation in home_screen.dart** `[High]`
- [x] **Make Group Selector in camera_screen.dart interactive** `[High]`
- [x] **Welcome overlay for users with no groups** `[High]`
- [x] **Action buttons in group management screen** `[Medium]`

---

## Phase 8: Group Creation Hang & Timeout Recovery

Resolve Firestore offline-first write freezes.

- [x] **Added 15s write timeouts in firestore_service.dart** `[High]`
- [x] **Status UI and TimeoutException catch in create_group_screen.dart** `[High]`
- [x] **Catch TimeoutException in group_management_screen.dart** `[Medium]`

---

## Phase 9: Storage Upload Hang & Timeout Recovery

Prevent storage upload UI freezes.

- [x] **Added 60s upload timeouts in storage_service.dart** `[High]`
- [x] **Timeout catch in uploadPhoto provider and error feedback** `[High]`

---

## Phase 10: Modernize Android Gradle Build & APK Compilation

Update build settings for compilation compatibility.

- [x] **Migrate settings.gradle and app/build.gradle to modern plugin DSL** `[High]`
- [x] **Upgrade Android Gradle Plugin to 8.9.1 and compileSdk to 36** `[High]`
- [x] **Upgrade Workmanager dependency to 0.9.0** `[High]`
- [x] **Correct windowBackground styling XML namespaces** `[High]`

---

## Phase 11: Fix Camera Stretching & Timing Issues

- [x] **Correct aspect ratio layout in camera_screen.dart** `[High]`
- [x] **Adjust timeouts in firestore_service.dart and storage_service.dart** `[High]`

---

## Phase 12: Robust Camera Preview Scaling

- [x] **FittedBox aspect ratio correction on camera preview** `[High]`
- [x] **Compression timeouts added to prevent thread lock** `[High]`

---

## Phase 13: Aspect Ratio Lock & Database Write Timeouts

- [x] **Locked camera preview aspect ratio using FittedBox + display ratio locked SizedBox** `[High]`
- [x] **Add 15s write timeouts to createGroup, createInvite, and createPhoto in firestore_service.dart** `[High]`

---

## Phase 14: Profile Settings, Group Management, and Compliance

Complete compliance items, profile customizability, group lifecycle control, and forgot password flows.

- [x] **Add deleteAccount to AuthService in auth_service.dart** `[High]`
- [x] **Implement Forgot Password recovery in login_screen.dart** `[Medium]`
- [x] **Create profile_settings_screen.dart with name & avatar updates, logout, and deletion controls** `[High]`
- [x] **Connect settings screen from group_management_screen.dart and add Leave Group and Delete Group actions** `[High]`
- [x] **Verify that CI/CD runs and builds the release APK successfully** `[High]`

---

## Notes & Constraints

1. **iOS Widget Limit**: iOS background widget processes have a strict **30MB memory limit**. Keep downloaded image size small (target under 200KB, max bounding box of 1080x1080 JPEG) to avoid background memory jettons.
2. **App Groups**: Native communications on iOS require a shared App Group. Use `group.com.glance.app` consistently in Xcode settings and Dart/Swift references.
3. **Android Shared Preferences**: To allow the native AppWidget and Flutter to communicate, keys stored in Shared Preferences MUST have a `"flutter."` prefix, and the database name must be `"FlutterSharedPreferences"`.
4. **Web Compilation Compatibility**: Do not use packages like `sqflite` or `workmanager` directly without protecting imports and invocations using `kIsWeb` conditional guards or custom web-stubs.
5. **UGC Compliance**: To satisfy App Store Guideline 1.2 (User Generated Content), a EULA approval check is mandatory during onboarding, along with client-side block/report tools.
