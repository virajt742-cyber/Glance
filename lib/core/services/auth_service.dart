import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:glance_app/core/constants/app_constants.dart';
import 'package:glance_app/core/exceptions/app_exceptions.dart';
import 'package:glance_app/core/models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  // ─── Current User ───────────────────────────────────────────────────
  User? get currentUser => _auth.currentUser;
  String? get currentUserId => _auth.currentUser?.uid;
  bool get isAuthenticated => _auth.currentUser != null;

  /// Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Stream of a user's Firestore profile by UID
  Stream<UserModel?> userProfileStreamForId(String uid) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return UserModel.fromFirestore(doc);
    });
  }

  /// Stream of the current user's Firestore profile
  Stream<UserModel?> get userProfileStream {
    final uid = currentUserId;
    if (uid == null) return Stream.value(null);
    return userProfileStreamForId(uid);
  }

  // ─── Sign Up ────────────────────────────────────────────────────────
  Future<UserModel> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      // Create Firebase Auth account
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw const AuthException('Failed to create account', code: 'null-user');
      }

      // Update display name in Firebase Auth
      await user.updateDisplayName(displayName.trim());

      // Create Firestore user document
      final userModel = UserModel(
        id: user.uid,
        displayName: displayName.trim(),
        email: email.trim(),
        profilePicUrl: '',
        pushToken: '',
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .set(userModel.toCreateJson())
          .timeout(const Duration(seconds: 20));

      return userModel;
    } on FirebaseAuthException catch (e) {
      throw AuthException(
        _mapFirebaseAuthError(e.code),
        code: e.code,
        originalError: e,
      );
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Sign up failed: ${e.toString()}', originalError: e);
    }
  }

  // ─── Sign In ────────────────────────────────────────────────────────
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw const AuthException('Failed to sign in', code: 'null-user');
      }

      // Fetch the user's Firestore profile
      final doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 20));

      if (!doc.exists || doc.data() == null) {
        // Edge case: Auth exists but Firestore doc is missing — recreate
        final userModel = UserModel(
          id: user.uid,
          displayName: user.displayName ?? 'User',
          email: email.trim(),
          profilePicUrl: user.photoURL ?? '',
          pushToken: '',
          createdAt: DateTime.now(),
        );
        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(user.uid)
            .set(userModel.toCreateJson())
            .timeout(const Duration(seconds: 20));
        return userModel;
      }

      return UserModel.fromFirestore(doc);
    } on FirebaseAuthException catch (e) {
      throw AuthException(
        _mapFirebaseAuthError(e.code),
        code: e.code,
        originalError: e,
      );
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Sign in failed: ${e.toString()}', originalError: e);
    }
  }

  // ─── Sign Out ───────────────────────────────────────────────────────
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw AuthException('Sign out failed: ${e.toString()}', originalError: e);
    }
  }

  // ─── Ensure User Profile Exists ────────────────────────────────────
  /// Checks if the user's Firestore profile exists; creates it if missing.
  /// Resilient to brief offline states on Web.
  Future<UserModel> ensureUserProfileExists(User firebaseUser) async {
    final docRef = _firestore
        .collection(AppConstants.usersCollection)
        .doc(firebaseUser.uid);

    try {
      final doc = await docRef.get().timeout(const Duration(seconds: 20));
      if (doc.exists && doc.data() != null) {
        return UserModel.fromFirestore(doc);
      }
      // Doc doesn't exist — create it
      return await _createUserProfile(docRef, firebaseUser);
    } catch (e) {
      // .get() failed (offline/timeout) — try to create the profile anyway.
      // If it already exists, Firestore SDK buffers the write and the
      // realtime stream (userProfileStreamForId) will pick up the existing doc.
      try {
        return await _createUserProfile(docRef, firebaseUser);
      } catch (_) {
        // Both read and write failed — return a local-only model.
        // The realtime stream will hydrate once connectivity resumes.
        return UserModel(
          id: firebaseUser.uid,
          displayName: firebaseUser.displayName ?? 'User',
          email: firebaseUser.email ?? '',
          profilePicUrl: firebaseUser.photoURL ?? '',
          pushToken: '',
          createdAt: DateTime.now(),
        );
      }
    }
  }

  Future<UserModel> _createUserProfile(
    DocumentReference<Map<String, dynamic>> docRef,
    User firebaseUser,
  ) async {
    final userModel = UserModel(
      id: firebaseUser.uid,
      displayName: firebaseUser.displayName ?? 'User',
      email: firebaseUser.email ?? '',
      profilePicUrl: firebaseUser.photoURL ?? '',
      pushToken: '',
      createdAt: DateTime.now(),
    );
    await docRef.set(userModel.toCreateJson()).timeout(const Duration(seconds: 20));
    return userModel;
  }

  // ─── Update Push Token ─────────────────────────────────────────────
  Future<void> updatePushToken(String token) async {
    final uid = currentUserId;
    if (uid == null) return;

    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .update({'pushToken': token});
  }

  // ─── Update Profile ────────────────────────────────────────────────
  Future<void> updateProfile({
    String? displayName,
    String? profilePicUrl,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw const AuthException('Not authenticated');

    final updates = <String, dynamic>{};
    if (displayName != null) updates['displayName'] = displayName.trim();
    if (profilePicUrl != null) updates['profilePicUrl'] = profilePicUrl;

    if (updates.isNotEmpty) {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .update(updates);
    }

    if (displayName != null) {
      await _auth.currentUser?.updateDisplayName(displayName.trim());
    }
  }

  // ─── Get User By ID ────────────────────────────────────────────────
  Future<UserModel?> getUserById(String userId) async {
    final doc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .get();

    if (!doc.exists || doc.data() == null) return null;
    return UserModel.fromFirestore(doc);
  }

  // ─── Get Multiple Users ─────────────────────────────────────────────
  Future<List<UserModel>> getUsersByIds(List<String> userIds) async {
    if (userIds.isEmpty) return [];

    // Firestore whereIn supports max 30 items per query
    final results = <UserModel>[];
    final chunks = <List<String>>[];

    for (var i = 0; i < userIds.length; i += 30) {
      chunks.add(userIds.sublist(i, i + 30 > userIds.length ? userIds.length : i + 30));
    }

    for (final chunk in chunks) {
      final snapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      results.addAll(
        snapshot.docs.map((doc) => UserModel.fromFirestore(doc)),
      );
    }

    return results;
  }

  // ─── Delete Account ────────────────────────────────────────────────
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthException('Not authenticated');
    final uid = user.uid;

    try {
      // 1. Delete Firestore user document
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .delete()
          .timeout(const Duration(seconds: 15));

      // 2. Delete Firebase Auth user
      await user.delete();
    } on FirebaseAuthException catch (e) {
      throw AuthException(
        _mapFirebaseAuthError(e.code),
        code: e.code,
        originalError: e,
      );
    } catch (e) {
      throw AuthException('Failed to delete account: ${e.toString()}', originalError: e);
    }
  }

  // ─── Password Reset ────────────────────────────────────────────────
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(
        _mapFirebaseAuthError(e.code),
        code: e.code,
        originalError: e,
      );
    }
  }

  // ─── Error Mapping ─────────────────────────────────────────────────
  String _mapFirebaseAuthError(String code) {
    switch (code) {
      case 'requires-recent-login':
        return 'For security reasons, this action requires you to log out and log back in before deleting your account.';
      case 'email-already-in-use':
        return 'An account with this email already exists';
      case 'invalid-email':
        return 'Please enter a valid email address';
      case 'weak-password':
        return 'Password must be at least 6 characters';
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      case 'operation-not-allowed':
      case 'configuration-not-found':
        return 'Email/Password sign-in is not enabled in Firebase Console';
      case 'invalid-credential':
        return 'Invalid email or password';
      default:
        return 'Authentication failed. Please try again';
    }
  }
}
