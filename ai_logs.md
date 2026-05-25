# AI Development & Optimization Logs

This log records the complete history of technical enhancements, optimizations, bug resolutions, and compliance features implemented in the Glance project by the AI agent.

---

## 🛠️ Build System & Native Architecture Upgrades

### Android Gradle Modernization
* **Migrated Plugin DSL**: Upgraded `settings.gradle` and `app/build.gradle` to modern plugin DSL configurations, eliminating legacy `buildscript` dependencies and resolving classpath conflicts.
* **SDK and AGP Upgrades**:
  * Upgraded Android Gradle Plugin (AGP) from legacy versions to **8.9.1**.
  * Upgraded Gradle Wrapper to **8.11.1**.
  * Upgraded compileSdk and targetSdk versions to **36** to support the latest Android features.
* **Workmanager Fixes**: Upgraded the `workmanager` dependency to `^0.9.0` to resolve thread-local class loader errors and build warnings on modern Flutter SDKs.
* **Duplicate Classes Resolving**: Added explicit `resolutionStrategy` in `app/build.gradle` to resolve dependency duplication issues with work-runtime libraries.
* **Native Startup Hardening**: Wrapped native initialization services inside try-catch blocks in `main.dart` to prevent boot hangs if background channels fail.

---

## 📸 Camera Preview Aspect Ratio Correction

### Stretching & Distortion Resolution
* **The Issue**: On most Android and iOS devices, the camera preview stream appeared vertically stretched because the container constraints didn't match the native camera sensor aspect ratio.
* **The Fix**: 
  * Replaced manual math-based scaling factors in [camera_screen.dart](file:///c:/V/Glance/lib/features/camera/screens/camera_screen.dart).
  * Enforced a standard of wrapping `CameraPreview` inside a `SizedBox` locked to the camera sensor's display aspect ratio (`displayRatio`).
  * Placed the `SizedBox` inside a `FittedBox` configured with `BoxFit.cover`. This ensures uniform fullscreen scaling and cropping without stretching.

---

## ⚡ Database Write Timeouts & Storage Upload Robustness

### Firestore Silent Hangs Fix
* **The Issue**: In FlutterFire, when offline database persistence is enabled, if a write is blocked by rules or the database does not exist, the client SDK silent-buffers local cache writes and hangs the Future indefinitely, causing screens to freeze on loading indicators.
* **The Fix**: 
  * Replaced tight 5-8s write timeouts with defensive **15-second timeouts** on Firestore document operations (`createGroup`, `createInvite`, `createPhoto`) in [firestore_service.dart](file:///c:/V/Glance/lib/core/services/firestore_service.dart).
  * Caught `TimeoutException` in UI controllers to display user-friendly troubleshooting instructions regarding Firebase console database creation.

### Storage Upload Recovery
* **The Issue**: Uploading images on mobile cellular networks easily timed out with the initial 15-second limits.
* **The Fix**:
  * Increased upload timeouts to **60 seconds** in [storage_service.dart](file:///c:/V/Glance/lib/core/services/storage_service.dart).
  * Added error-catching in [providers.dart](file:///c:/V/Glance/lib/core/providers/providers.dart) to detect `object-not-found` or `bucket-not-found` errors (which Google Cloud Storage returns on uninitialized buckets) to tell the developer to click "Get Started" in the Storage Console.

---

## 🔒 Store Compliance & UGC Moderation (App Store Guideline 1.2 & 5.1.1)

### User-Generated Content (UGC) Consent
* **EULA Checkbox**: Integrated a mandatory EULA acceptance checkbox in the [signup_screen.dart](file:///c:/V/Glance/lib/features/auth/screens/signup_screen.dart). Users cannot register or access group sharing without accepting content guidelines.
* **Flagging & Reporting**: Added a popup dialog on feed items enabling users to instantly flag/report offensive content, saving report documents to the `reports` collection in Firestore.
* **User Blocking**: Added a "Block User" trigger that appends the target user ID to a `blockedUsers` array inside the current user's profile document. Riverpod feed providers automatically filter and hide posts from blocked users.

### Account Settings & Deletion
* **Settings & Profile screen**: Built [profile_settings_screen.dart](file:///c:/V/Glance/lib/features/profile/screens/profile_settings_screen.dart) supporting display name updates, avatar photo picking and upload, sign out, and double-confirmed account deletion.
* **Re-authentication Catching**: Added checks for `requires-recent-login` errors during account deletion, prompting users to re-authenticate if their session is stale.

---

## 📁 Offline Sync & Multi-Platform Web Compilation

### Offline SQLite Queue
* Implemented [queue_service.dart](file:///c:/V/Glance/lib/core/services/queue_service.dart) writing to a local SQLite database when cellular network drops, scheduling workmanager background sync tasks that upload cached photos once connection returns.

### Safe Web Compilation
* Created stub classes in `lib/core/utils/` (`sqflite_stub.dart`, `workmanager_stub.dart`, `permission_handler_stub.dart`, `image_compress_stub.dart`) to allow web builds (`flutter build web` or Chrome debugging) to compile without importing native-only binaries.
