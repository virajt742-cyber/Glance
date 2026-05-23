/// Stub for dart:io on web.
/// Provides File, Platform, and Directory stubs so code compiles on web.
/// All actual usage must be guarded by kIsWeb checks.

import 'dart:typed_data';

class File {
  final String path;
  
  File(this.path);
  
  File get absolute => this;
  
  Future<bool> exists() async => false;
  bool existsSync() => false;
  
  Future<Uint8List> readAsBytes() async => Uint8List(0);
  Uint8List readAsBytesSync() => Uint8List(0);
  
  Future<FileStat> stat() async => FileStat._();
  
  void deleteSync({bool recursive = false}) {}
  Future<void> delete({bool recursive = false}) async {}
}

class FileStat {
  FileStat._();
  final DateTime modified = DateTime.now();
}

class Directory {
  final String path;
  Directory(this.path);
  
  Future<bool> exists() async => false;
  bool existsSync() => false;
}

class Platform {
  static bool get isAndroid => false;
  static bool get isIOS => false;
  static bool get isMacOS => false;
  static bool get isWindows => false;
  static bool get isLinux => false;
  static bool get isFuchsia => false;
}
