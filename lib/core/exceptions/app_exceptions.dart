/// Custom exception types for Glance
class GlanceException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const GlanceException(this.message, {this.code, this.originalError});

  @override
  String toString() => 'GlanceException($code): $message';
}

class AuthException extends GlanceException {
  const AuthException(super.message, {super.code, super.originalError});
}

class GroupException extends GlanceException {
  const GroupException(super.message, {super.code, super.originalError});
}

class InviteException extends GlanceException {
  const InviteException(super.message, {super.code, super.originalError});
}

class PhotoException extends GlanceException {
  const PhotoException(super.message, {super.code, super.originalError});
}

class StorageException extends GlanceException {
  const StorageException(super.message, {super.code, super.originalError});
}

// ─── Specific Invite Errors ───────────────────────────────────────────
class InviteExpiredException extends InviteException {
  const InviteExpiredException()
      : super('This invite code has expired', code: 'invite-expired');
}

class InviteAlreadyUsedException extends InviteException {
  const InviteAlreadyUsedException()
      : super('This invite code has already been used', code: 'invite-used');
}

class InviteNotFoundException extends InviteException {
  const InviteNotFoundException()
      : super('Invalid invite code', code: 'invite-not-found');
}

class AlreadyInGroupException extends InviteException {
  const AlreadyInGroupException()
      : super('You are already a member of this group', code: 'already-member');
}

class GroupFullException extends GroupException {
  const GroupFullException()
      : super('This group has reached the maximum number of members', code: 'group-full');
}
