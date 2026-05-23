import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

// ignore: avoid_classes_with_only_static_members
/// Safe platform checks that don't crash on web.
///
/// `dart:io` `Platform` throws `UnsupportedError` on web,
/// so always check [isWeb] first or use these helpers.
class PlatformUtils {
  PlatformUtils._();

  static bool get isWeb => kIsWeb;

  static bool get isAndroid {
    if (kIsWeb) return false;
    return _platform == 'android';
  }

  static bool get isIOS {
    if (kIsWeb) return false;
    return _platform == 'ios';
  }

  static bool get isMobile => isAndroid || isIOS;

  /// Cached platform string to avoid repeated dart:io imports at call-sites.
  static final String _platform = _detectPlatform();

  static String _detectPlatform() {
    if (kIsWeb) return 'web';
    try {
      // Dynamic import to avoid dart:io compile issue on web
      // ignore: uri_does_not_exist
      return _getPlatformString();
    } catch (_) {
      return 'unknown';
    }
  }
}

/// Separated so dart:io is only imported here.
String _getPlatformString() {
  // This file can import dart:io because it's only called when !kIsWeb
  // The import is at the top of the file — see platform_utils_io.dart
  // For simplicity, we use defaultTargetPlatform from Flutter instead.
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    TargetPlatform.macOS => 'macos',
    TargetPlatform.windows => 'windows',
    TargetPlatform.linux => 'linux',
    TargetPlatform.fuchsia => 'fuchsia',
  };
}
