import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class GroupModel extends Equatable {
  final String id;
  final String name;
  final String creatorId;
  final String inviteCode;
  final List<String> memberIds;
  final DateTime createdAt;

  const GroupModel({
    required this.id,
    required this.name,
    required this.creatorId,
    this.inviteCode = '',
    this.memberIds = const [],
    required this.createdAt,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json, {String? docId}) {
    return GroupModel(
      id: docId ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      creatorId: json['creatorId'] as String? ?? '',
      inviteCode: json['inviteCode'] as String? ?? '',
      memberIds: _parseStringList(json['memberIds']),
      createdAt: _parseTimestamp(json['createdAt']),
    );
  }

  factory GroupModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return GroupModel.fromJson(data, docId: doc.id);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'creatorId': creatorId,
      'inviteCode': inviteCode,
      'memberIds': memberIds,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Map<String, dynamic> toCreateJson() {
    return {
      ...toJson(),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  bool isMember(String userId) => memberIds.contains(userId);

  GroupModel copyWith({
    String? id,
    String? name,
    String? creatorId,
    String? inviteCode,
    List<String>? memberIds,
    DateTime? createdAt,
  }) {
    return GroupModel(
      id: id ?? this.id,
      name: name ?? this.name,
      creatorId: creatorId ?? this.creatorId,
      inviteCode: inviteCode ?? this.inviteCode,
      memberIds: memberIds ?? this.memberIds,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static List<String> _parseStringList(dynamic value) {
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }

  @override
  List<Object?> get props => [id, name, creatorId, inviteCode, memberIds, createdAt];

  @override
  String toString() => 'GroupModel(id: $id, name: $name, members: ${memberIds.length})';
}
