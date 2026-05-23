/// Stub for flutter_image_compress on web.
/// All actual usage must be guarded by kIsWeb checks.

import 'dart:typed_data';

enum CompressFormat { jpeg, png, heic, webp }

class FlutterImageCompress {
  static Future<Uint8List?> compressWithFile(
    String path, {
    int minWidth = 1920,
    int minHeight = 1080,
    int quality = 95,
    int rotate = 0,
    bool autoCorrectionAngle = true,
    CompressFormat format = CompressFormat.jpeg,
    bool keepExif = false,
    int inSampleSize = 1,
  }) async {
    return null;
  }

  static Future<Uint8List> compressWithList(
    Uint8List image, {
    int minWidth = 1920,
    int minHeight = 1080,
    int quality = 95,
    int rotate = 0,
    bool autoCorrectionAngle = true,
    CompressFormat format = CompressFormat.jpeg,
    bool keepExif = false,
    int inSampleSize = 1,
  }) async {
    return image;
  }
}
