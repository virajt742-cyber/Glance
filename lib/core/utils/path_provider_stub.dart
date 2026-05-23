/// Stub for path_provider on web.
/// All actual usage must be guarded by kIsWeb checks.

import 'package:glance_app/core/utils/io_stub.dart';

Future<Directory> getTemporaryDirectory() async => Directory('');
Future<Directory> getApplicationDocumentsDirectory() async => Directory('');
Future<Directory> getApplicationSupportDirectory() async => Directory('');
Future<Directory?> getExternalStorageDirectory() async => null;
Future<Directory?> getDownloadsDirectory() async => null;
