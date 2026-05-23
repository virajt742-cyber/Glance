import * as admin from "firebase-admin";
import * as functions from "firebase-functions";

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

// ═══════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════

const INVITE_CODE_LENGTH = 6;
const INVITE_CODE_CHARS = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
const INVITE_EXPIRATION_HOURS = 48;
const MAX_GROUP_MEMBERS = 50;

// ═══════════════════════════════════════════════════════════════════════
// INTERFACES
// ═══════════════════════════════════════════════════════════════════════

interface UserDoc {
  id: string;
  displayName: string;
  email: string;
  profilePicUrl: string;
  pushToken: string;
  createdAt: admin.firestore.Timestamp;
}

interface GroupDoc {
  id: string;
  name: string;
  creatorId: string;
  inviteCode: string;
  memberIds: string[];
  createdAt: admin.firestore.Timestamp;
}

interface PhotoDoc {
  id: string;
  groupId: string;
  senderId: string;
  storageUrl: string;
  localTimestamp: admin.firestore.Timestamp;
  caption: string;
  reactionEmojiMap: Record<string, string>;
}

interface InviteDoc {
  id: string;
  inviteCode: string;
  groupId: string;
  expiresAt: admin.firestore.Timestamp;
  status: "active" | "used" | "expired";
  createdBy: string;
  createdAt: admin.firestore.Timestamp;
}

// ═══════════════════════════════════════════════════════════════════════
// HELPER: Generate Unique Invite Code
// ═══════════════════════════════════════════════════════════════════════

async function generateUniqueInviteCode(): Promise<string> {
  let attempts = 0;
  const maxAttempts = 10;

  while (attempts < maxAttempts) {
    let code = "";
    for (let i = 0; i < INVITE_CODE_LENGTH; i++) {
      const randomIndex = Math.floor(Math.random() * INVITE_CODE_CHARS.length);
      code += INVITE_CODE_CHARS[randomIndex];
    }

    // Verify uniqueness against existing active invites
    const existing = await db
      .collection("invites")
      .where("inviteCode", "==", code)
      .where("status", "==", "active")
      .limit(1)
      .get();

    if (existing.empty) {
      return code;
    }

    attempts++;
  }

  throw new functions.https.HttpsError(
    "internal",
    "Failed to generate unique invite code after maximum attempts"
  );
}

// ═══════════════════════════════════════════════════════════════════════
// CLOUD FUNCTION: Create Group Invite
// ═══════════════════════════════════════════════════════════════════════

export const createGroupInvite = functions.https.onCall(
  async (request) => {
    // 1. Auth check
    if (!request.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Must be authenticated to create an invite"
      );
    }

    const { groupId } = request.data as { groupId: string };
    if (!groupId || typeof groupId !== "string") {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "groupId is required"
      );
    }

    const userId = request.auth.uid;

    // 2. Verify user is a member of the group
    const groupDoc = await db.collection("groups").doc(groupId).get();
    if (!groupDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Group not found");
    }

    const group = groupDoc.data() as GroupDoc;
    if (!group.memberIds.includes(userId)) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "You are not a member of this group"
      );
    }

    // 3. Generate unique code
    const inviteCode = await generateUniqueInviteCode();

    // 4. Create invite document
    const inviteRef = db.collection("invites").doc();
    const invite: InviteDoc = {
      id: inviteRef.id,
      inviteCode,
      groupId,
      expiresAt: admin.firestore.Timestamp.fromDate(
        new Date(Date.now() + INVITE_EXPIRATION_HOURS * 60 * 60 * 1000)
      ),
      status: "active",
      createdBy: userId,
      createdAt: admin.firestore.Timestamp.now(),
    };

    await inviteRef.set(invite);

    return { inviteCode, expiresAt: invite.expiresAt.toDate().toISOString() };
  }
);

// ═══════════════════════════════════════════════════════════════════════
// CLOUD FUNCTION: Join Group With Code
// ═══════════════════════════════════════════════════════════════════════

export const joinGroupWithCode = functions.https.onCall(
  async (request) => {
    // 1. Auth check
    if (!request.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Must be authenticated to join a group"
      );
    }

    const { inviteCode } = request.data as { inviteCode: string };
    if (!inviteCode || typeof inviteCode !== "string") {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "inviteCode is required"
      );
    }

    const userId = request.auth.uid;
    const code = inviteCode.toUpperCase().trim();

    if (code.length !== INVITE_CODE_LENGTH) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Invalid invite code format"
      );
    }

    // 2. Find the invite
    const inviteSnap = await db
      .collection("invites")
      .where("inviteCode", "==", code)
      .limit(1)
      .get();

    if (inviteSnap.empty) {
      throw new functions.https.HttpsError(
        "not-found",
        "Invalid invite code"
      );
    }

    const inviteDoc = inviteSnap.docs[0];
    const invite = inviteDoc.data() as InviteDoc;

    // 3. Check if already used
    if (invite.status === "used") {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "This invite code has already been used"
      );
    }

    // 4. Check expiration
    if (invite.expiresAt.toDate() < new Date()) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "This invite code has expired"
      );
    }

    // 5. Get the group
    const groupDoc = await db.collection("groups").doc(invite.groupId).get();
    if (!groupDoc.exists) {
      throw new functions.https.HttpsError(
        "not-found",
        "Group no longer exists"
      );
    }

    const group = groupDoc.data() as GroupDoc;

    // 6. Check if already a member
    if (group.memberIds.includes(userId)) {
      throw new functions.https.HttpsError(
        "already-exists",
        "You are already a member of this group"
      );
    }

    // 7. Check group capacity
    if (group.memberIds.length >= MAX_GROUP_MEMBERS) {
      throw new functions.https.HttpsError(
        "resource-exhausted",
        "This group has reached the maximum number of members"
      );
    }

    // 8. Atomic batch: add member + mark invite used
    const batch = db.batch();

    batch.update(db.collection("groups").doc(invite.groupId), {
      memberIds: admin.firestore.FieldValue.arrayUnion([userId]),
    });

    batch.update(inviteDoc.ref, { status: "used" });

    await batch.commit();

    return {
      groupId: invite.groupId,
      groupName: group.name,
      message: `Successfully joined "${group.name}"`,
    };
  }
);

// ═══════════════════════════════════════════════════════════════════════
// CLOUD FUNCTION: On Photo Created — Send FCM to Group Members
// ═══════════════════════════════════════════════════════════════════════

export const onPhotoCreated = functions.firestore
  .document("photos/{photoId}")
  .onCreate(async (snapshot, context) => {
    const photo = snapshot.data() as PhotoDoc;
    const { groupId, senderId, storageUrl, caption } = photo;

    // 1. Get the group to find member IDs
    const groupDoc = await db.collection("groups").doc(groupId).get();
    if (!groupDoc.exists) return;

    const group = groupDoc.data() as GroupDoc;

    // 2. Get sender info
    const senderDoc = await db.collection("users").doc(senderId).get();
    const sender = senderDoc.data() as UserDoc | undefined;
    const senderName = sender?.displayName ?? "Someone";

    // 3. Collect push tokens of all members except sender
    const otherMembers = group.memberIds.filter((id) => id !== senderId);
    if (otherMembers.length === 0) return;

    // Fetch tokens in batches of 30 (Firestore whereIn limit)
    const tokens: string[] = [];
    for (let i = 0; i < otherMembers.length; i += 30) {
      const chunk = otherMembers.slice(i, i + 30);
      const usersSnap = await db
        .collection("users")
        .where(admin.firestore.FieldPath.documentId(), "in", chunk)
        .get();

      usersSnap.docs.forEach((doc) => {
        const user = doc.data() as UserDoc;
        if (user.pushToken && user.pushToken.length > 0) {
          tokens.push(user.pushToken);
        }
      });
    }

    if (tokens.length === 0) return;

    // 4. Build the silent data payload for widget updates
    const dataPayload: Record<string, string> = {
      type: "new_photo",
      photoId: context.params.photoId,
      photoUrl: storageUrl,
      senderName: senderName,
      senderId: senderId,
      groupId: groupId,
      groupName: group.name,
      timestamp: new Date().toISOString(),
      caption: caption || "",
    };

    // 5. Send to each token using the v1 API
    const messages: admin.messaging.Message[] = tokens.map((token) => ({
      token,
      data: dataPayload,
      android: {
        priority: "high" as const,
        ttl: 86400 * 1000, // 24 hours in milliseconds
        restrictedPackageName: "com.glance.app",
      },
      apns: {
        headers: {
          "apns-priority": "5",
          "apns-push-type": "background",
        },
        payload: {
          aps: {
            "content-available": 1,
            "mutable-content": 1,
            sound: "",
          },
        },
      },
    }));

    // 6. Send all messages (batch send handles up to 500)
    const response = await messaging.sendEach(messages);

    // 7. Clean up invalid tokens
    const tokensToRemove: string[] = [];
    response.responses.forEach((resp, idx) => {
      if (resp.error) {
        const errorCode = resp.error.code;
        if (
          errorCode === "messaging/invalid-registration-token" ||
          errorCode === "messaging/registration-token-not-registered"
        ) {
          tokensToRemove.push(tokens[idx]);
        }
      }
    });

    // Remove invalid tokens from user documents
    if (tokensToRemove.length > 0) {
      const batch = db.batch();
      const usersSnap = await db
        .collection("users")
        .where("pushToken", "in", tokensToRemove.slice(0, 30))
        .get();

      usersSnap.docs.forEach((doc) => {
        batch.update(doc.ref, { pushToken: "" });
      });

      await batch.commit();
    }

    console.log(
      `Sent ${response.successCount}/${tokens.length} notifications for photo ${context.params.photoId}`
    );
  });

// ═══════════════════════════════════════════════════════════════════════
// CLOUD FUNCTION: Cleanup Expired Invites (Scheduled)
// ═══════════════════════════════════════════════════════════════════════

export const cleanupExpiredInvites = functions.pubsub
  .schedule("every 6 hours")
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();
    const expiredSnap = await db
      .collection("invites")
      .where("status", "==", "active")
      .where("expiresAt", "<", now)
      .limit(500)
      .get();

    if (expiredSnap.empty) return;

    const batch = db.batch();
    expiredSnap.docs.forEach((doc) => {
      batch.update(doc.ref, { status: "expired" });
    });

    await batch.commit();
    console.log(`Marked ${expiredSnap.size} invites as expired`);
  });
