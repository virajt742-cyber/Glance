import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:glance_app/core/constants/app_constants.dart';
import 'package:glance_app/core/exceptions/app_exceptions.dart';
import 'package:glance_app/core/models/models.dart';

class FirestoreService {
  final FirebaseFirestore _firestore;

  FirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // ═══════════════════════════════════════════════════════════════════
  // GROUPS
  // ═══════════════════════════════════════════════════════════════════

  /// Create a new group with the current user as creator and first member
  Future<GroupModel> createGroup({
    required String name,
    required String creatorId,
  }) async {
    final docRef = _firestore.collection(AppConstants.groupsCollection).doc();
    final inviteCode = await _generateUniqueInviteCode();

    final group = GroupModel(
      id: docRef.id,
      name: name,
      creatorId: creatorId,
      inviteCode: inviteCode,
      memberIds: [creatorId],
      createdAt: DateTime.now(),
    );

    // ERROR FIX: Added a defensive 15-second timeout on docRef.set() to prevent infinite UI hangs
    // when Cloud Firestore is not created, is in Locked Mode, or rules block the write on the server.
    await docRef.set(group.toCreateJson()).timeout(const Duration(seconds: 15));
    return group;
  }

  /// Get a single group by ID
  Future<GroupModel?> getGroup(String groupId) async {
    final doc = await _firestore
        .collection(AppConstants.groupsCollection)
        .doc(groupId)
        .get();

    if (!doc.exists || doc.data() == null) return null;
    return GroupModel.fromFirestore(doc);
  }

  /// Stream a single group
  Stream<GroupModel?> groupStream(String groupId) {
    return _firestore
        .collection(AppConstants.groupsCollection)
        .doc(groupId)
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return GroupModel.fromFirestore(doc);
    });
  }

  /// Stream all groups the user is a member of
  Stream<List<GroupModel>> userGroupsStream(String userId) {
    return _firestore
        .collection(AppConstants.groupsCollection)
        .where('memberIds', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
      final groups = snapshot.docs
          .map((doc) => GroupModel.fromFirestore(doc))
          .toList();
      groups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return groups;
    });
  }

  /// Update group name
  Future<void> updateGroupName(String groupId, String newName) async {
    await _firestore
        .collection(AppConstants.groupsCollection)
        .doc(groupId)
        .update({'name': newName});
  }

  /// Add a member to a group (used by joinGroupWithCode)
  Future<void> addMemberToGroup(String groupId, String userId) async {
    final groupDoc = await _firestore
        .collection(AppConstants.groupsCollection)
        .doc(groupId)
        .get();

    if (!groupDoc.exists) {
      throw const GroupException('Group not found', code: 'group-not-found');
    }

    final group = GroupModel.fromFirestore(groupDoc);

    if (group.isMember(userId)) {
      throw const AlreadyInGroupException();
    }

    if (group.memberIds.length >= AppConstants.maxGroupMembers) {
      throw const GroupFullException();
    }

    await _firestore
        .collection(AppConstants.groupsCollection)
        .doc(groupId)
        .update({
      'memberIds': FieldValue.arrayUnion([userId]),
    });
  }

  /// Remove a member from a group
  Future<void> removeMemberFromGroup(String groupId, String userId) async {
    await _firestore
        .collection(AppConstants.groupsCollection)
        .doc(groupId)
        .update({
      'memberIds': FieldValue.arrayRemove([userId]),
    });
  }

  /// Delete a group (creator only)
  Future<void> deleteGroup(String groupId) async {
    await _firestore
        .collection(AppConstants.groupsCollection)
        .doc(groupId)
        .delete();
  }

  // ═══════════════════════════════════════════════════════════════════
  // PHOTOS
  // ═══════════════════════════════════════════════════════════════════

  /// Create a photo document
  Future<PhotoModel> createPhoto({
    required String groupId,
    required String senderId,
    required String storageUrl,
    String caption = '',
  }) async {
    final docRef = _firestore.collection(AppConstants.photosCollection).doc();

    final photo = PhotoModel(
      id: docRef.id,
      groupId: groupId,
      senderId: senderId,
      storageUrl: storageUrl,
      localTimestamp: DateTime.now(),
      caption: caption,
      reactionEmojiMap: {},
    );

    // ERROR FIX: Added a defensive 15-second timeout on docRef.set() to prevent infinite UI hangs
    // during the "Saving to database..." step when Firestore is offline, locked, or rules block the write.
    await docRef.set(photo.toCreateJson()).timeout(const Duration(seconds: 15));
    return photo;
  }

  /// Get a single photo by ID
  Future<PhotoModel?> getPhoto(String photoId) async {
    final doc = await _firestore
        .collection(AppConstants.photosCollection)
        .doc(photoId)
        .get();

    if (!doc.exists || doc.data() == null) return null;
    return PhotoModel.fromFirestore(doc);
  }

  /// Stream a single photo (for live reaction updates)
  Stream<PhotoModel?> photoStream(String photoId) {
    return _firestore
        .collection(AppConstants.photosCollection)
        .doc(photoId)
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return PhotoModel.fromFirestore(doc);
    });
  }

  /// Stream photos for a group (newest first, with pagination)
  Stream<List<PhotoModel>> groupPhotosStream(String groupId, {int limit = 20}) {
    return _firestore
        .collection(AppConstants.photosCollection)
        .where('groupId', isEqualTo: groupId)
        .orderBy('localTimestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => PhotoModel.fromFirestore(doc)).toList());
  }

  /// Paginated fetch of older photos
  Future<List<PhotoModel>> getOlderPhotos(
    String groupId, {
    required DocumentSnapshot lastDoc,
    int limit = 20,
  }) async {
    final snapshot = await _firestore
        .collection(AppConstants.photosCollection)
        .where('groupId', isEqualTo: groupId)
        .orderBy('localTimestamp', descending: true)
        .startAfterDocument(lastDoc)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) => PhotoModel.fromFirestore(doc)).toList();
  }

  /// Get the latest photo for a group (for widget display)
  Future<PhotoModel?> getLatestPhoto(String groupId) async {
    final snapshot = await _firestore
        .collection(AppConstants.photosCollection)
        .where('groupId', isEqualTo: groupId)
        .orderBy('localTimestamp', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return PhotoModel.fromFirestore(snapshot.docs.first);
  }

  /// Add or update a reaction on a photo
  Future<void> addReaction({
    required String photoId,
    required String userId,
    required String emoji,
  }) async {
    await _firestore
        .collection(AppConstants.photosCollection)
        .doc(photoId)
        .update(PhotoModel.reactionUpdate(userId, emoji));
  }

  /// Remove a reaction from a photo
  Future<void> removeReaction({
    required String photoId,
    required String userId,
  }) async {
    await _firestore
        .collection(AppConstants.photosCollection)
        .doc(photoId)
        .update(PhotoModel.reactionRemove(userId));
  }

  /// Delete a photo
  Future<void> deletePhoto(String photoId) async {
    await _firestore
        .collection(AppConstants.photosCollection)
        .doc(photoId)
        .delete();
  }

  // ═══════════════════════════════════════════════════════════════════
  // UGC MODERATION
  // ═══════════════════════════════════════════════════════════════════

  /// Report a user or specific photo
  Future<void> reportContent({
    required String reportedBy,
    required String reportedUserId,
    String? photoId,
    required String reason,
  }) async {
    await _firestore.collection('reports').add({
      'reportedBy': reportedBy,
      'reportedUserId': reportedUserId,
      'photoId': photoId,
      'reason': reason,
      'createdAt': DateTime.now(),
      'status': 'pending',
    });
  }

  /// Block a user
  Future<void> blockUser({
    required String blockerId,
    required String blockedId,
  }) async {
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(blockerId)
        .update({
      'blockedUsers': FieldValue.arrayUnion([blockedId])
    });
  }

  // ═══════════════════════════════════════════════════════════════════
  // INVITES
  // ═══════════════════════════════════════════════════════════════════

  /// Create an invite for a group
  Future<InviteModel> createInvite({
    required String groupId,
    required String createdBy,
  }) async {
    final code = await _generateUniqueInviteCode();
    final docRef = _firestore.collection(AppConstants.invitesCollection).doc();

    final invite = InviteModel(
      id: docRef.id,
      inviteCode: code,
      groupId: groupId,
      expiresAt: DateTime.now().add(
        const Duration(hours: AppConstants.inviteExpirationHours),
      ),
      status: InviteStatus.active,
      createdBy: createdBy,
      createdAt: DateTime.now(),
    );

    // ERROR FIX: Added a defensive 15-second timeout on docRef.set() to prevent infinite UI hangs
    // during the "Generate Code" step when Firestore is offline, locked, or rules block the write on the server.
    await docRef.set(invite.toCreateJson()).timeout(const Duration(seconds: 15));
    return invite;
  }

  /// Find an invite by code
  Future<InviteModel?> findInviteByCode(String code) async {
    final snapshot = await _firestore
        .collection(AppConstants.invitesCollection)
        .where('inviteCode', isEqualTo: code.toUpperCase().trim())
        .limit(1)
        .get()
        .timeout(const Duration(seconds: 15));

    if (snapshot.docs.isEmpty) return null;
    return InviteModel.fromFirestore(snapshot.docs.first);
  }

  /// Mark an invite as used
  Future<void> markInviteUsed(String inviteId) async {
    await _firestore
        .collection(AppConstants.invitesCollection)
        .doc(inviteId)
        .update({'status': 'used'});
  }

  // ═══════════════════════════════════════════════════════════════════
  // JOIN GROUP WITH CODE — Complete Flow
  // ═══════════════════════════════════════════════════════════════════

  /// Validates the invite code, adds user to group, marks invite as used.
  /// Full error handling for all edge cases.
  Future<GroupModel> joinGroupWithCode({
    required String inviteCode,
    required String userId,
  }) async {
    final code = inviteCode.toUpperCase().trim();

    if (code.length != AppConstants.inviteCodeLength) {
      throw const InviteNotFoundException();
    }

    // 1. Find the invite
    final invite = await findInviteByCode(code);
    if (invite == null) {
      throw const InviteNotFoundException();
    }

    // 2. Check if invite is already used
    if (invite.status == InviteStatus.used) {
      throw const InviteAlreadyUsedException();
    }

    // 3. Check if invite is expired
    if (invite.isExpired) {
      throw const InviteExpiredException();
    }

    // 4. Get the group
    final group = await getGroup(invite.groupId);
    if (group == null) {
      throw const GroupException('Group no longer exists', code: 'group-deleted');
    }

    // 5. Check if user is already a member
    if (group.isMember(userId)) {
      throw const AlreadyInGroupException();
    }

    // 6. Check if group is full
    if (group.memberIds.length >= AppConstants.maxGroupMembers) {
      throw const GroupFullException();
    }

    // 7. Use a batch write for atomicity
    final batch = _firestore.batch();

    // Add user to group
    batch.update(
      _firestore.collection(AppConstants.groupsCollection).doc(group.id),
      {
        'memberIds': FieldValue.arrayUnion([userId]),
      },
    );

    // Mark invite as used
    batch.update(
      _firestore.collection(AppConstants.invitesCollection).doc(invite.id),
      {'status': 'used'},
    );

    await batch.commit().timeout(const Duration(seconds: 20));

    // Return updated group
    return group.copyWith(
      memberIds: [...group.memberIds, userId],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // INVITE CODE GENERATION
  // ═══════════════════════════════════════════════════════════════════

  /// Generates a unique, human-readable 6-character alphanumeric invite code.
  /// Excludes ambiguous characters (0, O, I, l, 1) for readability.
  Future<String> _generateUniqueInviteCode() async {
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    String code;
    int attempts = 0;
    const maxAttempts = 10;

    do {
      code = List.generate(
        AppConstants.inviteCodeLength,
        (_) => chars[random.nextInt(chars.length)],
      ).join();

      attempts++;
      if (attempts > maxAttempts) {
        throw const InviteException(
          'Failed to generate unique invite code',
          code: 'code-gen-failed',
        );
      }

      // Check for uniqueness with timeout
      try {
        final existing = await findInviteByCode(code).timeout(const Duration(seconds: 4));
        if (existing == null) return code;
      } on TimeoutException {
        // If the query times out, log it and assume the code is unique.
        // With 6 chars from 31 chars (~887M combinations), conflicts are extremely rare.
        print('[FirestoreService] Timeout checking invite code uniqueness, assuming code is unique.');
        return code;
      } catch (e) {
        // Log other database verification exceptions and fallback.
        print('[FirestoreService] Error checking invite code uniqueness: $e, assuming code is unique.');
        return code;
      }
    } while (true);
  }
}
