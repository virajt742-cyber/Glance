import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart'; // For AppLifecycleState
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:glance_app/core/models/models.dart';
import 'package:glance_app/core/services/services.dart';
import 'package:glance_app/core/services/queue_service.dart';
import 'package:glance_app/core/services/background_service.dart';

// ═══════════════════════════════════════════════════════════════════════
// SERVICE PROVIDERS (singletons)
// ═══════════════════════════════════════════════════════════════════════

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final firestoreServiceProvider = Provider<FirestoreService>((ref) => FirestoreService());
final storageServiceProvider = Provider<StorageService>((ref) => StorageService());
final fcmServiceProvider = Provider<FCMService>((ref) => FCMService());

// ═══════════════════════════════════════════════════════════════════════
// AUTH STATE
// ═══════════════════════════════════════════════════════════════════════

/// Stream provider for Firebase Auth state changes
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges.handleError((err, stack) {
    debugPrint('[Providers] Error in authStateProvider stream: $err\n$stack');
  }).map((user) {
    debugPrint('[Providers] authStateProvider emitted user: ${user?.uid}');
    return user;
  });
});

/// Stream provider for the current user's Firestore profile
final currentUserProfileProvider = StreamProvider<UserModel?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  debugPrint('[Providers] currentUserProfileProvider watched userId: $userId');
  if (userId == null) {
    debugPrint('[Providers] currentUserProfileProvider: userId is null, emitting null profile');
    return Stream.value(null);
  }

  final authService = ref.watch(authServiceProvider);
  final firebaseUser = authService.currentUser;
  if (firebaseUser != null) {
    authService.ensureUserProfileExists(firebaseUser).catchError((e) {
      debugPrint('[Providers] Error ensuring user profile exists: $e');
      return UserModel(
        id: firebaseUser.uid,
        displayName: firebaseUser.displayName ?? 'User',
        email: firebaseUser.email ?? '',
        createdAt: DateTime.now(),
      );
    });
  }

  return authService.userProfileStreamForId(userId).handleError((err, stack) {
    debugPrint('[Providers] Error in currentUserProfileProvider stream: $err\n$stack');
  }).map((profile) {
    debugPrint('[Providers] currentUserProfileProvider emitted profile: ${profile?.displayName} (id: ${profile?.id})');
    return profile;
  });
});

/// Simple provider for current user ID
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).value?.uid;
});

// ═══════════════════════════════════════════════════════════════════════
// ACTIVE GROUP
// ═══════════════════════════════════════════════════════════════════════

/// State notifier for the currently selected group ID
final activeGroupIdProvider = StateProvider<String?>((ref) => null);

/// Stream of all groups the current user belongs to
final userGroupsProvider = StreamProvider<List<GroupModel>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  debugPrint('[Providers] userGroupsProvider userId watch: $userId');
  if (userId == null) {
    debugPrint('[Providers] userGroupsProvider returning empty stream (userId is null)');
    return Stream.value([]);
  }
  return ref.watch(firestoreServiceProvider).userGroupsStream(userId).handleError((err, stack) {
    debugPrint('[Providers] Error in userGroupsProvider stream: $err\n$stack');
  }).map((groups) {
    debugPrint('[Providers] userGroupsProvider emitted ${groups.length} groups');
    return groups;
  });
});

/// Stream of the active group details
final activeGroupProvider = StreamProvider<GroupModel?>((ref) {
  final groupId = ref.watch(activeGroupIdProvider);
  if (groupId == null) return Stream.value(null);
  return ref.watch(firestoreServiceProvider).groupStream(groupId);
});

/// Members of the active group (fetched as UserModels)
final activeGroupMembersProvider = FutureProvider<List<UserModel>>((ref) async {
  final group = ref.watch(activeGroupProvider).value;
  if (group == null) return [];
  return ref.watch(authServiceProvider).getUsersByIds(group.memberIds);
});

// ═══════════════════════════════════════════════════════════════════════
// LIFECYCLE STATE
// ═══════════════════════════════════════════════════════════════════════

final appLifecycleStateProvider = StateProvider<AppLifecycleState>((ref) => AppLifecycleState.resumed);

// ═══════════════════════════════════════════════════════════════════════
// PHOTOS
// ═══════════════════════════════════════════════════════════════════════

/// Stream of photos for the active group
final activeGroupPhotosProvider = StreamProvider<List<PhotoModel>>((ref) {
  final groupId = ref.watch(activeGroupIdProvider);
  final lifecycle = ref.watch(appLifecycleStateProvider);
  
  if (groupId == null || lifecycle == AppLifecycleState.paused || lifecycle == AppLifecycleState.detached) {
    return Stream.value([]); // Pause stream if backgrounded
  }
  
  final photosStream = ref.watch(firestoreServiceProvider).groupPhotosStream(groupId);
  final userProfileAsync = ref.watch(currentUserProfileProvider);
  
  return photosStream.map((photos) {
    final blockedUsers = userProfileAsync.value?.blockedUsers ?? [];
    if (blockedUsers.isEmpty) return photos;
    return photos.where((photo) => !blockedUsers.contains(photo.senderId)).toList();
  });
});

/// Stream a single photo (for real-time reaction updates)
final photoStreamProvider =
    StreamProvider.family<PhotoModel?, String>((ref, photoId) {
  final lifecycle = ref.watch(appLifecycleStateProvider);
  if (lifecycle == AppLifecycleState.paused || lifecycle == AppLifecycleState.detached) {
    return Stream.value(null);
  }
  return ref.watch(firestoreServiceProvider).photoStream(photoId);
});

/// Latest photo in the active group (for widget display)
final latestPhotoProvider = StreamProvider<PhotoModel?>((ref) {
  final groupId = ref.watch(activeGroupIdProvider);
  if (groupId == null) return Stream.value(null);
  
  final photosStream = ref.watch(firestoreServiceProvider).groupPhotosStream(groupId, limit: 10);
  final userProfileAsync = ref.watch(currentUserProfileProvider);
  
  return photosStream.map((photos) {
    final blockedUsers = userProfileAsync.value?.blockedUsers ?? [];
    if (photos.isEmpty) return null;
    if (blockedUsers.isEmpty) return photos.first;
    
    for (final photo in photos) {
      if (!blockedUsers.contains(photo.senderId)) {
        return photo;
      }
    }
    return null;
  });
});

// ═══════════════════════════════════════════════════════════════════════
// UPLOAD STATE
// ═══════════════════════════════════════════════════════════════════════

enum UploadStatus { idle, compressing, uploading, saving, notifying, done, error }

class UploadState {
  final UploadStatus status;
  final double progress;
  final String? errorMessage;

  const UploadState({
    this.status = UploadStatus.idle,
    this.progress = 0.0,
    this.errorMessage,
  });

  UploadState copyWith({
    UploadStatus? status,
    double? progress,
    String? errorMessage,
  }) {
    return UploadState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  bool get isUploading =>
      status == UploadStatus.compressing ||
      status == UploadStatus.uploading ||
      status == UploadStatus.saving ||
      status == UploadStatus.notifying;
}

class UploadNotifier extends StateNotifier<UploadState> {
  final Ref _ref;

  UploadNotifier(this._ref) : super(const UploadState());

  Future<bool> uploadPhoto({
    required String imagePath,
    required String groupId,
    String caption = '',
  }) async {
    final userId = _ref.read(currentUserIdProvider);
    final userProfile = _ref.read(currentUserProfileProvider).value;
    if (userId == null) return false;

    try {
      // Step 1: Compress
      state = state.copyWith(status: UploadStatus.compressing, progress: 0.1);

      // Step 2: Upload to Storage
      state = state.copyWith(status: UploadStatus.uploading, progress: 0.3);

      final storageService = _ref.read(storageServiceProvider);
      final String downloadUrl;

      if (kIsWeb) {
        final xFile = XFile(imagePath);
        final bytes = await xFile.readAsBytes();
        downloadUrl = await storageService.uploadGroupPhotoFromBytes(
          imageBytes: bytes,
          groupId: groupId,
          userId: userId,
        );
      } else {
        final imageFile = File(imagePath);
        downloadUrl = await storageService.uploadGroupPhoto(
          imageFile: imageFile,
          groupId: groupId,
          userId: userId,
        );
      }

      // Step 3: Create Firestore document
      state = state.copyWith(status: UploadStatus.saving, progress: 0.7);

      final firestoreService = _ref.read(firestoreServiceProvider);
      final photoModel = await firestoreService.createPhoto(
        groupId: groupId,
        senderId: userId,
        storageUrl: downloadUrl,
        caption: caption,
      );

      // Step 4: Update native widget with latest photo
      state = state.copyWith(status: UploadStatus.notifying, progress: 0.9);

      final fcmService = _ref.read(fcmServiceProvider);
      await fcmService.saveLatestPhotoForWidget(
        photoUrl: downloadUrl,
        senderName: userProfile?.displayName ?? 'Someone',
        groupId: groupId,
        photoId: photoModel.id,
      );

      state = state.copyWith(status: UploadStatus.done, progress: 1.0);
      return true;
    } catch (e) {
      final isTimeout = e is TimeoutException || e.toString().contains('TimeoutException');
      // ERROR FIX: Catching "object-not-found" or "bucket-not-found" (which GCS returns as 404/not found)
      // to let the user know their Storage bucket hasn't been created/enabled in the Firebase Console yet.
      final isObjectNotFound = e.toString().contains('object-not-found') || 
                               e.toString().contains('ObjectNotFound') ||
                               e.toString().contains('bucket-not-found');
      
      if (isObjectNotFound) {
        state = state.copyWith(
          status: UploadStatus.error,
          errorMessage: 'Firebase Storage bucket not found. Please ensure you have created and enabled Firebase Storage in your Firebase Console (Build > Storage).',
        );
        return false;
      }

      final isNetworkError = e.toString().contains('network_error') || 
                             e.toString().contains('offline') || 
                             e.toString().contains('SocketException') ||
                             e.toString().contains('network-request-failed') ||
                             isTimeout;
                             
      if (isNetworkError && !kIsWeb) {
        // Offline queue is native-only (sqflite + workmanager)
        try {
          final queueService = QueueService();
          await queueService.enqueue(imagePath, groupId, caption);
          BackgroundService.scheduleOfflineUpload();
          
          state = state.copyWith(
            status: UploadStatus.error,
            errorMessage: isTimeout
                ? 'Upload timed out. Photo queued for upload.'
                : 'Offline. Photo queued for upload.',
          );
          return true; // We consider queuing a temporary success for UX
        } catch (queueErr) {
          state = state.copyWith(
            status: UploadStatus.error,
            errorMessage: 'Failed to queue offline upload.',
          );
          return false;
        }
      } else if (isNetworkError && kIsWeb) {
        state = state.copyWith(
          status: UploadStatus.error,
          errorMessage: isTimeout
              ? 'Upload timed out. Please check your connection or verify Firebase Storage CORS configuration.'
              : 'Network error. Please verify Firebase Storage CORS configuration.',
        );
        return false;
      }
      
      state = state.copyWith(
        status: UploadStatus.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  void reset() {
    state = const UploadState();
  }
}



final uploadProvider =
    StateNotifierProvider<UploadNotifier, UploadState>((ref) {
  return UploadNotifier(ref);
});

// ═══════════════════════════════════════════════════════════════════════
// JOIN GROUP
// ═══════════════════════════════════════════════════════════════════════

final joinGroupProvider = FutureProvider.family<GroupModel, String>(
  (ref, inviteCode) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) throw Exception('Not authenticated');

    final firestoreService = ref.read(firestoreServiceProvider);
    return firestoreService.joinGroupWithCode(
      inviteCode: inviteCode,
      userId: userId,
    );
  },
);

// ═══════════════════════════════════════════════════════════════════════
// HOME SCREEN PAGE INDEX
// ═══════════════════════════════════════════════════════════════════════

/// State provider for the home screen current page index (0: Groups, 1: Camera, 2: Feed)
final homePageIndexProvider = StateProvider<int>((ref) => 1);

