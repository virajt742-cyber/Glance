import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:uuid/uuid.dart';

import 'package:glance_app/core/constants/app_constants.dart';
import 'package:glance_app/core/exceptions/app_exceptions.dart';

// Conditional imports for native-only packages
import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart'
    if (dart.library.html) 'package:glance_app/core/utils/image_compress_stub.dart';
import 'package:path_provider/path_provider.dart'
    if (dart.library.html) 'package:glance_app/core/utils/path_provider_stub.dart';

class StorageService {
  final FirebaseStorage _storage;
  static const _uuid = Uuid();

  StorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  Future<String> uploadGroupPhoto({
    required File imageFile,
    required String groupId,
    required String userId,
  }) async {
    try {
      final Uint8List compressed;
      if (kIsWeb) {
        // On web, skip native compression — read raw bytes
        compressed = await imageFile.readAsBytes();
      } else {
        compressed = await _compressImage(imageFile);
      }
      final fileName = '${_uuid.v4()}.jpg';
      final storagePath =
          '${AppConstants.groupPhotosPath}/$groupId/photos/$userId/$fileName';

      final ref = _storage.ref().child(storagePath);
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploadedBy': userId,
          'groupId': groupId,
        },
      );

      await ref.putData(compressed, metadata).timeout(const Duration(seconds: 60));
      return await ref.getDownloadURL().timeout(const Duration(seconds: 20));
    } on FirebaseException catch (e) {
      throw StorageException(
        'Failed to upload photo: ${e.message}',
        code: e.code,
        originalError: e,
      );
    } catch (e) {
      if (e is StorageException) rethrow;
      throw StorageException('Upload failed: $e', originalError: e);
    }
  }

  /// Upload from raw bytes — useful for web where dart:io File isn't available
  Future<String> uploadGroupPhotoFromBytes({
    required Uint8List imageBytes,
    required String groupId,
    required String userId,
  }) async {
    try {
      final fileName = '${_uuid.v4()}.jpg';
      final storagePath =
          '${AppConstants.groupPhotosPath}/$groupId/photos/$userId/$fileName';

      final ref = _storage.ref().child(storagePath);
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploadedBy': userId,
          'groupId': groupId,
        },
      );

      await ref.putData(imageBytes, metadata).timeout(const Duration(seconds: 60));
      return await ref.getDownloadURL().timeout(const Duration(seconds: 20));
    } on FirebaseException catch (e) {
      throw StorageException(
        'Failed to upload photo: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  Future<String> uploadProfilePhoto({
    required File imageFile,
    required String userId,
  }) async {
    try {
      final Uint8List compressed;
      if (kIsWeb) {
        compressed = await imageFile.readAsBytes();
      } else {
        compressed = await _compressImage(imageFile, maxWidth: 512, maxHeight: 512, initialQuality: 80);
      }
      final storagePath =
          '${AppConstants.profilePhotosPath}/$userId/profile/avatar.jpg';
      final ref = _storage.ref().child(storagePath);

      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'uploadedBy': userId, 'type': 'profile'},
      );

      await ref.putData(compressed, metadata).timeout(const Duration(seconds: 60));
      return await ref.getDownloadURL().timeout(const Duration(seconds: 20));
    } on FirebaseException catch (e) {
      throw StorageException(
        'Failed to upload profile photo: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  Future<String> uploadProfilePhotoFromBytes({
    required Uint8List imageBytes,
    required String userId,
  }) async {
    try {
      final storagePath =
          '${AppConstants.profilePhotosPath}/$userId/profile/avatar.jpg';
      final ref = _storage.ref().child(storagePath);

      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'uploadedBy': userId, 'type': 'profile'},
      );

      await ref.putData(imageBytes, metadata).timeout(const Duration(seconds: 60));
      return await ref.getDownloadURL().timeout(const Duration(seconds: 20));
    } on FirebaseException catch (e) {
      throw StorageException(
        'Failed to upload profile photo: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  Future<void> deletePhoto(String storageUrl) async {
    try {
      final ref = _storage.refFromURL(storageUrl);
      await ref.delete().timeout(const Duration(seconds: 5));
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') {
        throw StorageException(
          'Failed to delete photo: ${e.message}',
          code: e.code,
          originalError: e,
        );
      }
    }
  }

  Future<String> downloadToLocal(String url, String fileName) async {
    // On web, just return the URL — no local file system
    if (kIsWeb) return url;

    try {
      final tempDir = await getTemporaryDirectory();
      final localPath = '${tempDir.path}/$fileName';
      final file = File(localPath);

      if (await file.exists()) {
        final stat = await file.stat();
        final age = DateTime.now().difference(stat.modified);
        if (age.inMinutes < 30) return localPath;
      }

      final ref = _storage.refFromURL(url);
      await ref.writeToFile(file).timeout(const Duration(seconds: 15));
      return localPath;
    } catch (e) {
      throw StorageException('Download failed: $e', originalError: e);
    }
  }

  Future<Uint8List> _compressImage(
    File file, {
    int maxWidth = 1080,
    int maxHeight = 1080,
    int initialQuality = 75,
  }) async {
    try {
      int quality = initialQuality;
      Uint8List? result;
      
      // Dynamic compression loop to target under 200KB (204,800 bytes)
      while (quality >= 30) {
        result = await FlutterImageCompress.compressWithFile(
          file.absolute.path,
          minWidth: maxWidth,
          minHeight: maxHeight,
          quality: quality,
          format: CompressFormat.jpeg,
        ).timeout(const Duration(seconds: 4));
        
        if (result == null || result.isEmpty) {
          break; // Fallback to raw bytes below
        }
        
        if (result.lengthInBytes <= 204800) {
          return result; // Successfully under 200KB
        }
        
        quality -= 10; // Reduce quality and try again
      }
      
      if (result != null && result.isNotEmpty) {
        return result; // Best effort if still over 200KB at quality 30
      }
      
      return await file.readAsBytes();
    } catch (e) {
      return await file.readAsBytes();
    }
  }
}
