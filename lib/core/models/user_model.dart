import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final String id;
  final String displayName;
  final String email;
  final String profilePicUrl;
  final String pushToken;
  final DateTime createdAt;
  final List<String> blockedUsers;

  const UserModel({
    required this.id,
    required this.displayName,
    required this.email,
    this.profilePicUrl = '',
    this.pushToken = '',
    required this.createdAt,
    this.blockedUsers = const [],
  });

  factory UserModel.fromJson(Map<String, dynamic> json, {String? docId}) {
    return UserModel(
      id: docId ?? json['id'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      profilePicUrl: json['profilePicUrl'] as String? ?? '',
      pushToken: json['pushToken'] as String? ?? '',
      createdAt: _parseTimestamp(json['createdAt']),
      blockedUsers: (json['blockedUsers'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }

  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return UserModel.fromJson(data, docId: doc.id);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'email': email,
      'profilePicUrl': profilePicUrl,
      'pushToken': pushToken,
      'createdAt': Timestamp.fromDate(createdAt),
      'blockedUsers': blockedUsers,
    };
  }

  Map<String, dynamic> toCreateJson() {
    return {
      ...toJson(),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  UserModel copyWith({
    String? id,
    String? displayName,
    String? email,
    String? profilePicUrl,
    String? pushToken,
    DateTime? createdAt,
    List<String>? blockedUsers,
  }) {
    return UserModel(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      profilePicUrl: profilePicUrl ?? this.profilePicUrl,
      pushToken: pushToken ?? this.pushToken,
      createdAt: createdAt ?? this.createdAt,
      blockedUsers: blockedUsers ?? this.blockedUsers,
    );
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }

  @override
  List<Object?> get props => [id, displayName, email, profilePicUrl, pushToken, createdAt, blockedUsers];

  @override
  String toString() => 'UserModel(id: $id, displayName: $displayName, email: $email, blockedUsers: $blockedUsers)';
}
