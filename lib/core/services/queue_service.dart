import 'package:flutter/foundation.dart' show kIsWeb;

// sqflite is native-only — use conditional import
import 'package:sqflite/sqflite.dart'
    if (dart.library.html) 'package:glance_app/core/utils/sqflite_stub.dart';
import 'package:path/path.dart';

class QueueItem {
  final int? id;
  final String imagePath;
  final String groupId;
  final String caption;
  final int retryCount;
  
  QueueItem({
    this.id,
    required this.imagePath,
    required this.groupId,
    this.caption = '',
    this.retryCount = 0,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'imagePath': imagePath,
      'groupId': groupId,
      'caption': caption,
      'retryCount': retryCount,
    };
  }
  
  factory QueueItem.fromMap(Map<String, dynamic> map) {
    return QueueItem(
      id: map['id'],
      imagePath: map['imagePath'],
      groupId: map['groupId'],
      caption: map['caption'],
      retryCount: map['retryCount'],
    );
  }
}

class QueueService {
  static Database? _database;
  static const String _tableName = 'offline_queue';
  
  Future<Database> get database async {
    // sqflite is not available on web
    if (kIsWeb) throw UnsupportedError('QueueService is not supported on web');
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }
  
  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'glance_queue.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            imagePath TEXT NOT NULL,
            groupId TEXT NOT NULL,
            caption TEXT,
            retryCount INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
  }
  
  Future<void> enqueue(String imagePath, String groupId, String caption) async {
    if (kIsWeb) return; // No offline queue on web
    final db = await database;
    final item = QueueItem(imagePath: imagePath, groupId: groupId, caption: caption);
    await db.insert(_tableName, item.toMap());
  }
  
  Future<List<QueueItem>> getPendingItems() async {
    if (kIsWeb) return []; // No offline queue on web
    final db = await database;
    final maps = await db.query(_tableName, orderBy: 'id ASC');
    return List.generate(maps.length, (i) {
      return QueueItem.fromMap(maps[i]);
    });
  }
  
  Future<void> removeItem(int id) async {
    if (kIsWeb) return;
    final db = await database;
    await db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
  }
  
  Future<void> incrementRetryCount(int id) async {
    if (kIsWeb) return;
    final db = await database;
    await db.rawUpdate('UPDATE $_tableName SET retryCount = retryCount + 1 WHERE id = ?', [id]);
  }
}
