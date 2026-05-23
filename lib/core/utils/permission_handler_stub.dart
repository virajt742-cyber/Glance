/// Stub for permission_handler package on web.
/// On web, the browser handles permissions natively (camera, microphone, etc.)
/// All actual usage must be guarded by kIsWeb checks.

enum PermissionStatus { denied, granted, restricted, limited, permanentlyDenied, provisional }

extension PermissionStatusX on PermissionStatus {
  bool get isGranted => this == PermissionStatus.granted;
  bool get isDenied => this == PermissionStatus.denied;
  bool get isRestricted => this == PermissionStatus.restricted;
  bool get isLimited => this == PermissionStatus.limited;
  bool get isPermanentlyDenied => this == PermissionStatus.permanentlyDenied;
}

class Permission {
  static const Permission camera = Permission._('camera');
  static const Permission microphone = Permission._('microphone');
  static const Permission photos = Permission._('photos');
  static const Permission storage = Permission._('storage');
  static const Permission notification = Permission._('notification');
  
  final String _name;
  const Permission._(this._name);
  
  Future<PermissionStatus> request() async => PermissionStatus.granted;
  Future<PermissionStatus> get status async => PermissionStatus.granted;
}

Future<void> openAppSettings() async {}
