/// App-wide constants for Glance
class AppConstants {
  AppConstants._();

  // ─── App Info ───────────────────────────────────────────────────────
  static const String appName = 'Glance';
  static const String appTagline = 'Share moments instantly';
  static const String appBundleId = 'com.glance.app';
  static const String appGroupId = 'group.com.glance.app';

  // ─── Firebase Collections ───────────────────────────────────────────
  static const String usersCollection = 'users';
  static const String groupsCollection = 'groups';
  static const String photosCollection = 'photos';
  static const String invitesCollection = 'invites';

  // ─── Storage Paths ──────────────────────────────────────────────────
  static const String profilePhotosPath = 'users';
  static const String groupPhotosPath = 'groups';

  // ─── Invite ─────────────────────────────────────────────────────────
  static const int inviteCodeLength = 6;
  static const int inviteExpirationHours = 48;
  static const int maxGroupMembers = 50;

  // ─── Photo ──────────────────────────────────────────────────────────
  static const int maxPhotoWidth = 1080;
  static const int maxPhotoHeight = 1080;
  static const int photoQuality = 85;
  static const int maxCaptionLength = 500;
  static const int photosPageSize = 20;

  // ─── Reactions ──────────────────────────────────────────────────────
  static const List<String> reactionEmojis = ['👍', '🔥', '❤️', '😂', '😮'];

  // ─── Widget ─────────────────────────────────────────────────────────
  static const String widgetKindHome = 'GlanceHomeWidget';
  static const String widgetKeyPhotoUrl = 'glance_photo_url';
  static const String widgetKeySenderName = 'glance_sender_name';
  static const String widgetKeyTimestamp = 'glance_timestamp';
  static const String widgetKeyGroupId = 'glance_group_id';
  static const String widgetKeyPhotoLocalPath = 'glance_photo_local_path';
  static const String widgetKeyPhotoId = 'glance_photo_id';

  // ─── FCM ────────────────────────────────────────────────────────────
  static const String fcmTypeNewPhoto = 'new_photo';
  static const String fcmTypeGroupInvite = 'group_invite';
  static const String fcmTypeReaction = 'reaction';
}
