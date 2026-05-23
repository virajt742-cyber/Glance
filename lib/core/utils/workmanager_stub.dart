/// Stub for workmanager package on web.
/// This file is only imported when compiling for web (dart.library.html).

enum NetworkType { connected, unmetered, notRequired, notRoaming, metered }
enum ExistingWorkPolicy { replace, keep, append, update }

class Constraints {
  final NetworkType? networkType;
  final bool? requiresBatteryNotLow;
  final bool? requiresCharging;
  final bool? requiresDeviceIdle;
  final bool? requiresStorageNotLow;

  const Constraints({
    this.networkType,
    this.requiresBatteryNotLow,
    this.requiresCharging,
    this.requiresDeviceIdle,
    this.requiresStorageNotLow,
  });
}

class Workmanager {
  Future<void> initialize(
    Function callbackDispatcher, {
    bool isInDebugMode = false,
  }) async {}

  void registerOneOffTask(
    String uniqueName,
    String taskName, {
    String? tag,
    Duration? initialDelay,
    Constraints? constraints,
    Duration? backoffPolicyDelay,
    ExistingWorkPolicy? existingWorkPolicy,
    Map<String, dynamic>? inputData,
  }) {}

  void registerPeriodicTask(
    String uniqueName,
    String taskName, {
    Duration? frequency,
    String? tag,
    Duration? initialDelay,
    Constraints? constraints,
    ExistingWorkPolicy? existingWorkPolicy,
    Map<String, dynamic>? inputData,
  }) {}

  Future<void> cancelAll() async {}
  Future<void> cancelByTag(String tag) async {}
  Future<void> cancelByUniqueName(String uniqueName) async {}

  void executeTask(
      Future<bool> Function(String task, Map<String, dynamic>? inputData)
          backgroundTask) {}
}
