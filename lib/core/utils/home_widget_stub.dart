/// Stub for home_widget package on web.
/// This file is only imported when compiling for web (dart.library.html).
/// All calls should be guarded by `kIsWeb` checks anyway, but this
/// prevents compile errors from the conditional import.

class HomeWidget {
  HomeWidget._();

  static Future<bool?> saveWidgetData<T>(String id, T? data) async => null;

  static Future<bool?> updateWidget({
    String? name,
    String? iOSName,
    String? androidName,
    String? qualifiedAndroidName,
  }) async => null;

  static Future<T?> getWidgetData<T>(String id, {T? defaultValue}) async =>
      defaultValue;
}
