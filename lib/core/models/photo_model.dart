import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class PhotoModel extends Equatable {
  final String id;
  final String groupId;
  final String senderId;
  final String storageUrl;
  final DateTime localTimestamp;
  final String caption;
  final Map<String, String> reactionEmojiMap;

  const PhotoModel({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.storageUrl,
    required this.localTimestamp,
    this.caption = '',
    this.reactionEmojiMap = const {},
  });

  factory PhotoModel.fromJson(Map<String, dynamic> json, {String? docId}) {
    return PhotoModel(
      id: docId ?? json['id'] as String? ?? '',
      groupId: json['groupId'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      storageUrl: json['storageUrl'] as String? ?? '',
      localTimestamp: _parseTimestamp(json['localTimestamp']),
      caption: json['caption'] as String? ?? '',
      reactionEmojiMap: _parseReactionMap(json['reactionEmojiMap']),
    );
  }

  factory PhotoModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return PhotoModel.fromJson(data, docId: doc.id);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'groupId': groupId,
      'senderId': senderId,
      'storageUrl': storageUrl,
      'localTimestamp': Timestamp.fromDate(localTimestamp),
      'caption': caption,
      'reactionEmojiMap': reactionEmojiMap,
    };
  }

  Map<String, dynamic> toCreateJson() {
    return {
      ...toJson(),
      'localTimestamp': FieldValue.serverTimestamp(),
    };
  }

  /// Returns a Firestore-safe update map for adding/updating a reaction
  static Map<String, dynamic> reactionUpdate(String userId, String emoji) {
    return {
      'reactionEmojiMap.$userId': emoji,
    };
  }

  /// Returns a Firestore-safe update map for removing a reaction
  static Map<String, dynamic> reactionRemove(String userId) {
    return {
      'reactionEmojiMap.$userId': FieldValue.delete(),
    };
  }

  bool hasReactedWith(String userId) => reactionEmojiMap.containsKey(userId);

  String? getReaction(String userId) => reactionEmojiMap[userId];

  int get reactionCount => reactionEmojiMap.length;

  /// Groups reactions by emoji for display: {'🔥': 3, '❤️': 2}
  Map<String, int> get reactionCounts {
    final counts = <String, int>{};
    for (final emoji in reactionEmojiMap.values) {
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }
    return counts;
  }

  PhotoModel copyWith({
    String? id,
    String? groupId,
    String? senderId,
    String? storageUrl,
    DateTime? localTimestamp,
    String? caption,
    Map<String, String>? reactionEmojiMap,
  }) {
    return PhotoModel(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      senderId: senderId ?? this.senderId,
      storageUrl: storageUrl ?? this.storageUrl,
      localTimestamp: localTimestamp ?? this.localTimestamp,
      caption: caption ?? this.caption,
      reactionEmojiMap: reactionEmojiMap ?? this.reactionEmojiMap,
    );
  }

  static Map<String, String> _parseReactionMap(dynamic value) {
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val.toString()));
    }
    return {};
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }

  @override
  List<Object?> get props => [
        id,
        groupId,
        senderId,
        storageUrl,
        localTimestamp,
        caption,
        reactionEmojiMap,
      ];

  @override
  String toString() =>
      'PhotoModel(id: $id, groupId: $groupId, senderId: $senderId, reactions: $reactionCount)';
}
