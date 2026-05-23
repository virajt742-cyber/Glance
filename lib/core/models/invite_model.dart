import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum InviteStatus {
  active,
  used,
  expired;

  static InviteStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'active':
        return InviteStatus.active;
      case 'used':
        return InviteStatus.used;
      case 'expired':
        return InviteStatus.expired;
      default:
        return InviteStatus.active;
    }
  }
}

class InviteModel extends Equatable {
  final String id;
  final String inviteCode;
  final String groupId;
  final DateTime expiresAt;
  final InviteStatus status;
  final String createdBy;
  final DateTime createdAt;

  const InviteModel({
    required this.id,
    required this.inviteCode,
    required this.groupId,
    required this.expiresAt,
    this.status = InviteStatus.active,
    this.createdBy = '',
    required this.createdAt,
  });

  factory InviteModel.fromJson(Map<String, dynamic> json, {String? docId}) {
    return InviteModel(
      id: docId ?? json['id'] as String? ?? '',
      inviteCode: json['inviteCode'] as String? ?? '',
      groupId: json['groupId'] as String? ?? '',
      expiresAt: _parseTimestamp(json['expiresAt']),
      status: InviteStatus.fromString(json['status'] as String? ?? 'active'),
      createdBy: json['createdBy'] as String? ?? '',
      createdAt: _parseTimestamp(json['createdAt']),
    );
  }

  factory InviteModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return InviteModel.fromJson(data, docId: doc.id);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'inviteCode': inviteCode,
      'groupId': groupId,
      'expiresAt': Timestamp.fromDate(expiresAt),
      'status': status.name,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Map<String, dynamic> toCreateJson() {
    return {
      ...toJson(),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  bool get isActive => status == InviteStatus.active && !isExpired;

  InviteModel copyWith({
    String? id,
    String? inviteCode,
    String? groupId,
    DateTime? expiresAt,
    InviteStatus? status,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return InviteModel(
      id: id ?? this.id,
      inviteCode: inviteCode ?? this.inviteCode,
      groupId: groupId ?? this.groupId,
      expiresAt: expiresAt ?? this.expiresAt,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }

  @override
  List<Object?> get props => [id, inviteCode, groupId, expiresAt, status, createdBy, createdAt];

  @override
  String toString() =>
      'InviteModel(id: $id, code: $inviteCode, groupId: $groupId, status: ${status.name})';
}
