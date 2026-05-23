import 'package:flutter/foundation.dart';

// Standard import - web compiler allows it now
import 'dart:io';

import 'package:glance_app/core/services/queue_service.dart';
import 'package:glance_app/core/services/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Import workmanager only on native
import 'package:workmanager/workmanager.dart'
    if (dart.library.html) 'package:glance_app/core/utils/workmanager_stub.dart';

const String _offlineUploadTask = 'offlineUploadTask';

@pragma('vm:entry-point')
void callbackDispatcher() {
  if (kIsWeb) return; // Should never be called on web, but guard anyway

  Workmanager().executeTask((task, inputData) async {
    if (task == _offlineUploadTask) {
      try {
        await Firebase.initializeApp();
        final auth = FirebaseAuth.instance;
        if (auth.currentUser == null) return true; // Can't upload without auth
        
        final queueService = QueueService();
        final storageService = StorageService();
        final firestoreService = FirestoreService();
        final fcmService = FCMService();
        
        final pendingItems = await queueService.getPendingItems();
        
        for (final item in pendingItems) {
          try {
            final file = File(item.imagePath);
            if (!file.existsSync()) {
              await queueService.removeItem(item.id!);
              continue;
            }
            
            final downloadUrl = await storageService.uploadGroupPhoto(
              imageFile: file,
              groupId: item.groupId,
              userId: auth.currentUser!.uid,
            );
            
            final photoModel = await firestoreService.createPhoto(
              groupId: item.groupId,
              senderId: auth.currentUser!.uid,
              storageUrl: downloadUrl,
              caption: item.caption,
            );
            
            await fcmService.saveLatestPhotoForWidget(
              photoUrl: downloadUrl,
              senderName: auth.currentUser!.displayName ?? 'Someone',
              groupId: item.groupId,
              photoId: photoModel.id,
            );
            
            // Cleanup on success
            await queueService.removeItem(item.id!);
            if (file.existsSync()) {
              file.deleteSync();
            }
          } catch (e) {
            await queueService.incrementRetryCount(item.id!);
            if (item.retryCount > 3) {
              await queueService.removeItem(item.id!); // Drop after 3 retries
            }
          }
        }
      } catch (err) {
        if (kDebugMode) print('Background task error: $err');
      }
    }
    return true;
  });
}

class BackgroundService {
  static Future<void> initialize() async {
    // Workmanager is native-only
    if (kIsWeb) return;

    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: kDebugMode,
    );
  }

  static void scheduleOfflineUpload() {
    // Workmanager is native-only
    if (kIsWeb) return;

    Workmanager().registerOneOffTask(
      'offline_upload_${DateTime.now().millisecondsSinceEpoch}',
      _offlineUploadTask,
      constraints: Constraints(
        networkType: NetworkType.connected, // Only run when connected
      ),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }
}
